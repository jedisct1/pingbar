import Foundation

/// Pure in-memory packet loss calculator.
/// Tracks a rolling window of success/failure results and computes loss percentage.
/// Contains no networking or timer logic — all configuration is passed in explicitly.
final class LossTracker {
    enum LossLevel {
        case good, warning, bad
    }

    struct Configuration {
        var windowSize: Int
        var warningThreshold: Double
        var badThreshold: Double

        static let `default` = Configuration(
            windowSize: 50,
            warningThreshold: 3.0,
            badThreshold: 10.0
        )

        /// Returns a copy with values clamped to safe ranges.
        func clamped() -> Configuration {
            Configuration(
                windowSize: max(10, min(windowSize, 500)),
                warningThreshold: max(0.1, warningThreshold),
                badThreshold: max(warningThreshold + 0.1, badThreshold)
            )
        }
    }

    private var window: [Bool] = []
    private var config: Configuration

    /// Current packet loss percentage (0.0–100.0).
    private(set) var lossPercent: Double = 0.0

    /// Current classified loss level.
    private(set) var level: LossLevel = .good

    /// Number of countable samples currently in the window.
    var sampleCount: Int { window.count }

    /// Whether enough samples have been collected for a meaningful reading.
    var hasEnoughSamples: Bool { window.count >= 3 }

    init(config: Configuration = .default) {
        self.config = config.clamped()
    }

    /// Record a probe result.
    /// - Parameters:
    ///   - success: Whether the probe succeeded.
    ///   - isCountable: If false, the result is ignored (e.g., captive portal detections).
    func record(success: Bool, isCountable: Bool = true) {
        guard isCountable else { return }

        window.append(success)
        if window.count > config.windowSize {
            window.removeFirst(window.count - config.windowSize)
        }
        recalculate()
    }

    /// Update configuration. Trims the window if the new size is smaller.
    func updateConfiguration(_ newConfig: Configuration) {
        config = newConfig.clamped()
        if window.count > config.windowSize {
            window.removeFirst(window.count - config.windowSize)
        }
        recalculate()
    }

    /// Clear all history and reset to initial state.
    func reset() {
        window.removeAll()
        lossPercent = 0.0
        level = .good
    }

    // MARK: - Private

    private func recalculate() {
        guard !window.isEmpty else {
            lossPercent = 0.0
            level = .good
            return
        }

        let failures = window.filter { !$0 }.count
        lossPercent = (Double(failures) / Double(window.count)) * 100.0

        if lossPercent >= config.badThreshold {
            level = .bad
        } else if lossPercent >= config.warningThreshold {
            level = .warning
        } else {
            level = .good
        }
    }
}
