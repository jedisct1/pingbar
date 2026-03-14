import XCTest
@testable import PingBarLib

final class LossTrackerTests: XCTestCase {

    func testInitialState() {
        let tracker = LossTracker()
        XCTAssertEqual(tracker.lossPercent, 0.0)
        XCTAssertEqual(tracker.level, .good)
        XCTAssertEqual(tracker.sampleCount, 0)
        XCTAssertFalse(tracker.hasEnoughSamples)
    }

    func testAllSuccessZeroLoss() {
        let tracker = LossTracker(config: .init(windowSize: 20, warningThreshold: 3.0, badThreshold: 10.0))
        for _ in 0..<20 {
            tracker.record(success: true)
        }
        XCTAssertEqual(tracker.lossPercent, 0.0)
        XCTAssertEqual(tracker.level, .good)
        XCTAssertEqual(tracker.sampleCount, 20)
        XCTAssertTrue(tracker.hasEnoughSamples)
    }

    func testAllFailureFullLoss() {
        let tracker = LossTracker(config: .init(windowSize: 10, warningThreshold: 3.0, badThreshold: 10.0))
        for _ in 0..<10 {
            tracker.record(success: false)
        }
        XCTAssertEqual(tracker.lossPercent, 100.0)
        XCTAssertEqual(tracker.level, .bad)
    }

    func testMixedResults() {
        let tracker = LossTracker(config: .init(windowSize: 20, warningThreshold: 3.0, badThreshold: 10.0))
        // 18 success + 2 failure = 10% loss
        for _ in 0..<18 {
            tracker.record(success: true)
        }
        for _ in 0..<2 {
            tracker.record(success: false)
        }
        XCTAssertEqual(tracker.lossPercent, 10.0)
        XCTAssertEqual(tracker.level, .bad)
    }

    func testWarningThreshold() {
        // 5% loss with warning at 3% and bad at 10%
        let tracker = LossTracker(config: .init(windowSize: 20, warningThreshold: 3.0, badThreshold: 10.0))
        for _ in 0..<19 {
            tracker.record(success: true)
        }
        tracker.record(success: false) // 1/20 = 5%
        XCTAssertEqual(tracker.lossPercent, 5.0)
        XCTAssertEqual(tracker.level, .warning)
    }

    func testNonCountableSamplesIgnored() {
        let tracker = LossTracker(config: .init(windowSize: 20, warningThreshold: 3.0, badThreshold: 10.0))
        tracker.record(success: true)
        tracker.record(success: false, isCountable: false) // captive portal — ignored
        tracker.record(success: false, isCountable: false) // ignored
        tracker.record(success: true)

        XCTAssertEqual(tracker.sampleCount, 2)
        XCTAssertEqual(tracker.lossPercent, 0.0)
        XCTAssertEqual(tracker.level, .good)
    }

    func testWindowSlidingEvictsOldResults() {
        let tracker = LossTracker(config: .init(windowSize: 10, warningThreshold: 3.0, badThreshold: 10.0))

        // Fill window with 10 failures
        for _ in 0..<10 {
            tracker.record(success: false)
        }
        XCTAssertEqual(tracker.lossPercent, 100.0)

        // Push 10 successes — failures slide out
        for _ in 0..<10 {
            tracker.record(success: true)
        }
        XCTAssertEqual(tracker.sampleCount, 10)
        XCTAssertEqual(tracker.lossPercent, 0.0)
        XCTAssertEqual(tracker.level, .good)
    }

    func testReset() {
        let tracker = LossTracker(config: .init(windowSize: 10, warningThreshold: 3.0, badThreshold: 10.0))
        for _ in 0..<10 {
            tracker.record(success: false)
        }
        XCTAssertEqual(tracker.level, .bad)

        tracker.reset()
        XCTAssertEqual(tracker.sampleCount, 0)
        XCTAssertEqual(tracker.lossPercent, 0.0)
        XCTAssertEqual(tracker.level, .good)
        XCTAssertFalse(tracker.hasEnoughSamples)
    }

    func testUpdateConfigurationTrimsWindow() {
        let tracker = LossTracker(config: .init(windowSize: 50, warningThreshold: 3.0, badThreshold: 10.0))
        for _ in 0..<30 {
            tracker.record(success: true)
        }
        XCTAssertEqual(tracker.sampleCount, 30)

        // Shrink window — oldest samples evicted
        tracker.updateConfiguration(.init(windowSize: 10, warningThreshold: 3.0, badThreshold: 10.0))
        XCTAssertEqual(tracker.sampleCount, 10)
    }

    func testConfigurationClampingMinWindowSize() {
        // windowSize below minimum 10 should be clamped
        let tracker = LossTracker(config: .init(windowSize: 2, warningThreshold: 3.0, badThreshold: 10.0))
        for _ in 0..<15 {
            tracker.record(success: true)
        }
        // Window clamped to 10, so 15 samples should be trimmed to 10
        XCTAssertEqual(tracker.sampleCount, 10)
    }

    func testConfigurationClampingMaxWindowSize() {
        // windowSize above maximum 500 should be clamped
        let tracker = LossTracker(config: .init(windowSize: 1000, warningThreshold: 3.0, badThreshold: 10.0))
        for _ in 0..<600 {
            tracker.record(success: true)
        }
        XCTAssertEqual(tracker.sampleCount, 500)
    }

    func testConfigurationClampingBadThresholdAboveWarning() {
        // bad threshold must be at least warning + 0.1
        let tracker = LossTracker(config: .init(windowSize: 20, warningThreshold: 10.0, badThreshold: 5.0))
        // 10% loss: bad threshold was clamped to 10.1, so at exactly 10% this is warning not bad
        for _ in 0..<18 {
            tracker.record(success: true)
        }
        for _ in 0..<2 {
            tracker.record(success: false)
        }
        XCTAssertEqual(tracker.lossPercent, 10.0)
        XCTAssertEqual(tracker.level, .warning) // 10.0 < 10.1 (clamped bad threshold)
    }

    func testHasEnoughSamples() {
        let tracker = LossTracker()
        XCTAssertFalse(tracker.hasEnoughSamples)
        for _ in 0..<9 {
            tracker.record(success: true)
        }
        XCTAssertFalse(tracker.hasEnoughSamples)
        tracker.record(success: true)
        XCTAssertTrue(tracker.hasEnoughSamples)
    }

    func testExactThresholdBoundaries() {
        // Exactly at warning threshold should be warning
        let config = LossTracker.Configuration(windowSize: 100, warningThreshold: 5.0, badThreshold: 10.0)
        let tracker = LossTracker(config: config)
        for _ in 0..<95 { tracker.record(success: true) }
        for _ in 0..<5 { tracker.record(success: false) }
        XCTAssertEqual(tracker.lossPercent, 5.0)
        XCTAssertEqual(tracker.level, .warning)
    }
}
