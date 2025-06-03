import XCTest
@testable import PingBarLib

final class SparklineRendererTests: XCTestCase {
    
    func testEmptyPings() {
        let result = SparklineRenderer.renderSparkline(pings: [])
        XCTAssertEqual(result, "")
    }
    
    func testSinglePing() {
        let result = SparklineRenderer.renderSparkline(pings: [100])
        XCTAssertEqual(result, "▁")
    }
    
    func testIdenticalPings() {
        let result = SparklineRenderer.renderSparkline(pings: [100, 100, 100])
        XCTAssertEqual(result, "▁▁▁")
    }
    
    func testVariedPings() {
        let pings = [10, 50, 100, 150, 200]
        let result = SparklineRenderer.renderSparkline(pings: pings)
        
        // Should render as increasing sparkline
        XCTAssertEqual(result.count, 5)
        XCTAssertTrue(result.contains("▁"))
        XCTAssertTrue(result.contains("█"))
    }
    
    func testMinMaxRange() {
        let pings = [1, 1000] // Large range
        let result = SparklineRenderer.renderSparkline(pings: pings)
        
        XCTAssertEqual(result, "▁█")
    }
}