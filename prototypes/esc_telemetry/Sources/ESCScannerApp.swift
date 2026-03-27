import SwiftUI

@main
struct ESCScannerApp: App {
    init() {
        Logger.configure(sessionLabel: LaunchConfiguration.sessionLabel())
    }

    var body: some Scene {
        WindowGroup {
            ESCScannerView()
        }
    }
}
