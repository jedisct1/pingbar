import XCTest
@testable import PingBarLib

@MainActor
final class AppDelegateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.showNetworkInterfaces)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.customDNSServer)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.showNetworkInterfaces)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.customDNSServer)
        super.tearDown()
    }

    func testShowNetworkInterfacesDefaultsToTrueWhenUnset() {
        let appDelegate = AppDelegate()

        XCTAssertTrue(appDelegate.shouldShowNetworkInterfaces())
    }

    func testShowNetworkInterfacesUsesStoredValue() {
        UserDefaults.standard.set(false, forKey: UserDefaultsKey.showNetworkInterfaces)
        let appDelegate = AppDelegate()

        XCTAssertFalse(appDelegate.shouldShowNetworkInterfaces())
    }

    func testCurrentDNSSummaryUsesDisplayNames() {
        let appDelegate = AppDelegate()

        XCTAssertEqual(
            appDelegate.currentDNSSummary(from: ["1.1.1.1", "8.8.8.8"]),
            "Current: Cloudflare, Google"
        )
    }

    func testCurrentDNSSummaryHandlesMissingResolvers() {
        let appDelegate = AppDelegate()

        XCTAssertEqual(appDelegate.currentDNSSummary(from: []), "Current: Unavailable")
    }

    func testGraphTitleUsesDedicatedTrendLine() {
        let appDelegate = AppDelegate()
        let pings = [10, 50, 100, 75]

        XCTAssertEqual(
            appDelegate.graphTitle(for: pings),
            "Trend  \(SparklineRenderer.renderSparkline(pings: pings))"
        )
    }

    func testStatsTitleFormatsAvgMedianMinMaxForOddCount() {
        let appDelegate = AppDelegate()

        XCTAssertEqual(
            appDelegate.statsTitle(for: [10, 50, 100, 75, 20]),
            "avg 51ms | med 50ms | min 10ms | max 100ms"
        )
    }

    func testStatsTitleFormatsMedianForEvenCount() {
        let appDelegate = AppDelegate()

        XCTAssertEqual(
            appDelegate.statsTitle(for: [10, 20, 40, 100]),
            "avg 42ms | med 30ms | min 10ms | max 100ms"
        )
    }

    func testPacketLossTitleUsesSimplifiedReadableFormat() {
        let appDelegate = AppDelegate()

        XCTAssertEqual(
            appDelegate.packetLossTitle(
                lossPercent: 31.6,
                mode: "Passive",
                sampleCount: 19,
                windowSize: 50,
                hasEnoughSamples: true
            ),
            "Loss  31.6% | passive | 19/50"
        )
    }

    func testPacketLossTitleUsesCollectingStateFormat() {
        let appDelegate = AppDelegate()

        XCTAssertEqual(
            appDelegate.packetLossTitle(
                lossPercent: 0,
                mode: "Passive",
                sampleCount: 1,
                windowSize: 50,
                hasEnoughSamples: false
            ),
            "Loss  collecting | passive | 1/50"
        )
    }
}
