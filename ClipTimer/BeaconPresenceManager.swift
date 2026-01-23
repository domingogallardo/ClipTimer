//
//  BeaconPresenceManager.swift
//  ClipTimer
//
//  Created by Domingo Gallardo
//

import CoreBluetooth
import Foundation

final class BeaconPresenceManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    struct BeaconKey: Hashable {
        let uuid: String
        let major: UInt16
        let minor: UInt16
    }

    struct IBeaconPayload {
        let uuid: String
        let major: UInt16
        let minor: UInt16
        let txPower: Int8
    }

    struct Config {
        let target: BeaconKey
        let minValidRssiThreshold: Int
        let weakSeconds: TimeInterval
        let weakPrimeSeconds: TimeInterval
        let awayTimeout: TimeInterval
        let emaAlpha: Double

        static let `default` = Config(
            target: BeaconKey(
                uuid: "FDA50693-A4E2-4FB1-AFCF-C6EB07647825",
                major: 10011,
                minor: 19641
            ),
            minValidRssiThreshold: -70,
            weakSeconds: 30.0,
            weakPrimeSeconds: 20.0,
            awayTimeout: 90.0,
            emaAlpha: 0.3
        )
    }

    enum PresenceState: String {
        case searching
        case present
        case away
    }

    struct AbsenceDetails: Equatable {
        let reason: String
        let rssi: Int?
        let rssiAverage: Double?
        let ageSeconds: Int?
        let weakDuration: TimeInterval?
        let minValidRssiThreshold: Int
        let weakSeconds: TimeInterval
        let weakPrimeSeconds: TimeInterval
        let awayTimeout: TimeInterval

        var formattedDescription: String {
            let rssiLabel = rssi.map { String($0) } ?? "NA"
            let rssiAvgLabel = rssiAverage.map { String(format: "%.1f", $0) } ?? "NA"
            let ageLabel = ageSeconds.map { String($0) } ?? "NA"
            let weakAge = weakDuration.map { String(format: "%.0f", $0) } ?? "NA"
            let weakSecondsLabel = String(format: "%.0f", weakSeconds)
            let weakPrimeLabel = String(format: "%.0f", weakPrimeSeconds)
            let awayTimeoutLabel = String(format: "%.0f", awayTimeout)

            return """
Reason: \(reason)
RSSI: \(rssiLabel)
RSSI avg: \(rssiAvgLabel)
Age: \(ageLabel)s
Weak duration: \(weakAge)s (threshold \(minValidRssiThreshold), weak \(weakSecondsLabel)s, prime \(weakPrimeLabel)s)
Away timeout: \(awayTimeoutLabel)s
"""
        }
    }

    @Published private(set) var state: PresenceState
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var awaitingConfirmation = false
    @Published private(set) var lastAbsenceDetails: AbsenceDetails?

    var isPresent: Bool {
        state == .present
    }

    var needsBluetoothPermission: Bool {
        bluetoothState == .unauthorized
    }

    private var central: CBCentralManager?
    private var isScanning = false
    private var reportTimer: Timer?
    private var lastSeen: Date?
    private var lastRssi: Int?
    private var rssiFiltered: Double?
    private var lastState: PresenceState?
    private var firstPresenceConfirmed = false
    private var weakSince: Date?
    private let startTime: Date
    private var lastLoggedMinute: Int?
    private let config: Config

    init(
        config: Config = .default,
        initialState: PresenceState = .searching,
        startScanning: Bool = true
    ) {
        self.config = config
        self.state = initialState
        self.startTime = Date()
        super.init()
        if startScanning {
            start()
        }
    }

    func start() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func stop() {
        stopScanning()
        central?.delegate = nil
        central = nil
    }

    func restartDetection() {
        awaitingConfirmation = false
        resetPresenceState()
        startScanningIfNeeded()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        let stateDescription: String
        switch central.state {
        case .poweredOn:
            stateDescription = "poweredOn"
        case .poweredOff:
            stateDescription = "poweredOff"
        case .unauthorized:
            stateDescription = "unauthorized"
        case .unsupported:
            stateDescription = "unsupported"
        case .resetting:
            stateDescription = "resetting"
        case .unknown:
            fallthrough
        @unknown default:
            stateDescription = "unknown"
        }

        print("[BLE] central state = \(stateDescription)")

        if central.state == .poweredOn {
            startScanningIfNeeded()
        } else {
            stopScanning()
            resetPresenceState()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let payload = parseIBeacon(advertisementData: advertisementData) else { return }
        let key = BeaconKey(uuid: payload.uuid, major: payload.major, minor: payload.minor)
        guard key == config.target else { return }

        let rssiValue = RSSI.intValue
        guard isValidRssi(rssiValue) else { return }

        lastRssi = rssiValue
        updateRssiFiltered(with: rssiValue)

        guard rssiValue >= config.minValidRssiThreshold else { return }

        lastSeen = Date()
    }

    private func startScanningIfNeeded() {
        guard !isScanning, let central else { return }
        isScanning = true
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
        startReportTimerIfNeeded()
        print("[BLE] scanning started (tracking 1 beacon)")
    }

    private func stopScanning() {
        guard isScanning, let central else { return }
        isScanning = false
        central.stopScan()
        stopReportTimer()
        print("[BLE] scanning stopped")
    }

    private func startReportTimerIfNeeded() {
        guard reportTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.reportPresence()
        }
        RunLoop.main.add(timer, forMode: .common)
        reportTimer = timer
    }

    private func stopReportTimer() {
        reportTimer?.invalidate()
        reportTimer = nil
    }

    private func reportPresence() {
        let now = Date()
        let ageSeconds: Int? = lastSeen.map { Int(now.timeIntervalSince($0)) }
        var weakDuration: TimeInterval?

        if firstPresenceConfirmed, let filtered = rssiFiltered {
            if filtered < Double(config.minValidRssiThreshold) {
                if weakSince == nil {
                    weakSince = now
                }
                weakDuration = weakSince.map { now.timeIntervalSince($0) }
            } else {
                weakSince = nil
            }
        } else {
            weakSince = nil
        }

        let weakTimedOut = weakDuration.map { $0 >= config.weakSeconds } ?? false
        let weakPrimed = weakDuration.map { $0 >= config.weakPrimeSeconds } ?? false

        let newState: PresenceState
        let reason: String

        if lastSeen == nil {
            newState = .searching
            reason = "no-signal"
        } else if !firstPresenceConfirmed {
            firstPresenceConfirmed = true
            newState = .present
            reason = "assumed"
        } else {
            if weakTimedOut {
                newState = .away
                reason = "weak-rssi"
            } else if let ageSeconds = ageSeconds, Double(ageSeconds) > config.awayTimeout {
                if weakPrimed {
                    newState = .away
                    reason = "timeout"
                } else {
                    newState = .present
                    reason = "stale-hold"
                }
            } else {
                newState = .present
                reason = "hold"
            }
        }

        let rssiLabel = lastRssi.map { String($0) } ?? "NA"
        let rssiAvgLabel = rssiFiltered.map { String(format: "%.1f", $0) } ?? "NA"
        let ageLabel = ageSeconds.map { String($0) } ?? "NA"
        let awayTimeoutLabel = String(format: "%.0f", config.awayTimeout)
        let weakAge = weakDuration.map { String(format: "%.0f", $0) } ?? "NA"
        let weakLabel = "weak=\(weakAge)s/\(Int(config.weakSeconds))s@\(config.minValidRssiThreshold) prime=\(Int(config.weakPrimeSeconds))s"
        let detailed = "[BLE] presence \(newState.rawValue) (reason=\(reason), rssi=\(rssiLabel), rssiAvg=\(rssiAvgLabel), age=\(ageLabel)s, valid>=\(config.minValidRssiThreshold), \(weakLabel), awayTimeout=\(awayTimeoutLabel)s)"

        let stateChanged = newState == .searching || lastState == nil || lastState != newState
        if stateChanged {
            print(detailed)
        } else if firstPresenceConfirmed {
            let minuteIndex = Int(now.timeIntervalSince(startTime) / 60) + 1
            if lastLoggedMinute != minuteIndex {
                print("[BLE] minute \(minuteIndex): \(newState.rawValue) (reason=\(reason), age=\(ageLabel)s, rssiAvg=\(rssiAvgLabel), \(weakLabel))")
                lastLoggedMinute = minuteIndex
            }
        }

        if newState == .away && lastState != .away {
            lastAbsenceDetails = AbsenceDetails(
                reason: reason,
                rssi: lastRssi,
                rssiAverage: rssiFiltered,
                ageSeconds: ageSeconds,
                weakDuration: weakDuration,
                minValidRssiThreshold: config.minValidRssiThreshold,
                weakSeconds: config.weakSeconds,
                weakPrimeSeconds: config.weakPrimeSeconds,
                awayTimeout: config.awayTimeout
            )
            if state != .away {
                state = .away
            }
            lastState = .away
            pauseForPresenceConfirmation()
            return
        }

        if state != newState {
            state = newState
        }
        lastState = newState
    }

    private func updateRssiFiltered(with value: Int) {
        let newValue = Double(value)
        if let current = rssiFiltered {
            rssiFiltered = (config.emaAlpha * newValue) + ((1.0 - config.emaAlpha) * current)
        } else {
            rssiFiltered = newValue
        }
    }

    private func isValidRssi(_ value: Int) -> Bool {
        value >= -120 && value <= -1
    }

    private func parseIBeacon(advertisementData: [String: Any]) -> IBeaconPayload? {
        guard let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else {
            return nil
        }

        let bytes = [UInt8](data)
        guard bytes.count >= 25 else { return nil }
        guard bytes[0] == 0x4C && bytes[1] == 0x00 && bytes[2] == 0x02 && bytes[3] == 0x15 else {
            return nil
        }

        let uuidBytes = bytes[4..<20]
        let uuid = uuidString(from: Array(uuidBytes))
        let major = UInt16(bytes[20]) << 8 | UInt16(bytes[21])
        let minor = UInt16(bytes[22]) << 8 | UInt16(bytes[23])
        let txPower = Int8(bitPattern: bytes[24])
        return IBeaconPayload(uuid: uuid, major: major, minor: minor, txPower: txPower)
    }

    private func uuidString(from bytes: [UInt8]) -> String {
        guard bytes.count == 16 else { return "unknown" }
        return String(
            format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
    }

    private func resetPresenceState() {
        lastSeen = nil
        lastRssi = nil
        rssiFiltered = nil
        lastState = nil
        firstPresenceConfirmed = false
        lastLoggedMinute = nil
        weakSince = nil
        awaitingConfirmation = false
        lastAbsenceDetails = nil
        if state != .searching {
            state = .searching
        }
    }

    private func pauseForPresenceConfirmation() {
        guard !awaitingConfirmation else { return }
        awaitingConfirmation = true
        stopScanning()
        print("[BLE] awaiting confirmation to resume scanning")
    }
}
