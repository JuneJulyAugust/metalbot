import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "car.side.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("metalbot")
                    .font(.largeTitle.bold())
                
                VStack(spacing: 20) {
                    NavigationLink(destination: SelfDrivingView()) {
                        HStack {
                            Image(systemName: "steeringwheel")
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text("Full Self-Driving")
                                    .font(.headline)
                                Text("Autonomous mode with ARKit & BLE")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 10)
                    }
                    
                    NavigationLink(destination: DiagnosticsView()) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text("Diagnostics & Debug")
                                    .font(.headline)
                                Text("Validate individual subsystems")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 10)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                Text("v0.6.0-dev")
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct DiagnosticsView: View {
    var body: some View {
        List {
            Section(header: Text("Perception")) {
                NavigationLink(destination: DepthCaptureView()) {
                    Label("LiDAR Capture", systemImage: "cube.transparent")
                        .font(.headline)
                        .padding(.vertical, 4)
                }
            }
            
            Section(header: Text("Estimation")) {
                NavigationLink(destination: ARKitPoseView()) {
                    Label("ARKit 6D Pose", systemImage: "move.3d")
                        .font(.headline)
                        .padding(.vertical, 4)
                }
            }
            
            Section(header: Text("CONTROL")) {
                NavigationLink(destination: MCPTestView()) {
                    Label("Raspberry Pi WiFi", systemImage: "cpu")
                        .font(.headline)
                        .padding(.vertical, 4)
                }
            }
            
            Section(header: Text("Control")) {
                NavigationLink(destination: STM32ControlView()) {
                    Label("STM32 Direct BLE", systemImage: "bolt.horizontal.fill")
                        .font(.headline)
                        .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Diagnostics")
    }
}
