import Foundation

struct LaunchAgentManager {
    
    static func setLaunchAtLogin(enabled: Bool) {
        let fileManager = FileManager.default
        let label = "com.example.PingBar"
        guard let agentDir = (fileManager.homeDirectoryForCurrentUser as NSURL).appendingPathComponent("Library/LaunchAgents") else { return }
        let agentPlist = agentDir.appendingPathComponent("\(label).plist")
        let appPath = Bundle.main.bundlePath + "/Contents/MacOS/PingBar"
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [appPath],
            "RunAtLoad": true
        ]
        if enabled {
            try? fileManager.createDirectory(at: agentDir, withIntermediateDirectories: true)
            let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try? data?.write(to: agentPlist)
        } else {
            try? fileManager.removeItem(at: agentPlist)
        }
    }
}