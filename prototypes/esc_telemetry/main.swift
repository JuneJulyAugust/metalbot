import Foundation

Logger.configure(sessionLabel: LaunchConfiguration.sessionLabel())
let monitor = ESCTelemetryMonitor()
RunLoop.main.run()
