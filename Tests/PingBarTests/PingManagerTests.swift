import XCTest
@testable import PingBarLib

@MainActor
final class PingManagerTests: XCTestCase {

    var pingManager: PingManager!

    override func setUp() {
        super.setUp()
        clearDefaults()
        pingManager = PingManager()
    }

    override func tearDown() {
        pingManager.stop()
        pingManager = nil
        clearDefaults()
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertNotNil(pingManager)
        XCTAssertEqual(pingManager.currentHost, "www.google.com")
        XCTAssertEqual(pingManager.highPingThreshold, 200)
        XCTAssertEqual(pingManager.packetLossMode, .passive)
        XCTAssertEqual(pingManager.packetLossWindowSize, 50)
    }

    func testUpdateSettings() {
        let newHost = "https://www.example.com"
        let newInterval = 10.0

        pingManager.updateSettings(host: newHost, interval: newInterval)

        XCTAssertEqual(pingManager.currentHost, "www.example.com")
    }

    func testHighPingThresholdUpdate() {
        let newThreshold = 150
        pingManager.highPingThreshold = newThreshold
        XCTAssertEqual(pingManager.highPingThreshold, newThreshold)
    }

    func testReloadSettingsUsesPacketLossDefaults() {
        UserDefaults.standard.set(PingManager.PacketLossMode.active.rawValue, forKey: UserDefaultsKey.packetLossMode)
        UserDefaults.standard.set(80, forKey: UserDefaultsKey.packetLossWindowSize)
        UserDefaults.standard.set(4.0, forKey: UserDefaultsKey.packetLossWarningThreshold)
        UserDefaults.standard.set(12.0, forKey: UserDefaultsKey.packetLossBadThreshold)
        UserDefaults.standard.set(2.0, forKey: UserDefaultsKey.packetLossProbeInterval)
        UserDefaults.standard.set(9, forKey: UserDefaultsKey.packetLossBurstSize)

        pingManager.reloadSettingsFromDefaults(restartIfRunning: false)

        XCTAssertEqual(pingManager.packetLossMode, .active)
        XCTAssertEqual(pingManager.packetLossWindowSize, 80)
    }

    func testReloadSettingsResetsLossTrackerWhenModeChanges() {
        pingManager.lossTracker.record(success: false)
        pingManager.lossTracker.record(success: false)
        pingManager.lossTracker.record(success: false)
        XCTAssertEqual(pingManager.lossTracker.sampleCount, 3)

        UserDefaults.standard.set(PingManager.PacketLossMode.active.rawValue, forKey: UserDefaultsKey.packetLossMode)
        pingManager.reloadSettingsFromDefaults(restartIfRunning: false)

        XCTAssertEqual(pingManager.lossTracker.sampleCount, 0)
        XCTAssertEqual(pingManager.packetLossMode, .active)
    }

    func testRecentPingsTracking() {
        // Initially empty
        XCTAssertTrue(pingManager.recentPings.isEmpty)

        // Simulate adding pings (would normally come from network requests)
        // This test would need to be expanded with proper mocking for actual network tests
    }

    private func clearDefaults() {
        let keys = [
            UserDefaultsKey.highPingThreshold,
            UserDefaultsKey.pingHost,
            UserDefaultsKey.pingInterval,
            UserDefaultsKey.packetLossMode,
            UserDefaultsKey.packetLossWindowSize,
            UserDefaultsKey.packetLossWarningThreshold,
            UserDefaultsKey.packetLossBadThreshold,
            UserDefaultsKey.packetLossProbeInterval,
            UserDefaultsKey.packetLossBurstSize
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
