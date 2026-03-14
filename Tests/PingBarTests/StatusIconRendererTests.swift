import XCTest
@testable import PingBarLib

@MainActor
final class StatusIconRendererTests: XCTestCase {

    func testRenderReturnsNonNilImageForAllCombinations() {
        let statuses: [PingManager.PingStatus] = [.good, .warning, .bad, .captivePortal]
        let levels: [LossTracker.LossLevel] = [.good, .warning, .bad]

        for status in statuses {
            for level in levels {
                let latencyMs: Int? = (status == .bad || status == .captivePortal) ? nil : 42
                let image = StatusIconRenderer.render(
                    latencyMs: latencyMs,
                    lossLevel: level,
                    pingStatus: status,
                    hasEnoughLossSamples: true
                )
                XCTAssertNotNil(image, "Icon should not be nil for status=\(status), level=\(level)")
                XCTAssertEqual(image.size.width, 18, "Icon width should be 18pt")
                XCTAssertEqual(image.size.height, 18, "Icon height should be 18pt")
            }
        }
    }

    func testRenderWithCollectingState() {
        // When not enough samples, ring should be neutral (gray) — should still return valid image
        let image = StatusIconRenderer.render(
            latencyMs: 50,
            lossLevel: .good,
            pingStatus: .good,
            hasEnoughLossSamples: false
        )
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 18)
    }

    func testRenderWithNilLatency() {
        let image = StatusIconRenderer.render(
            latencyMs: nil,
            lossLevel: .bad,
            pingStatus: .bad,
            hasEnoughLossSamples: true
        )
        XCTAssertNotNil(image)
    }

    func testRenderWithHighLatency() {
        let image = StatusIconRenderer.render(
            latencyMs: 1000,
            lossLevel: .good,
            pingStatus: .warning,
            hasEnoughLossSamples: true
        )
        XCTAssertNotNil(image)
    }
}
