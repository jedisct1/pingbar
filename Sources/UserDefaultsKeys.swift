import Foundation

enum UserDefaultsKey {
    // Existing keys
    static let pingHost = "PingHost"
    static let pingInterval = "PingInterval"
    static let highPingThreshold = "HighPingThreshold"
    static let customDNSServer = "CustomDNSServer"
    static let revertDNSOnCaptivePortal = "RevertDNSOnCaptivePortal"
    static let restoreCustomDNSAfterCaptive = "RestoreCustomDNSAfterCaptive"
    static let launchAtLogin = "LaunchAtLogin"
    static let lastCustomDNS = "LastCustomDNS"

    // Packet loss keys
    static let packetLossMode = "PacketLossMode"
    static let packetLossWindowSize = "PacketLossWindowSize"
    static let packetLossWarningThreshold = "PacketLossWarningThreshold"
    static let packetLossBadThreshold = "PacketLossBadThreshold"
    static let packetLossProbeInterval = "PacketLossProbeInterval"
    static let packetLossBurstSize = "PacketLossBurstSize"

    // Biometric auth
    static let requireBiometricForDNS = "RequireBiometricForDNS"
}
