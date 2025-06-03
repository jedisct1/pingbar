import XCTest
@testable import PingBarLib

final class DNSManagerTests: XCTestCase {
    
    func testDNSNameMapping() {
        XCTAssertEqual(DNSManager.dnsNameMap["1.1.1.1"], "Cloudflare")
        XCTAssertEqual(DNSManager.dnsNameMap["8.8.8.8"], "Google")
        XCTAssertEqual(DNSManager.dnsNameMap["9.9.9.9"], "Quad9")
        XCTAssertEqual(DNSManager.dnsNameMap["127.0.0.1"], "dnscrypt-proxy")
        XCTAssertEqual(DNSManager.dnsNameMap["114.114.114.114"], "114DNS")
    }
    
    func testDNSNameMappingUnknown() {
        XCTAssertNil(DNSManager.dnsNameMap["192.168.1.1"])
        XCTAssertNil(DNSManager.dnsNameMap["unknown.dns"])
    }
    
    // Note: We don't test setDNSWithOsascript here as it requires:
    // 1. Administrator privileges
    // 2. Actual system modification
    // 3. AppleScript execution
    // These would be better suited for integration tests or manual testing
}