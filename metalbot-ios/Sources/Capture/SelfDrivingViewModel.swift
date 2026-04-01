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

    let orchestrator = PlannerOrchestrator(planner: ConstantSpeedPlanner())

    /// Active waypoints for map overlay (empty for constant speed mode).
    @Published var waypoints: [Waypoint] = []

    /// Target throttle for constant throttle planner. Adjustable from UI.
    @Published var targetThrottle: Float = 0.4

    // MARK: - Throttle Limits

    static let maxThrottle: Float = 1.0
    static let minThrottle: Float = -1.0

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
        setupSubscriptions()
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    func start() {
        guard !isStarted else { return }

        poseModel.start()
        escManager.start()
        stm32Manager.start()

        isStarted = true

        poseModel.onFrameUpdate = { [weak self] pose, depth, speed in
            self?.runControlLoop(pose: pose, depth: depth, speed: speed)
        }
    }

    func stop() {
        isStarted = false
        isAutonomous = false

        poseModel.onFrameUpdate = nil

        poseModel.stop()

        resetActuators()
    }

    func toggleAutonomous() {
        isAutonomous.toggle()
        if isAutonomous {
            orchestrator.setGoal(.constantThrottle(targetThrottle: targetThrottle))
        } else {
            orchestrator.reset()
            waypoints = []
            resetActuators()
        }
    }

    // MARK: - Control Loop

    private func runControlLoop(pose: PoseEntry, depth: Float?, speed: Double?) {
        guard isStarted && isAutonomous else { return }

        let motorSpeed: Double? = {
            guard let tel = escManager.telemetry, tel.speedMps > 0.01 else { return nil }
            return tel.speedMps
        }()
        let arkitSpeed: Double? = {
            if let s = speed, s > 0.01 { return s }
            return nil
        }()

        let context = PlannerContext(
            pose: pose,
            currentThrottle: self.throttle,
            escTelemetry: escManager.telemetry,
            forwardDepth: depth,
            motorSpeedMps: motorSpeed,
            arkitSpeedMps: arkitSpeed,
            timestamp: pose.timestamp
        )

        let command = orchestrator.tick(context: context)

        sendActuatorCommands(steering: command.steering, throttle: command.throttle)

        DispatchQueue.main.async {
            self.steering = command.steering
            self.throttle = command.throttle
        }
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
