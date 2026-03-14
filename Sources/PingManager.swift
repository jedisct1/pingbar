import Foundation

@MainActor
final class PingManager {
    enum PingStatus {
        case good, warning, bad, captivePortal
    }

    enum PacketLossMode: String {
        case passive
        case active

        var displayName: String {
            rawValue.capitalized
        }
    }

    struct PingResult {
        let status: PingStatus
        let message: String
        let latencyMs: Int?
        let success: Bool
        let countsAsLoss: Bool
    }

    private var timer: Timer?
    private var activeBurstTimer: Timer?
    private var currentPingTask: URLSessionDataTask?
    private var activeBurstTasks: [URLSessionDataTask] = []
    private var isActiveBurstInFlight = false
    private var lifecycleGeneration = 0
    private var isRunning = false
    private var url: URL
    private var interval: TimeInterval
    private var lastPingFailedAt: Date?
    private var latestMainStatus: PingStatus = .bad
    private var packetLossProbeInterval: TimeInterval = 30.0
    private var packetLossBurstSize: Int = 5
    private(set) var packetLossWindowSize = 50
    private var highPingThresholdValue = 200

    var onPingResult: ((PingResult) -> Void)?
    var onPacketLossUpdated: (() -> Void)?

    var highPingThreshold: Int {
        get { highPingThresholdValue }
        set {
            let clamped = max(1, newValue)
            highPingThresholdValue = clamped
            UserDefaults.standard.set(clamped, forKey: UserDefaultsKey.highPingThreshold)
        }
    }

    private(set) var packetLossMode: PacketLossMode = .passive
    private(set) var recentPings: [Int] = []
    private(set) var lossTracker = LossTracker()
    private let maxRecentPings = 30

    init() {
        self.url = URL(string: "https://www.google.com")!
        self.interval = 5.0
        reloadSettingsFromDefaults(restartIfRunning: false)
    }

    func updateSettings(host: String, interval: TimeInterval) {
        UserDefaults.standard.set(host, forKey: UserDefaultsKey.pingHost)
        UserDefaults.standard.set(interval, forKey: UserDefaultsKey.pingInterval)
        reloadSettingsFromDefaults()
    }

    func reloadSettingsFromDefaults(restartIfRunning: Bool = true) {
        let defaults = UserDefaults.standard
        let wasRunning = isRunning
        let previousMode = packetLossMode

        let host = defaults.string(forKey: UserDefaultsKey.pingHost) ?? "https://www.google.com"
        url = URL(string: host) ?? URL(string: "https://www.google.com")!

        let intervalValue = defaults.double(forKey: UserDefaultsKey.pingInterval)
        interval = intervalValue > 0 ? intervalValue : 5.0

        let threshold = defaults.integer(forKey: UserDefaultsKey.highPingThreshold).nonZeroOr(200)
        highPingThresholdValue = max(1, threshold)

        packetLossMode = PacketLossMode(rawValue: defaults.string(forKey: UserDefaultsKey.packetLossMode) ?? "") ?? .passive
        packetLossWindowSize = clampValue(defaults.integer(forKey: UserDefaultsKey.packetLossWindowSize).nonZeroOr(50), min: 10, max: 500)
        packetLossProbeInterval = max(1.0, defaults.double(forKey: UserDefaultsKey.packetLossProbeInterval).nonZeroOr(30.0))
        packetLossBurstSize = clampValue(defaults.integer(forKey: UserDefaultsKey.packetLossBurstSize).nonZeroOr(5), min: 1, max: 100)

        let warningThreshold = defaults.double(forKey: UserDefaultsKey.packetLossWarningThreshold).nonZeroOr(3.0)
        let badThreshold = defaults.double(forKey: UserDefaultsKey.packetLossBadThreshold).nonZeroOr(10.0)
        lossTracker.updateConfiguration(.init(
            windowSize: packetLossWindowSize,
            warningThreshold: warningThreshold,
            badThreshold: badThreshold
        ))

        if previousMode != packetLossMode {
            lossTracker.reset()
            onPacketLossUpdated?()
        }

        if restartIfRunning, wasRunning {
            start()
        }
    }

