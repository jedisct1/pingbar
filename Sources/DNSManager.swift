import Foundation

struct DNSManager {

    static let dnsNameMap: [String: String] = [
        "1.1.1.1": "Cloudflare",
        "8.8.8.8": "Google",
        "9.9.9.9": "Quad9",
        "127.0.0.1": "dnscrypt-proxy",
        "114.114.114.114": "114DNS"
    ]

    static func displayName(for dnsServer: String) -> String {
        // Check if it's a predefined DNS server
        if let name = dnsNameMap[dnsServer] {
            return name
        }

        // Check if there's a custom DNS server configured
        let customDNS = UserDefaults.standard.string(forKey: "CustomDNSServer") ?? ""
        if !customDNS.isEmpty {
            // If the custom DNS contains a space, treat it as "IP Name" format
            let components = customDNS.components(separatedBy: " ")
            if components.count >= 2 {
                let ip = components[0]
                let name = components.dropFirst().joined(separator: " ")
                if dnsServer == ip {
                    return name
                }
            } else if dnsServer == customDNS {
                // If custom DNS is just an IP, return "Custom (IP)"
                return "Custom (\(customDNS))"
            }
        }

        // Default to returning the IP address itself
        return dnsServer
    }

    static func getCustomDNSIP() -> String? {
        let customDNS = UserDefaults.standard.string(forKey: "CustomDNSServer") ?? ""
        if customDNS.isEmpty {
            return nil
        }

        // If the custom DNS contains a space, extract the IP part
        let components = customDNS.components(separatedBy: " ")
        return components[0]
    }

    static func setDNS(service: String, dnsArg: String) -> (success: Bool, message: String) {
        let dnsString = dnsArg == "Empty" ? "Empty" : dnsArg

        let result = runNetworkSetup(service: service, dnsString: dnsString)
        if result.success {
            return result
        }

        let needsPrivileges = result.message.contains("requires") ||
            result.message.contains("permission") ||
            result.message.contains("not allowed") ||
            result.message.contains("Operation not permitted")
        if !needsPrivileges {
            return result
        }

        return runNetworkSetupPrivileged(service: service, dnsString: dnsString)
    }

    private static func runNetworkSetup(service: String, dnsString: String) -> (success: Bool, message: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-setdnsservers", service, dnsString]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
        } catch {
            return (false, error.localizedDescription)
        }
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if task.terminationStatus == 0 {
            return (true, "DNS settings updated")
        }
        return (false, output.isEmpty ? "Failed to update DNS settings" : output)
    }

    private static func runNetworkSetupPrivileged(service: String, dnsString: String) -> (success: Bool, message: String) {
        let command = "/usr/sbin/networksetup -setdnsservers \(shellQuote(service)) \(shellQuote(dnsString))"
        let escapedCommand = escapeForAppleScript(command)

        let dnsDescription = dnsString == "Empty" ? "System Default" : displayName(for: dnsString)
        let escapedPrompt = escapeForAppleScript("PingBar needs administrator privileges to change DNS for \(service) to \(dnsDescription)")

        let script = """
        do shell script "\(escapedCommand)" with administrator privileges with prompt "\(escapedPrompt)"
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
        } catch {
            return (false, error.localizedDescription)
        }
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if task.terminationStatus == 0 {
            return (true, "DNS settings updated")
        }
        if output.contains("User cancelled") || output.contains("canceled") {
            return (false, "Operation cancelled by user")
        }
        return (false, output.isEmpty ? "Failed to update DNS settings" : output)
    }

    private static func shellQuote(_ str: String) -> String {
        "'" + str.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func escapeForAppleScript(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
    }
}