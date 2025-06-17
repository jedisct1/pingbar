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

    static func setDNSWithOsascript(service: String, dnsArg: String) -> (success: Bool, message: String) {
        let dnsString = dnsArg == "Empty" ? "Empty" : dnsArg
        let command = "/usr/sbin/networksetup -setdnsservers \"\(service)\" \(dnsString)"
        let escapedCommand = escapeForAppleScript(command)
        
        // Create a descriptive prompt for the authorization dialog
        let dnsDescription = dnsArg == "Empty" ? "System Default" : displayName(for: dnsArg)
        let promptMessage = "PingBar is changing DNS settings for \(service) to \(dnsDescription)"
        
        // Use the prompt parameter in the do shell script command
        let promptScript = """
        do shell script "\(escapedCommand)" with administrator privileges with prompt "\(promptMessage)"
        """
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", promptScript]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if task.terminationStatus == 0 {
            return (true, "DNS settings updated")
        } else {
            if output.contains("User cancelled") || output.contains("canceled") {
                return (false, "Operation cancelled by user")
            }
            return (false, output.isEmpty ? "Failed to update DNS settings" : output)
        }
    }

    private static func escapeForAppleScript(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
    }
}