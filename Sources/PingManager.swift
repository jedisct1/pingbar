import Foundation

@MainActor
final class PingManager {
    private var timer: Timer?
    private var url: URL
    private var interval: TimeInterval
    private var lastPingFailedAt: Date?
    var onPingResult: ((PingStatus, String) -> Void)?
    var highPingThreshold: Int {
        get { UserDefaults.standard.integer(forKey: "HighPingThreshold").nonZeroOr(200) }
        set { UserDefaults.standard.set(newValue, forKey: "HighPingThreshold") }
    }
    enum PingStatus {
        case good, warning, bad, captivePortal
    }
    private(set) var recentPings: [Int] = []
    private let maxRecentPings = 30

    init() {
        let host = UserDefaults.standard.string(forKey: "PingHost") ?? "https://www.google.com"
        self.url = URL(string: host) ?? URL(string: "https://www.google.com")!
        let intervalValue = UserDefaults.standard.double(forKey: "PingInterval")
        self.interval = intervalValue > 0 ? intervalValue : 5.0
    }

    func updateSettings(host: String, interval: TimeInterval) {
        url = URL(string: host) ?? URL(string: "https://www.google.com")!
        self.interval = interval
        start()
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.ping()
            }
        }
        ping()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func ping() {
        let start = Date()
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3.0
        let task = URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if error != nil {
                    self.detectCaptivePortal { @Sendable [weak self] isCaptive in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            if isCaptive {
                                self.onPingResult?(.captivePortal, "Captive Portal Detected")
                            } else {
                                if self.lastPingFailedAt == nil {
                                    self.lastPingFailedAt = Date()
                                }
                                let downFor = Int(Date().timeIntervalSince(self.lastPingFailedAt ?? Date()))
                                self.onPingResult?(.bad, "No Network (\(downFor)s)")
                            }
                        }
                    }
                } else {
                    self.lastPingFailedAt = nil
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    self.recentPings.append(ms)
                    if self.recentPings.count > self.maxRecentPings {
                        self.recentPings.removeFirst(self.recentPings.count - self.maxRecentPings)
                    }
                    let status: PingStatus = ms > self.highPingThreshold ? .warning : .good
                    self.onPingResult?(status, "Ping: \(ms)ms")
                }
            }
        }
        task.resume()
    }

    private func detectCaptivePortal(completion: @escaping @Sendable (Bool) -> Void) {
        guard let url = URL(string: "http://www.gstatic.com/generate_204") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0
        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            Task { @MainActor in
                if let http = response as? HTTPURLResponse {
                    completion(http.statusCode != 204)
                } else {
                    completion(false)
                }
            }
        }
        task.resume()
    }

    var currentHost: String {
        url.host ?? url.absoluteString
    }

    func getRecentPings() -> [Int] {
        recentPings
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int {
        self > 0 ? self : fallback
    }
}