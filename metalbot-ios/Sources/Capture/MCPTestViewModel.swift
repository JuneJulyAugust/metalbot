import Foundation
import UIKit
import Network
import Combine

class MCPTestViewModel: ObservableObject {
    @Published var connectionStatus: String = "Disconnected"
    @Published var hbSentCount: Int = 0
    @Published var hbReceivedCount: Int = 0
    @Published var cmdSentCount: Int = 0
    @Published var lastSentTime: String = "Never"
    @Published var lastReceivedTime: String = "Never"
    @Published var steering: Float = 0.0
    @Published var motor: Float = 0.0
    
    @Published var iphoneIP: String = "Unknown"
    @Published var iphoneName: String = UIDevice.current.name
    
    private var connection: NWConnection?
    private var timer: Timer?
    private var timeoutTimer: Timer?
    private let host = "192.168.2.189"
    private let port: NWEndpoint.Port = 8888
    
    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }()
    
    init() {
        iphoneIP = getIPAddress() ?? "0.0.0.0"
        setupConnection()
        startHeartbeat()
    }
    
    deinit {
        timer?.invalidate()
        timeoutTimer?.invalidate()
        connection?.cancel()
    }
    
    func setupConnection() {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: port)
        connection = NWConnection(to: endpoint, using: .udp)
        receiveLoop()
        connection?.start(queue: .global())
    }
    
    private func receiveLoop() {
        connection?.receiveMessage { [weak self] (data, context, isComplete, error) in
            if let data = data, !data.isEmpty {
                let msg = String(decoding: data, as: UTF8.self)
                if msg.contains("hb_pi") {
                    DispatchQueue.main.async {
                        self?.hbReceivedCount += 1
                        self?.lastReceivedTime = self?.timeFormatter.string(from: Date()) ?? ""
                        self?.connectionStatus = "Connected"
                        self?.resetTimeout()
                    }
                }
            }
            if error == nil {
                self?.receiveLoop()
            }
        }
    }
    
    private func resetTimeout() {
        timeoutTimer?.invalidate()
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.connectionStatus = "Disconnected (Timeout)"
            }
        }
    }
    
    func startHeartbeat() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    func sendHeartbeat() {
        send(message: "hb_iphone:\(hbSentCount)")
        DispatchQueue.main.async {
            self.hbSentCount += 1
            self.lastSentTime = self.timeFormatter.string(from: Date())
        }
    }
    
    func sendCommand() {
        let msg = String(format: "cmd:s=%.2f,m=%.2f", steering, motor)
        send(message: msg)
        DispatchQueue.main.async {
            self.cmdSentCount += 1
        }
    }
    
    private func send(message: String) {
        guard let data = message.data(using: .utf8) else { return }
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                print("Send error: \(error)")
            }
        }))
    }
    
    func updateSteering(_ val: Float) {
        steering = val
        sendCommand()
    }
    
    func updateMotor(_ val: Float) {
        motor = val
        sendCommand()
    }

    func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == "en0" { // WiFi interface
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}
