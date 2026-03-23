import Foundation
import ARKit
import simd

// MARK: - Data Models

struct PoseEntry: Identifiable {
    let id = UUID()
    let timestamp: TimeInterval

    // Robot Coordinates
    let x: Float // Forward
    let y: Float // Up
    let z: Float // Right
    let yaw: Float // Rotation about Y-axis (Up), gimbal-safe

    /// Tracking confidence: 0 = unknown/limited, 0.5 = limited with LiDAR, 1.0 = normal with LiDAR.
    let confidence: Float
}

// MARK: - Yaw Extraction (gimbal-safe)

/// Extract yaw (rotation about gravity/Y-axis) from a 4×4 transform using atan2.
/// This avoids the ±π discontinuities and gimbal lock of Euler angles.
///
/// Derivation: For ARKit `.gravity` alignment, a pure Y-rotation by angle θ gives
/// `columns.2 = (sin(θ), 0, cos(θ))` (the camera's backward/+Z axis in world space).
/// Therefore `atan2(columns.2.x, columns.2.z) = atan2(sin(θ), cos(θ)) = θ`,
/// matching `eulerAngles.y` without gimbal lock at extreme pitch.
func extractGimbalSafeYaw(from transform: simd_float4x4) -> Float {
    // Use camera's +Z (backward) axis projected onto the XZ plane.
    // This directly recovers the Y-rotation angle θ.
    return atan2(transform.columns.2.x, transform.columns.2.z)
}

// MARK: - ViewModel

