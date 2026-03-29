import SwiftUI

struct SelfDrivingView: View {
    @StateObject private var viewModel = SelfDrivingViewModel()
    @Environment(\.dismiss) var dismiss
    
    // View state for map interaction
    @State private var scale: CGFloat = 100.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 100.0
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // TOP BAR: Subsystem Status
                subsystemStatusHeader
                    .padding()
                    .background(Color(.systemBackground).shadow(radius: 2))
                
                // CENTER: Map
                mapSection
                    .zIndex(0)
                
                // BOTTOM: HUD & Controls
                controlPanel
                    .background(Color(.systemBackground).shadow(radius: 5))
            }
        }
        .navigationTitle("Self-Driving")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Exit") {
                    viewModel.stop()
                    dismiss()
                }
            }
        }
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
    
    // MARK: - Components
    
    private var subsystemStatusHeader: some View {
        HStack(spacing: 16) {
            StatusIndicator(label: "ARKit", status: viewModel.poseModel.trackingState == .normal ? .connected : .connecting)
            StatusIndicator(label: "ESC", status: viewModel.escManager.status == .connected ? .connected : .connecting)
            StatusIndicator(label: "STM32", status: viewModel.stm32Manager.status == .connected ? .connected : .connecting)
            Spacer()
            if let pose = viewModel.poseModel.currentPose {
                Text(String(format: "C:%.0f%%", pose.confidence * 100))
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(pose.confidence > 0.7 ? .green : .orange)
            }
        }
    }
    
    private var mapSection: some View {
        ZStack(alignment: .bottomLeading) {
            PoseMapView(
                poses: viewModel.poseModel.poses,
                currentPose: viewModel.poseModel.currentPose,
                isTracking: viewModel.poseModel.isTracking,
                scale: $scale,
                offset: $offset
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(10, min(lastScale * value, 2000))
                    }
                    .onEnded { _ in
                        lastScale = scale
                    }
            )
            
            // Map Controls
            VStack {
                Button {
                    withAnimation {
                        scale = 100
                        offset = .zero
                    }
                } label: {
                    Image(systemName: "location.viewfinder")
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
    
    private var controlPanel: some View {
        VStack(spacing: 20) {
            // Telemetry & Control Readout
            HStack(alignment: .top, spacing: 20) {
                // ESC Telemetry
                GroupBox(label: Label("TELEMETRY", systemImage: "gauge")) {
                    VStack(alignment: .leading, spacing: 4) {
                        MetricRow(label: "Speed", value: "\(viewModel.escManager.telemetry?.rpm ?? 0) RPM")
                        MetricRow(label: "Voltage", value: String(format: "%.1f V", viewModel.escManager.telemetry?.voltage ?? 0.0))
                        MetricRow(label: "ESC Temp", value: String(format: "%.0f°C", viewModel.escManager.telemetry?.escTemperature ?? 0.0))
                    }
                }
                .groupBoxStyle(ModernGroupBoxStyle())
                
                // Actuation Status
                GroupBox(label: Label("ACTUATION", systemImage: "engine.combustion")) {
                    VStack(alignment: .leading, spacing: 4) {
                        MetricRow(label: "Steering", value: String(format: "%.0f%%", viewModel.steering * 100))
                        MetricRow(label: "Throttle", value: String(format: "%.0f%%", viewModel.throttle * 100))
                        MetricRow(label: "Sent", value: "\(viewModel.stm32Manager.commandsSent)")
                    }
                }
                .groupBoxStyle(ModernGroupBoxStyle())
            }
            .padding(.horizontal)
            
            // Start/Stop Autonomous
            HStack(spacing: 20) {
                Button(action: { viewModel.toggleAutonomous() }) {
                    Label(viewModel.isAutonomous ? "DISARM" : "ARM AUTO", 
                          systemImage: viewModel.isAutonomous ? "stop.fill" : "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isAutonomous ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!viewModel.isStarted)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Sub-components

struct StatusIndicator: View {
    let label: String
    let status: StatusType
    
    enum StatusType {
        case connected, connecting, disconnected
        var color: Color {
            switch self {
            case .connected: return .green
            case .connecting: return .orange
            case .disconnected: return .red
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.secondary)
        }
    }
}
