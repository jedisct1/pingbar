import Foundation

struct NetworkUtilities {

    static func localInterfaceAddresses() -> [(String, String)] {
        var results: [(String, String)] = []
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return results }
        defer { freeifaddrs(firstAddr) }
        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            let name = String(cString: ptr.pointee.ifa_name)
            if (flags & IFF_UP) == IFF_UP && (flags & IFF_LOOPBACK) == 0 {
                if addr.sa_family == UInt8(AF_INET) {
                    let sin = UnsafeRawPointer(ptr.pointee.ifa_addr).assumingMemoryBound(to: sockaddr_in.self).pointee
                    let ip = String(cString: inet_ntoa(sin.sin_addr))
                    if isRoutableIPv4(sin.sin_addr) && !ip.isEmpty {
                        results.append((name, ip))
                    }
                } else if addr.sa_family == UInt8(AF_INET6) {
                    var sin6 = UnsafeRawPointer(ptr.pointee.ifa_addr).assumingMemoryBound(to: sockaddr_in6.self).pointee
                    var ipBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    let ipPtr = inet_ntop(AF_INET6, &sin6.sin6_addr, &ipBuffer, socklen_t(INET6_ADDRSTRLEN))
                    if let ipPtr {
                        let ip = String(cString: ipPtr)
                        if isRoutableIPv6(sin6.sin6_addr) && !ip.isEmpty {
                            results.append((name, ip))
                        }
                    }
                }
            }
            if let next = ptr.pointee.ifa_next {
                ptr = next
            } else {
                break
            }
        }
        return results
    }

    private static func isRoutableIPv4(_ addr: in_addr) -> Bool {
        let ip = UInt32(bigEndian: addr.s_addr)
        if ip == 0 { return false }
        if (ip & 0xff000000) == 0x7f000000 { return false }
        if (ip & 0xffff0000) == 0xa9fe0000 { return false }
        if (ip & 0xf0000000) == 0xe0000000 { return false }
        if ip == 0xffffffff { return false }
        return true
    }

    private static func isRoutableIPv6(_ addr: in6_addr) -> Bool {
        let addrBytes = withUnsafeBytes(of: addr) { Array($0) }
        if addrBytes.allSatisfy({ $0 == 0 }) { return false }
        if addrBytes[0] == 0 && addrBytes[15] == 1 && addrBytes[1...14].allSatisfy({ $0 == 0 }) { return false }
        if addrBytes[0] == 0xfe && (addrBytes[1] & 0xc0) == 0x80 { return false }
        if addrBytes[0] == 0xff { return false }
        return true
    }

    static func currentDNSResolvers() -> [String] {
        var resolvers: [String] = []
        guard let file = fopen("/etc/resolv.conf", "r") else { return resolvers }
        defer { fclose(file) }
        var linePtr: UnsafeMutablePointer<CChar>?
        var n: size_t = 0
        while getline(&linePtr, &n, file) > 0 {
            if let line = linePtr {
                let str = String(cString: line).trimmingCharacters(in: .whitespacesAndNewlines)
                if str.hasPrefix("nameserver ") {
                    let parts = str.components(separatedBy: .whitespaces)
                    if parts.count > 1 {
                        resolvers.append(parts[1])
                    }
                }
            }
        }
        if let linePtr = linePtr {
            free(linePtr)
        }
        return resolvers
    }

    static var defaultInterface: String? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else { return nil }
        defer { freeifaddrs(firstAddr) }
        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            let name = String(cString: ptr.pointee.ifa_name)
            if (flags & IFF_UP) == IFF_UP && (flags & IFF_LOOPBACK) == 0 && addr.sa_family == UInt8(AF_INET) {
                return name
            }
            if let next = ptr.pointee.ifa_next {
                ptr = next
            } else {
                break
            }
        }
        return nil
    }

    static func networkServiceName(for bsdName: String) -> String? {
        let task = Process()
        let pipe = Pipe()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-listallhardwareports"]
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        let lines = output.components(separatedBy: .newlines)
        var currentService: String?
        for line in lines {
            if line.hasPrefix("Hardware Port: ") {
                currentService = line.replacingOccurrences(of: "Hardware Port: ", with: "")
            } else if line.hasPrefix("Device: ") {
                let dev = line.replacingOccurrences(of: "Device: ", with: "")
                if dev == bsdName, let svc = currentService {
                    return svc
                }
            }
        }
        return nil
    }
}