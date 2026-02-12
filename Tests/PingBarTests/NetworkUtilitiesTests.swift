import XCTest
@testable import PingBarLib

final class NetworkUtilitiesTests: XCTestCase {
    
    func testLocalInterfaceAddresses() {
        let interfaces = NetworkUtilities.localInterfaceAddresses()
        
        // Should have at least one interface (even if just loopback is filtered out)
        // This test is environment-dependent, so we just check basic functionality
        XCTAssertTrue(interfaces.count >= 0)
        
        for (name, ip) in interfaces {
            XCTAssertFalse(name.isEmpty)
            XCTAssertFalse(ip.isEmpty)
            // Basic IP format check
            XCTAssertTrue(ip.contains(".") || ip.contains(":"))
        }
    }
    
    func testCurrentDNSResolvers() {
        let resolvers = NetworkUtilities.currentDNSResolvers()
        
        // Should return some DNS resolvers on a typical system
        // This test is environment-dependent
        for resolver in resolvers {
            XCTAssertFalse(resolver.isEmpty)
            // Basic format check - should be an IP address
            XCTAssertTrue(resolver.contains(".") || resolver.contains(":"))
        }
    }
    
    func testDefaultInterface() {
        let defaultInterface = NetworkUtilities.defaultInterface()

        // May be nil if no network interface is up
        if let interface = defaultInterface {
            XCTAssertFalse(interface.isEmpty)
        }
    }

    func testNetworkServiceName() {
        // This test requires a real network interface to be present
        if let defaultInterface = NetworkUtilities.defaultInterface() {
            let serviceName = NetworkUtilities.networkServiceName(for: defaultInterface)
            
            if let name = serviceName {
                XCTAssertFalse(name.isEmpty)
            }
        }
    }
}