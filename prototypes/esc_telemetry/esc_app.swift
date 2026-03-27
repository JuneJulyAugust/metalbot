import CoreBluetooth
import Foundation

enum LaunchConfiguration {
    static func sessionLabel(from arguments: [String] = ProcessInfo.processInfo.arguments,
                             environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        if let index = arguments.firstIndex(of: "--session-label"), index + 1 < arguments.count {
            return arguments[index + 1]
        }
        if let value = environment["ESC_SESSION_LABEL"], !value.isEmpty {
            return value
        }
        return nil
    }
}

struct Logger {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    private static let fileManager = FileManager.default
    private static let defaultLogPath = NSHomeDirectory() + "/esc_telemetry.log"
    private static let logDirectoryPath = NSHomeDirectory() + "/esc_telemetry_runs"
    private static var configuredLogPath = defaultLogPath
    private static var logFile: FileHandle?
    private static var isConfigured = false
    static var onWrite: ((String) -> Void)?
    static var shouldExitOnDisconnect = true

    static var logPath: String {
        configuredLogPath
    }

    static func configure(sessionLabel: String? = nil) {
        guard !isConfigured else {
            return
        }

        let timestamp = fileNameFormatter.string(from: Date())
        if let sessionLabel {
            let safeLabel = sanitizedLabel(sessionLabel)
            configuredLogPath = logDirectoryPath + "/\(timestamp)_\(safeLabel).log"
            try? fileManager.createDirectory(atPath: logDirectoryPath, withIntermediateDirectories: true)
        } else {
            configuredLogPath = defaultLogPath
        }

        fileManager.createFile(atPath: configuredLogPath, contents: nil, attributes: nil)
        logFile = FileHandle(forWritingAtPath: configuredLogPath)
        isConfigured = true
    }

    static func write(_ message: String) {
        let timeString = formatter.string(from: Date())
        let line = "[\(timeString)] \(message)"
        print(line)
        if let data = (line + "\n").data(using: .utf8), let file = logFile {
            file.seekToEndOfFile()
            file.write(data)
        }
        onWrite?(line)
    }

