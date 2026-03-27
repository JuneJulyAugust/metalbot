import SwiftUI

final class ESCScannerViewModel: ObservableObject {
    @Published var logLines: [String] = []

    private var monitor: ESCTelemetryMonitor?

    init() {
        Logger.shouldExitOnDisconnect = false
        Logger.onWrite = { [weak self] line in
            DispatchQueue.main.async {
                self?.logLines.append(line)
            }
        }
        monitor = ESCTelemetryMonitor()
    }
}

struct ESCScannerView: View {
    @StateObject private var viewModel = ESCScannerViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ESC Telemetry")
                .font(.headline)

            Text(Logger.logPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(viewModel.logLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: viewModel.logLines.count) { _, count in
                    guard count > 0 else { return }
                    proxy.scrollTo(count - 1, anchor: .bottom)
                }
            }
        }
        .padding()
        .frame(minWidth: 720, minHeight: 480)
    }
}
