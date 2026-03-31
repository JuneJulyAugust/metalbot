import Foundation
import Combine
import SwiftUI

/// Orchestrates all subsystems for autonomous operation.
final class SelfDrivingViewModel: ObservableObject {
    
    // MARK: - Subsystems
    
    @Published var poseModel = ARKitPoseViewModel()
    @Published var escManager = ESCBleManager.shared
    @Published var stm32Manager = STM32BleManager.shared
    
    // MARK: - Planner

    let orchestrator = PlannerOrchestrator(planner: WaypointPlanner())

    /// Active waypoints for map overlay.
    @Published var waypoints: [Waypoint] = []

    // MARK: - Planner Constants

    private enum PlannerDefaults {
        /// Distance ahead to place the initial test waypoint (metres).
        static let waypointDistanceM: Float = 5.0
        /// Waypoint acceptance radius (metres).
        static let waypointAcceptanceM: Float = 0.5
        /// Maximum throttle for waypoint following (0–1).
        static let maxThrottle: Float = 0.3
    }

    // MARK: - State

    @Published var isStarted = false
    @Published var isAutonomous = false
    @Published var showMapManager = false

    // Manual/Auto overrides for UI feedback
    @Published var steering: Float = 0.0
    @Published var throttle: Float = 0.0

    // Control loop subscription — driven by ARKit pose updates, not a fixed timer.
    private var controlLoopSub: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Forward sub-system changes to our own objectWillChange if needed,
        // but SwiftUI @Published handles nested object changes if they are classes.
        // Actually, SwiftUI doesn't automatically observe nested @Published objects.
        // We'll use manual subscriptions to trigger updates.
        
        setupSubscriptions()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Lifecycle
    
    func start() {
        guard !isStarted else { return }
        
        poseModel.start()
        escManager.start()    // idempotent — no-op if already connected
        stm32Manager.start() // idempotent — no-op if already connected
        
        isStarted = true

        // Drive the control loop directly from ARKit pose updates.
        // Runs at the camera frame rate (~60 Hz) — no artificial throttle.
        controlLoopSub = poseModel.$currentPose
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.runControlLoop()
            }
    }
    
    func stop() {
        isStarted = false
        isAutonomous = false
        
        controlLoopSub?.cancel()
        controlLoopSub = nil
        
        poseModel.stop()
        // Shared singletons (ESC + STM32) are not stopped — they persist across views
        
        resetActuators()
    }
    
    func toggleAutonomous() {
        isAutonomous.toggle()
        if isAutonomous {
            armPlanner()
        } else {
            orchestrator.reset()
            waypoints = []
            resetActuators()
        }
    }

    /// Place a waypoint ahead of the current pose and arm the planner.
    /// See RobotGeometry.swift for the coordinate derivation.
    private func armPlanner() {
        guard let pose = poseModel.currentPose else { return }
        let wp = forwardWaypoint(
            from: pose,
            distance: PlannerDefaults.waypointDistanceM,
            acceptanceRadius: PlannerDefaults.waypointAcceptanceM
        )
        waypoints = [wp]
        orchestrator.setGoal(.followWaypoints([wp], maxThrottle: PlannerDefaults.maxThrottle))
    }
    
    // MARK: - Control Loop
    
    private func runControlLoop() {
        guard isStarted && isAutonomous else { return }
        guard let pose = poseModel.currentPose else { return }

        let context = PlannerContext(
            pose: pose,
            currentThrottle: throttle,
            escTelemetry: escManager.telemetry,
            forwardDepth: poseModel.forwardDepth,
            timestamp: pose.timestamp
        )

        let command = orchestrator.tick(context: context)

        self.steering = command.steering
        self.throttle = command.throttle

        sendActuatorCommands(steering: command.steering, throttle: command.throttle)
    }
    
    // MARK: - Helpers
    
    private func setupSubscriptions() {
        poseModel.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        escManager.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        stm32Manager.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        orchestrator.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }
    
    private func sendActuatorCommands(steering: Float, throttle: Float) {
        let sPWM = toPulseWidth(steering)
        let tPWM = toPulseWidth(throttle)
        stm32Manager.sendCommand(steeringMicros: sPWM, throttleMicros: tPWM)
    }
    
    private func resetActuators() {
        steering = 0
        throttle = 0
        stm32Manager.sendCommand(steeringMicros: 1500, throttleMicros: 1500)
    }
    
    private func toPulseWidth(_ normalized: Float) -> Int16 {
        let clamped = max(-1.0, min(1.0, normalized))
        return Int16(1500.0 + clamped * 500.0)
    }
}