    static func hexString(from bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    static func hexString(from data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    private static func sanitizedLabel(_ label: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = label.unicodeScalars.map { allowed.contains($0) ? Character($0) : Character("_") }
        let collapsed = String(sanitized)
        return collapsed.isEmpty ? "session" : collapsed
    }
}

private enum ProbeFamily: CaseIterable {
    case framed
    case legacy

    var label: String {
        switch self {
        case .framed:
            return "framed-0x02"
        case .legacy:
            return "legacy-0x45"
        }
    }

    var initialCommand: [UInt8] {
        switch self {
        case .framed:
            return [0x02, 0x01, 0x00, 0x00, 0x00, 0x03]
        case .legacy:
            return [0x45, 0x05, 0x04, 0x01]
        }
    }

    var pollCommand: [UInt8] {
        switch self {
        case .framed:
            return [0x02, 0x01, 0x04, 0x40, 0x84, 0x03]
        case .legacy:
            return [0x45, 0x04, 0x04, 0x00]
        }
    }

    var handshakeCount: Int {
        20
    }

    var handshakeInterval: TimeInterval {
        0.2
    }

    var pollInterval: TimeInterval {
        0.12
    }

    var sessionDuration: TimeInterval {
        8.0
    }
}

private enum TelemetryDirection {
    case forward
    case reverse
    case stopped

    var label: String {
        switch self {
        case .forward:
            return "forward"
        case .reverse:
            return "reverse"
        case .stopped:
            return "stopped"
        }
    }
}

private struct TelemetryPacket {
    private static let expectedLength = 79

    let outputPercent: Int
    let direction: TelemetryDirection
    let escTemperatureC: Double
    let motorTemperatureC: Double
    let voltageV: Double
    let erpm: Int
    let rpm: Int

    init?(_ data: Data, poleCount: Int = 4) {
        let bytes = [UInt8](data)
        guard bytes.count == Self.expectedLength else {
            return nil
        }
        guard bytes[0] == 0x02, bytes[1] == 0x4A, bytes[2] == 0x04, bytes[3] == 0x01 else {
            return nil
        }

        let payload = Array(bytes[2..<(bytes.count - 3)])
        let expectedChecksum = (UInt16(bytes[bytes.count - 3]) << 8) | UInt16(bytes[bytes.count - 2])
        guard Self.crc16Xmodem(payload) == expectedChecksum else {
            return nil
        }

        let outputRaw = Self.signed16BE(bytes[23], bytes[24])
        let erpmRaw = Self.signed32BE(bytes[25], bytes[26], bytes[27], bytes[28])

        escTemperatureC = Double(Self.signed16BE(bytes[3], bytes[4])) / 10.0
        motorTemperatureC = Double(Self.signed16BE(bytes[5], bytes[6])) / 10.0
        outputPercent = min(100, abs(outputRaw / 10))
        direction = outputRaw > 0 ? .forward : outputRaw < 0 ? .reverse : .stopped
        erpm = erpmRaw
        rpm = Int((Double(erpmRaw) * 2.0) / Double(poleCount))
        let voltageRaw = (UInt16(bytes[29]) << 8) | UInt16(bytes[30])
        voltageV = Double(voltageRaw) / 100.0
    }

    var summary: String {
        "direction=\(direction.label) output=\(outputPercent)% esc=\(Self.format(escTemperatureC))C motor=\(Self.format(motorTemperatureC))C voltage=\(Self.format(voltageV))V erpm=\(erpm) rpm=\(rpm)"
    }

    private static func signed16BE(_ high: UInt8, _ low: UInt8) -> Int {
        Int(Int16(bitPattern: (UInt16(high) << 8) | UInt16(low)))
    }

    private static func signed32BE(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8, _ b3: UInt8) -> Int {
        let value = (UInt32(b0) << 24) | (UInt32(b1) << 16) | (UInt32(b2) << 8) | UInt32(b3)
        return Int(Int32(bitPattern: value))
    }

    private static func crc16Xmodem(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0
        for byte in bytes {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                if crc & 0x8000 != 0 {
                    crc = (crc &<< 1) ^ 0x1021
                } else {
                    crc = crc &<< 1
                }
            }
        }
        return crc
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

final class ESCTelemetryMonitor: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let targetDeviceName = "ESDM_4181FB"
    private let targetService = CBUUID(string: "AE3A")
    private let targetWrite = CBUUID(string: "AE3B")
    private let targetNotify = CBUUID(string: "AE3C")
    private let probeFamilies: [ProbeFamily] = [.framed, .legacy]

    private var centralManager: CBCentralManager!
    private var escPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var activeFamilyIndex = 0
    private var activeFamily: ProbeFamily?
    private var handshakeRemaining = 0
    private var telemetryCount = 0
    private var handshakeTimer: Timer?
    private var pollTimer: Timer?
    private var familyTimer: Timer?
    private var pendingWriteLabels: [String] = []

    override init() {
        super.init()
        Logger.write("--- Snail ESC telemetry probe harness ---")
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            Logger.write("Bluetooth is ON. Scanning for \(targetDeviceName)...")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        case .unknown:
            Logger.write("Bluetooth state is unknown.")
        case .resetting:
            Logger.write("Bluetooth is resetting.")
        case .unsupported:
            Logger.write("Bluetooth is unsupported.")
        case .unauthorized:
            Logger.write("Bluetooth is unauthorized.")
        case .poweredOff:
            Logger.write("Bluetooth is powered off.")
        @unknown default:
            Logger.write("Bluetooth entered an unknown state.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        Logger.write("Saw peripheral \(name) RSSI \(RSSI)")
        if name == targetDeviceName {
            Logger.write("Found ESC! Connecting...")
            escPeripheral = peripheral
            escPeripheral?.delegate = self
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Logger.write("Failed to connect to \(peripheral.identifier): \(String(describing: error))")
        if Logger.shouldExitOnDisconnect {
            exit(1)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Logger.write("Connected! Discovering service AE3A...")
        peripheral.discoverServices([targetService])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            Logger.write("Service discovery failed: \(error)")
            return
        }
        guard let services = peripheral.services else {
            Logger.write("No services discovered.")
            return
        }
        for service in services {
            Logger.write("Service discovered: \(service.uuid.uuidString)")
            if service.uuid == targetService {
                Logger.write("Found target service AE3A.")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            Logger.write("Characteristic discovery failed: \(error)")
            return
        }
        guard let characteristics = service.characteristics else {
            Logger.write("No characteristics discovered for service \(service.uuid.uuidString).")
            return
        }
        for char in characteristics {
            Logger.write("Characteristic \(char.uuid.uuidString) properties: \(propertyDescription(for: char))")
            if char.uuid == targetNotify {
                Logger.write("Subscribing to AE3C...")
                notifyCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
            }
            if char.uuid == targetWrite {
                Logger.write("Found write characteristic AE3B.")
                writeCharacteristic = char
            }
        }
        startProbeIfReady()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            Logger.write("Notification state update failed for \(characteristic.uuid.uuidString): \(error)")
            return
        }
        Logger.write("Notification state for \(characteristic.uuid.uuidString): \(characteristic.isNotifying)")
        if characteristic.uuid == targetNotify, characteristic.isNotifying {
            startProbeIfReady()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let label = pendingWriteLabels.isEmpty ? "untracked" : pendingWriteLabels.removeFirst()
        if let error = error {
            Logger.write("ACK[\(label)] error for \(characteristic.uuid.uuidString): \(error)")
        } else {
            Logger.write("ACK[\(label)] \(characteristic.uuid.uuidString)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            Logger.write("Notification error for \(characteristic.uuid.uuidString): \(error)")
            return
        }
        if let data = characteristic.value {
            if let packet = TelemetryPacket(data) {
                telemetryCount += 1
                Logger.write("Telemetry #\(telemetryCount) \(packet.summary)")
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            Logger.write("Disconnected with error: \(error)")
        } else {
            Logger.write("Disconnected.")
        }
        if Logger.shouldExitOnDisconnect {
            exit(0)
        }
    }

    private func startProbeIfReady() {
        guard activeFamily == nil else {
            return
        }
        guard let peripheral = escPeripheral, let writeCharacteristic, let notifyCharacteristic, notifyCharacteristic.isNotifying else {
            return
        }
        activeFamilyIndex = 0
        startProbe(for: probeFamilies[activeFamilyIndex], peripheral: peripheral, writeCharacteristic: writeCharacteristic)
    }

    private func startProbe(for family: ProbeFamily, peripheral: CBPeripheral, writeCharacteristic: CBCharacteristic) {
        cancelTimers()
        activeFamily = family
        handshakeRemaining = family.handshakeCount
        telemetryCount = 0
        Logger.write("Starting \(family.label) family. Init=\(Logger.hexString(from: family.initialCommand)) Poll=\(Logger.hexString(from: family.pollCommand))")

        let writeType = preferredWriteType(for: writeCharacteristic)
        Logger.write("Using write type \(writeType == .withResponse ? "withResponse" : "withoutResponse")")

        sendCommand(
            label: "\(family.label)/init",
            bytes: family.initialCommand,
            peripheral: peripheral,
            characteristic: writeCharacteristic,
            writeType: writeType
        )
        handshakeRemaining -= 1

        handshakeTimer = Timer.scheduledTimer(withTimeInterval: family.handshakeInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard self.handshakeRemaining > 0 else {
                timer.invalidate()
                self.startPolling(for: family, peripheral: peripheral, writeCharacteristic: writeCharacteristic)
                return
            }
            self.sendCommand(
                label: "\(family.label)/init",
                bytes: family.initialCommand,
                peripheral: peripheral,
                characteristic: writeCharacteristic,
                writeType: writeType
            )
            self.handshakeRemaining -= 1
            if self.handshakeRemaining == 0 {
                timer.invalidate()
                self.startPolling(for: family, peripheral: peripheral, writeCharacteristic: writeCharacteristic)
            }
        }

        familyTimer = Timer.scheduledTimer(withTimeInterval: family.sessionDuration, repeats: false) { [weak self] _ in
            self?.advanceToNextFamily()
        }
    }

    private func startPolling(for family: ProbeFamily, peripheral: CBPeripheral, writeCharacteristic: CBCharacteristic) {
        guard pollTimer == nil else {
            return
        }
        let writeType = preferredWriteType(for: writeCharacteristic)
        Logger.write("Starting \(family.label) poll loop.")
        pollTimer = Timer.scheduledTimer(withTimeInterval: family.pollInterval, repeats: true) { [weak self] _ in
            self?.sendCommand(
                label: "\(family.label)/poll",
                bytes: family.pollCommand,
                peripheral: peripheral,
                characteristic: writeCharacteristic,
                writeType: writeType
            )
        }
    }

    private func advanceToNextFamily() {
        cancelTimers()
        activeFamily = nil
        activeFamilyIndex += 1
        if activeFamilyIndex < probeFamilies.count,
           let peripheral = escPeripheral,
           let writeCharacteristic {
            let nextFamily = probeFamilies[activeFamilyIndex]
            Logger.write("Switching to \(nextFamily.label) family.")
            startProbe(for: nextFamily, peripheral: peripheral, writeCharacteristic: writeCharacteristic)
            return
        }

        Logger.write("Completed all probe families. Disconnecting.")
        if let peripheral = escPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    private func sendCommand(label: String, bytes: [UInt8], peripheral: CBPeripheral, characteristic: CBCharacteristic, writeType: CBCharacteristicWriteType) {
        if writeType == .withResponse {
            pendingWriteLabels.append(label)
        }
        Logger.write("TX[\(label)] \(Logger.hexString(from: bytes))")
        peripheral.writeValue(Data(bytes), for: characteristic, type: writeType)
    }

    private func preferredWriteType(for characteristic: CBCharacteristic) -> CBCharacteristicWriteType {
        if characteristic.properties.contains(.write) {
            return .withResponse
        }
        if characteristic.properties.contains(.writeWithoutResponse) {
            return .withoutResponse
        }
        return .withResponse
    }

    private func propertyDescription(for characteristic: CBCharacteristic) -> String {
        var properties: [String] = []
        if characteristic.properties.contains(.read) {
            properties.append("read")
        }
        if characteristic.properties.contains(.write) {
            properties.append("write")
        }
        if characteristic.properties.contains(.writeWithoutResponse) {
            properties.append("writeWithoutResponse")
        }
        if characteristic.properties.contains(.notify) {
            properties.append("notify")
        }
        if characteristic.properties.contains(.indicate) {
            properties.append("indicate")
        }
        if properties.isEmpty {
            return "none"
        }
        return properties.joined(separator: ",")
    }

    private func cancelTimers() {
        handshakeTimer?.invalidate()
        handshakeTimer = nil
        pollTimer?.invalidate()
        pollTimer = nil
        familyTimer?.invalidate()
        familyTimer = nil
        pendingWriteLabels.removeAll()
    }
}

