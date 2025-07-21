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
        return true
    }

    private static func isRoutableIPv6(_ addr: in6_addr) -> Bool {
        let addrBytes = Mirror(reflecting: addr.__u6_addr.__u6_addr8).children.map { $0.value as! UInt8 }
        return !addrBytes.starts(with: [0xfe, 0x80]) // link-local
    }

    static func currentDNSResolvers() -> [String] {
        var resolvers: [String] = []

        if let file = fopen("/etc/resolv.conf", "r") {
            defer { fclose(file) }
            var line: UnsafeMutablePointer<CChar>?
            var linecap: Int = 0
            var buffer: UnsafeMutablePointer<CChar>? = nil
            while getline(&buffer, &linecap, file) > 0 {
                line = buffer
                if let lineStr = line.flatMap({ String(cString: $0).trimmingCharacters(in: .whitespacesAndNewlines) }),
                   lineStr.hasPrefix("nameserver") {
                    let parts = lineStr.components(separatedBy: .whitespaces)
                    if parts.count >= 2 {
                        resolvers.append(parts[1])
                    }
                }
            }
            free(buffer)
        }

        return resolvers
    }

static func networkServiceName(for interface: String) -> String? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    task.arguments = ["-listnetworkserviceorder"]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    do {
        try task.run()
    } catch {
        print("Failed to run networksetup: \(error)")
        return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else { return nil }

    // Regex to match: (n) Service Name (Hardware Port: ..., Device: enX)
    let pattern = #"^\(\d+\)\s(.+?)\s+\(Hardware Port:.*?, Device: \b\#(interface)\b\)"#
    let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])

    if let match = regex?.firstMatch(in: output, range: NSRange(location: 0, length: output.utf16.count)),
       let range = Range(match.range(at: 1), in: output) {
        return String(output[range])
    }

    return nil
}

    static func defaultInterface() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
        process.arguments = ["-rn"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            print("Failed to run netstat: \(error)")
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        for line in output.components(separatedBy: "\n") {
            if line.starts(with: "default") {
                let components = line.split(separator: " ", omittingEmptySubsequences: true)
                if let iface = components.last {
                    return String(iface)
                }
            }
        }
        return nil
    }
}
