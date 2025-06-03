import Foundation

struct DNSManager {
    
    static let dnsNameMap: [String: String] = [
        "1.1.1.1": "Cloudflare",
        "8.8.8.8": "Google",
        "9.9.9.9": "Quad9",
        "127.0.0.1": "dnscrypt-proxy",
        "114.114.114.114": "114DNS"
    ]
    
    static func setDNSWithOsascript(service: String, dnsArg: String) -> (success: Bool, message: String) {
        let dnsString = dnsArg == "Empty" ? "Empty" : dnsArg
        let command = "/usr/sbin/networksetup -setdnsservers \"\(service)\" \(dnsString)"
        let escapedCommand = escapeForAppleScript(command)
        let script = "do shell script \"\(escapedCommand)\" with administrator privileges"
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if task.terminationStatus == 0 {
            return (true, output)
        } else {
            return (false, output.isEmpty ? "Unknown error. You may need to enter your password or run the app as an administrator." : output)
        }
    }

    private static func escapeForAppleScript(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
    }
}