    func start() {
        stop()
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.ping()
            }
        }

        if packetLossMode == .active {
            activeBurstTimer = Timer.scheduledTimer(withTimeInterval: packetLossProbeInterval, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.runActiveBurst()
                }
            }
        }

        ping()
        if packetLossMode == .active {
            runActiveBurst()
        }
    }

    func stop() {
        lifecycleGeneration += 1
        isRunning = false
        timer?.invalidate()
        timer = nil
        activeBurstTimer?.invalidate()
        activeBurstTimer = nil
        currentPingTask?.cancel()
        currentPingTask = nil
        activeBurstTasks.forEach { $0.cancel() }
        activeBurstTasks.removeAll()
        isActiveBurstInFlight = false
    }

    var currentHost: String {
        url.host ?? url.absoluteString
    }

    func getRecentPings() -> [Int] {
        recentPings
    }

    private func ping() {
        let generation = lifecycleGeneration
        let task = makeProbeTask(for: url, captureLatency: true) { [weak self] success, latencyMs in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.lifecycleGeneration == generation else { return }
                self.currentPingTask = nil
                if success {
                    self.handleSuccessfulPing(latencyMs: latencyMs ?? 0)
                } else {
                    self.handleFailedPing(generation: generation)
                }
            }
        }
        currentPingTask = task
        task.resume()
    }

    private func handleSuccessfulPing(latencyMs: Int) {
        lastPingFailedAt = nil
        latestMainStatus = latencyMs > highPingThresholdValue ? .warning : .good
        recentPings.append(latencyMs)
        if recentPings.count > maxRecentPings {
            recentPings.removeFirst(recentPings.count - maxRecentPings)
        }

        let result = PingResult(
            status: latestMainStatus,
            message: "Ping: \(latencyMs)ms",
            latencyMs: latencyMs,
            success: true,
            countsAsLoss: true
        )
        recordPassiveLossIfNeeded(result)
        onPingResult?(result)
    }

    private func handleFailedPing(generation: Int) {
        detectCaptivePortal { [weak self] isCaptive in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.lifecycleGeneration == generation else { return }
                if isCaptive {
                    self.latestMainStatus = .captivePortal
                    let result = PingResult(
                        status: .captivePortal,
                        message: "Captive Portal Detected",
                        latencyMs: nil,
                        success: false,
                        countsAsLoss: false
                    )
                    self.recordPassiveLossIfNeeded(result)
                    self.onPingResult?(result)
                } else {
                    self.latestMainStatus = .bad
                    if self.lastPingFailedAt == nil {
                        self.lastPingFailedAt = Date()
                    }
                    let downFor = Int(Date().timeIntervalSince(self.lastPingFailedAt ?? Date()))
                    let result = PingResult(
                        status: .bad,
                        message: "No Network (\(downFor)s)",
                        latencyMs: nil,
                        success: false,
                        countsAsLoss: true
                    )
                    self.recordPassiveLossIfNeeded(result)
                    self.onPingResult?(result)
                }
            }
        }
    }

    private func recordPassiveLossIfNeeded(_ result: PingResult) {
        guard packetLossMode == .passive else { return }
        lossTracker.record(success: result.success, isCountable: result.countsAsLoss)
    }

    private func runActiveBurst() {
        guard packetLossMode == .active else { return }
        guard latestMainStatus != .captivePortal else { return }
        guard !isActiveBurstInFlight else { return }

        let generation = lifecycleGeneration
        isActiveBurstInFlight = true
        activeBurstTasks.removeAll()

        let group = DispatchGroup()
        let counter = BurstCounter()

        for _ in 0..<packetLossBurstSize {
            group.enter()
            let task = makeProbeTask(for: url, captureLatency: false) { success, _ in
                counter.record(success: success)
                group.leave()
            }
            activeBurstTasks.append(task)
            task.resume()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self, self.lifecycleGeneration == generation else { return }
            self.activeBurstTasks.removeAll()
            self.isActiveBurstInFlight = false
            guard self.packetLossMode == .active, self.latestMainStatus != .captivePortal else { return }
            let summary = counter.snapshot()
            for _ in 0..<summary.successes {
                self.lossTracker.record(success: true)
            }
            for _ in 0..<summary.failures {
                self.lossTracker.record(success: false)
            }
            self.onPacketLossUpdated?()
        }
    }

    private func makeProbeTask(
        for targetURL: URL,
        captureLatency: Bool,
        completion: @escaping @Sendable (Bool, Int?) -> Void
    ) -> URLSessionDataTask {
        let start = captureLatency ? Date() : nil
        var request = URLRequest(url: targetURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3.0
        return URLSession.shared.dataTask(with: request) { _, _, error in
            let latencyMs = start.map { Int(Date().timeIntervalSince($0) * 1000) }
            completion(error == nil, error == nil ? latencyMs : nil)
        }
    }

    private func detectCaptivePortal(completion: @escaping @Sendable (Bool) -> Void) {
        guard let captiveURL = URL(string: "http://www.gstatic.com/generate_204") else {
            completion(false)
            return
        }
        var request = URLRequest(url: captiveURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0
        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                completion(http.statusCode != 204)
            } else {
                completion(false)
            }
        }
        task.resume()
    }
}

private final class BurstCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var successes = 0
    private var failures = 0

    func record(success: Bool) {
        lock.lock()
        if success {
            successes += 1
        } else {
            failures += 1
        }
        lock.unlock()
    }

    func snapshot() -> (successes: Int, failures: Int) {
        lock.lock()
        let result = (successes, failures)
        lock.unlock()
        return result
    }
}

private extension BinaryInteger {
    func nonZeroOr<T: BinaryInteger>(_ fallback: T) -> T {
        self > 0 ? T(self) : fallback
    }
}

private extension BinaryFloatingPoint {
    func nonZeroOr<T: BinaryFloatingPoint>(_ fallback: T) -> T {
        self > 0 ? T(self) : fallback
    }
}

private func clampValue<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
    Swift.max(minValue, Swift.min(value, maxValue))
}
