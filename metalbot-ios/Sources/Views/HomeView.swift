import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
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
            .navigationTitle("metalbot")
        }
    }
}
