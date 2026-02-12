import XCTest
@testable import PingBarLib

@MainActor
final class PingManagerTests: XCTestCase {
    
    var pingManager: PingManager!
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "HighPingThreshold")
        UserDefaults.standard.removeObject(forKey: "PingHost")
        UserDefaults.standard.removeObject(forKey: "PingInterval")
        pingManager = PingManager()
    }

    override func tearDown() {
        pingManager.stop()
        pingManager = nil
        UserDefaults.standard.removeObject(forKey: "HighPingThreshold")
        UserDefaults.standard.removeObject(forKey: "PingHost")
        UserDefaults.standard.removeObject(forKey: "PingInterval")
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertNotNil(pingManager)
        XCTAssertEqual(pingManager.currentHost, "www.google.com")
        XCTAssertEqual(pingManager.highPingThreshold, 200)
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
    
    func testRecentPingsTracking() {
        // Initially empty
        XCTAssertTrue(pingManager.getRecentPings().isEmpty)
        
        // Simulate adding pings (would normally come from network requests)
        // This test would need to be expanded with proper mocking for actual network tests
    }
}