final class ARKitPoseViewModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published var isTracking = false
    @Published var poses: [PoseEntry] = []
    @Published var currentPose: PoseEntry?
    @Published var errorMsg: String?
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var trackingReason: String = ""
    @Published var isUsingSceneDepth: Bool = false

    /// Whether the session was interrupted (app backgrounded, camera lost, etc.).
    @Published var isInterrupted: Bool = false

    /// Whether relocalization is in progress after an interruption.
    @Published var isRelocalizing: Bool = false

    /// Whether an ARWorldMap is loaded for drift correction.
    @Published var hasWorldMap: Bool = false

    private let arSession = ARSession()
    private var lastRecordedTime: TimeInterval = 0
    private let recordInterval: TimeInterval = 0.1 // 10 Hz

    /// Dedicated high-priority queue for ARSession delegate callbacks.
    /// Prevents frame processing from contending with UI layout on main thread.
    private let frameQueue = DispatchQueue(label: "com.metalbot.arkit.pose", qos: .userInitiated)

    /// Path for persisting the ARWorldMap to disk.
    private var worldMapURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("metalbot_worldmap.arexperience")
    }

    override init() {
        super.init()
        arSession.delegate = self
        arSession.delegateQueue = frameQueue
    }

    // MARK: - Session Lifecycle

    func start() {
        guard ARWorldTrackingConfiguration.isSupported else {
            errorMsg = "ARWorldTracking is not supported on this device."
            return
        }

        let config = makeTrackingConfiguration()

        // Attempt to load a previously saved ARWorldMap for relocalization.
        if let savedMap = loadWorldMap() {
            config.initialWorldMap = savedMap
            // Keep existing anchors from the map for relocalization.
            arSession.run(config, options: [.resetTracking])
            DispatchQueue.main.async {
                self.hasWorldMap = true
            }
        } else {
            arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        }

        DispatchQueue.main.async {
            self.isTracking = true
            self.poses.removeAll()
            self.lastRecordedTime = 0
            self.errorMsg = nil
            self.trackingState = .notAvailable
            self.trackingReason = "Initializing..."
            self.isUsingSceneDepth = false
            self.isInterrupted = false
            self.isRelocalizing = false
        }
    }

    func stop() {
        arSession.pause()
        DispatchQueue.main.async {
            self.isTracking = false
        }
    }

    func clear() {
        DispatchQueue.main.async {
            self.poses.removeAll()
            self.currentPose = nil
        }
    }

    // MARK: - ARWorldMap Persistence

    /// Save the current world map for future relocalization.
    func saveWorldMap() {
        arSession.getCurrentWorldMap { [weak self] worldMap, error in
            guard let self, let worldMap else {
                if let error {
                    print("ARWorldMap save failed: \(error.localizedDescription)")
                }
                return
            }
            do {
                let data = try NSKeyedArchiver.archivedData(
                    withRootObject: worldMap,
                    requiringSecureCoding: true
                )
                try data.write(to: self.worldMapURL, options: .atomic)
                print("ARWorldMap saved (\(worldMap.anchors.count) anchors)")
            } catch {
                print("ARWorldMap archive failed: \(error.localizedDescription)")
            }
        }
    }

    /// Delete the saved world map.
    func deleteWorldMap() {
        try? FileManager.default.removeItem(at: worldMapURL)
        DispatchQueue.main.async {
            self.hasWorldMap = false
        }
    }

    private func loadWorldMap() -> ARWorldMap? {
        guard FileManager.default.fileExists(atPath: worldMapURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: worldMapURL)
            let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
            return map
        } catch {
            print("ARWorldMap load failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Configuration

    private func makeTrackingConfiguration() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()

        // Align to gravity only (Y up, -Z is initial camera forward)
        config.worldAlignment = .gravity

        // --- Accuracy Enhancements ---

        // 1. LiDAR Scene Depth — constrains scale drift.
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }

        // 2. Smoothed Scene Depth — temporal averaging for mesh quality.
        //    Better mesh quality indirectly improves tracking stability.
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }

        // 3. Scene Reconstruction — persistent meshing for loop closure.
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }

        // 4. Plane Detection (Horizontal AND Vertical).
        //    Walls and floors give ARKit continuous structural anchors.
        config.planeDetection = [.horizontal, .vertical]

        // 5. Environment Texturing — builds a comprehensive feature map.
        config.environmentTexturing = .automatic

        // 6. Max video resolution — more VIO features.
        if let highResFormat = ARWorldTrackingConfiguration.supportedVideoFormats.max(by: {
            $0.imageResolution.width * $0.imageResolution.height <
            $1.imageResolution.width * $1.imageResolution.height
        }) {
            config.videoFormat = highResFormat
        }

        // 7. Reference image detection — for drift-correcting visual markers.
        //    If reference images exist in the asset catalog, ARKit will auto-detect them
        //    and create ARImageAnchors, tightening position estimates near markers.
        if let referenceImages = ARReferenceImage.referenceImages(
            inGroupNamed: "ARReferenceImages",
            bundle: nil
        ), !referenceImages.isEmpty {
            config.detectionImages = referenceImages
        }

        return config
    }

    // MARK: - Tracking Confidence

    /// Compute a 0–1 confidence score from tracking state and sensor availability.
    private func computeConfidence(state: ARCamera.TrackingState, hasDepth: Bool) -> Float {
        switch state {
        case .notAvailable:
            return 0.0
        case .limited(let reason):
            let base: Float
            switch reason {
            case .initializing:     base = 0.1
            case .relocalizing:     base = 0.2
            case .excessiveMotion:  base = 0.3
            case .insufficientFeatures: base = 0.25
            @unknown default:       base = 0.2
            }
            // LiDAR provides a boost even in limited states.
            return hasDepth ? min(base + 0.2, 0.6) : base
        case .normal:
            return hasDepth ? 1.0 : 0.8
        }
    }

    // MARK: - ARSessionDelegate — Frame Updates

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let transform = frame.camera.transform
        let timestamp = frame.timestamp
        let state = frame.camera.trackingState
        let hasDepth = frame.sceneDepth != nil

        // Map ARKit coordinates to Robot Frame:
        // ARKit: -Z is Initial Forward, +X is Right, +Y is Up
        // Robot: +X is Forward, +Z is Right, +Y is Up
        let robotX = -transform.columns.3.z
        let robotY = transform.columns.3.y
        let robotZ = transform.columns.3.x

        // Gimbal-safe yaw extraction using atan2 instead of eulerAngles.
        let robotYaw = extractGimbalSafeYaw(from: transform)

        let confidence = computeConfidence(state: state, hasDepth: hasDepth)

        let entry = PoseEntry(
            timestamp: timestamp,
            x: robotX, y: robotY, z: robotZ,
            yaw: robotYaw,
            confidence: confidence
        )

        DispatchQueue.main.async {
            self.currentPose = entry
            self.trackingState = state
            self.isUsingSceneDepth = hasDepth

            switch state {
            case .notAvailable:
                self.trackingReason = "Not Available"
                self.isRelocalizing = false
            case .limited(let reason):
                switch reason {
                case .initializing:        self.trackingReason = "Initializing..."
                case .relocalizing:
                    self.trackingReason = "Relocalizing..."
                    self.isRelocalizing = true
                case .excessiveMotion:     self.trackingReason = "Excessive Motion"
                case .insufficientFeatures: self.trackingReason = "Insufficient Features"
                @unknown default:          self.trackingReason = "Limited"
                }
            case .normal:
                self.trackingReason = "Normal"
                self.isRelocalizing = false
            }

            // Record trajectory at 10Hz, only when tracking is Normal.
            if state == .normal {
                if timestamp - self.lastRecordedTime >= self.recordInterval {
                    self.poses.append(entry)
                    self.lastRecordedTime = timestamp
                }
            }
        }
    }

    // MARK: - ARSessionDelegate — Session Interruption

    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async {
            self.isInterrupted = true
            self.trackingReason = "Session Interrupted"
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.isInterrupted = false
            self.isRelocalizing = true
            self.trackingReason = "Relocalizing..."
        }
    }

    /// Allow ARKit to attempt relocalization after an interruption.
    /// This is critical for a moving robot — without it, all future poses
    /// would be offset by the drift accumulated during the interruption.
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        true
    }

    // MARK: - ARSessionDelegate — Error Handling

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMsg = error.localizedDescription
            self.isTracking = false
        }
    }

    // MARK: - ARSessionDelegate — Anchor Detection (Reference Markers)

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let imageAnchor = anchor as? ARImageAnchor {
                let name = imageAnchor.referenceImage.name ?? "unknown"
                print("Reference marker detected: \(name) — position tightened")
            }
        }
    }
}
