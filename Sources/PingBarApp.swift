import Cocoa
import Foundation
import Security

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var pingManager: PingManager!
    private var pingMenuItem: NSMenuItem?
    private var packetLossMenuItem: NSMenuItem?
    private var preferencesWindow: PreferencesWindowController?
    private var preferencesMenuItem: NSMenuItem?
    private var ipMenuItems: [NSMenuItem] = []
    private var dnsMenuItem: NSMenuItem?
    private var dnsRevertedForOutage = false
    private var customDNSBeforeCaptive: String?
    private var graphMenuItem: NSMenuItem?
    private var latestLatencyMs: Int?
    private var latestPingStatus: PingManager.PingStatus = .bad

    nonisolated public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        pingManager = PingManager()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupStatusButton()
        renderIcon()

        let menu = NSMenu()
        menu.delegate = self

        let pingItem = NSMenuItem(title: "Checking...", action: nil, keyEquivalent: "")
        self.stylePingMenuItem(pingItem)
        menu.addItem(pingItem)

        let graphItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        self.styleGraphMenuItem(graphItem)
        menu.addItem(graphItem)

        let lossItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        self.styleGraphMenuItem(lossItem)
        menu.addItem(lossItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "⚙ Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        self.styleSystemMenuItem(prefsItem)
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "⏻ Quit PingBar", action: #selector(quit), keyEquivalent: "q")
        self.styleSystemMenuItem(quitItem)
        menu.addItem(quitItem)
        statusItem?.menu = menu
        self.pingMenuItem = pingItem
        self.graphMenuItem = graphItem
        self.packetLossMenuItem = lossItem
        self.preferencesMenuItem = prefsItem
        self.graphMenuItem?.isHidden = true
        self.packetLossMenuItem?.isHidden = true

        pingManager.onPingResult = { [weak self] result in
            guard let self else { return }
            let revertDNS = UserDefaults.standard.bool(forKey: UserDefaultsKey.revertDNSOnCaptivePortal)
            let restoreDNS = UserDefaults.standard.bool(forKey: UserDefaultsKey.restoreCustomDNSAfterCaptive)
            self.latestPingStatus = result.status
            self.latestLatencyMs = result.latencyMs
            let pings = self.pingManager.recentPings
            if !pings.isEmpty {
                let spark = SparklineRenderer.renderSparkline(pings: pings)
                let avg = pings.reduce(0, +) / pings.count
                let minPing = pings.min() ?? 0
                let maxPing = pings.max() ?? 0
                self.graphMenuItem?.title = "📊 \(spark)  ⌀ \(avg)ms  ↓ \(minPing)ms  ↑ \(maxPing)ms"
                if let graphItem = self.graphMenuItem {
                    self.styleGraphMenuItem(graphItem)
                }
                self.graphMenuItem?.isHidden = false
            } else {
                self.graphMenuItem?.title = ""
                self.graphMenuItem?.isHidden = true
            }
            switch result.status {
            case .good, .warning:
                if self.dnsRevertedForOutage, restoreDNS, let custom = self.customDNSBeforeCaptive, custom != "Empty" {
                    if let iface = NetworkUtilities.defaultInterface(), let service = NetworkUtilities.networkServiceName(for: iface) {
                        _ = DNSManager.setDNS(service: service, dnsArg: custom)
                        self.dnsRevertedForOutage = false
                        self.customDNSBeforeCaptive = nil
                    }
                } else {
                    self.dnsRevertedForOutage = false
                }
            case .bad:
                if revertDNS, !self.dnsRevertedForOutage {
                    if let iface = NetworkUtilities.defaultInterface(), let service = NetworkUtilities.networkServiceName(for: iface) {
                        let lastCustom = UserDefaults.standard.string(forKey: UserDefaultsKey.lastCustomDNS)
                        self.customDNSBeforeCaptive = (lastCustom != "Empty") ? lastCustom : nil
                        _ = DNSManager.setDNS(service: service, dnsArg: "Empty")
                        self.dnsRevertedForOutage = true
                    }
                }
            case .captivePortal:
                break
            }
            self.pingMenuItem?.title = result.message
            if let pingItem = self.pingMenuItem {
                self.stylePingMenuItem(pingItem)
            }
            self.refreshPacketLossMenuItem()
            self.renderIcon()
        }
        pingManager.onPacketLossUpdated = { [weak self] in
            guard let self else { return }
            self.refreshPacketLossMenuItem()
            self.renderIcon()
        }
        pingManager.start()

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    public func menuWillOpen(_ menu: NSMenu) {
        ipMenuItems.forEach(menu.removeItem)
        ipMenuItems.removeAll()
        if let dnsMenu = dnsMenuItem { menu.removeItem(dnsMenu) }
        guard let preferencesMenuItem, let baseInsertIndex = menu.items.firstIndex(of: preferencesMenuItem) else { return }
        var insertIndex = baseInsertIndex
        let ifaces = NetworkUtilities.localInterfaceAddresses()
        if !ifaces.isEmpty {
            for (idx, (iface, ip)) in ifaces.enumerated() {
                let ipItem = NSMenuItem(title: "🌐 \(iface): \(ip)", action: nil, keyEquivalent: "")
                self.styleInfoMenuItem(ipItem)
                menu.insertItem(ipItem, at: insertIndex + idx)
                ipMenuItems.append(ipItem)
            }
            let sep = NSMenuItem.separator()
            menu.insertItem(sep, at: insertIndex + ifaces.count)
            ipMenuItems.append(sep)
            insertIndex += ifaces.count + 1
        }
        let dnsResolvers = NetworkUtilities.currentDNSResolvers()
        if !dnsResolvers.isEmpty {
            let sep = NSMenuItem.separator()
            menu.insertItem(sep, at: insertIndex)
            ipMenuItems.append(sep)
            insertIndex += 1
            for (idx, dns) in dnsResolvers.enumerated() {
                let display = DNSManager.displayName(for: dns)
                let dnsItem = NSMenuItem(title: "🔍 DNS: \(display)", action: nil, keyEquivalent: "")
                self.styleInfoMenuItem(dnsItem)
                menu.insertItem(dnsItem, at: insertIndex + idx)
                ipMenuItems.append(dnsItem)
            }
            let sepAfter = NSMenuItem.separator()
            menu.insertItem(sepAfter, at: insertIndex + dnsResolvers.count)
            ipMenuItems.append(sepAfter)
            insertIndex += dnsResolvers.count + 1
        }
        let dnsMenu = NSMenu(title: "Set DNS for Default Interface")
        var dnsOptions: [(String, String?)] = [
            ("🏠 System Default", nil),
            ("🔒 dnscrypt-proxy (127.0.0.1)", "127.0.0.1"),
            ("☁️ Cloudflare (1.1.1.1)", "1.1.1.1"),
            ("🔍 Google (8.8.8.8)", "8.8.8.8"),
            ("🛡 Quad9 (9.9.9.9)", "9.9.9.9"),
            ("🌏 114DNS (114.114.114.114)", "114.114.114.114")
        ]

        // Add custom DNS if configured
        if let customDNSIP = DNSManager.getCustomDNSIP() {
            let displayName = DNSManager.displayName(for: customDNSIP)
            let menuTitle = "⚙️ \(displayName) (\(customDNSIP))"
            dnsOptions.append((menuTitle, customDNSIP))
        }

        let systemDefault = dnsOptions.removeFirst()
        let dnscryptProxy = dnsOptions.removeFirst()
        dnsOptions.sort { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
        dnsOptions.insert(dnscryptProxy, at: 0)
        dnsOptions.insert(systemDefault, at: 0)
        for (label, ip) in dnsOptions {
            let item = NSMenuItem(title: label, action: #selector(setDNS(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ip as AnyObject?
            self.styleDNSMenuItem(item)
            dnsMenu.addItem(item)
        }
        let dnsMenuItem = NSMenuItem(title: "🔧 Set DNS for Default Interface", action: nil, keyEquivalent: "")
        dnsMenuItem.submenu = dnsMenu
        self.styleSystemMenuItem(dnsMenuItem)
        menu.insertItem(dnsMenuItem, at: insertIndex)
        self.dnsMenuItem = dnsMenuItem
    }


    @MainActor
    @objc private func showPreferences(_ sender: Any?) {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController { [weak self] in
                self?.pingManager.reloadSettingsFromDefaults()
                self?.refreshPacketLossMenuItem()
                self?.renderIcon()
                self?.preferencesWindow = nil
                let launchAtLogin = UserDefaults.standard.bool(forKey: UserDefaultsKey.launchAtLogin)
                LaunchAgentManager.setLaunchAtLogin(enabled: launchAtLogin)
            }
        }
        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func systemWillSleep(_ notification: Notification) {
        pingManager.stop()
    }

    @objc private func systemDidWake(_ notification: Notification) {
        pingManager.start()
    }

    @MainActor
    @objc private func quit() {
        NSApplication.shared.terminate(self)
    }


    @MainActor
    @objc private func setDNS(_ sender: NSMenuItem) {
        guard let ip = sender.representedObject as? String? else { return }
        guard let iface = NetworkUtilities.defaultInterface(), let service = NetworkUtilities.networkServiceName(for: iface) else { return }
        let dnsArg = ip ?? "Empty"

        let requireAuth = UserDefaults.standard.bool(forKey: UserDefaultsKey.requireBiometricForDNS)

        if requireAuth {
            let dnsName = dnsArg == "Empty" ? "System Default" : DNSManager.displayName(for: dnsArg)
            BiometricAuthManager.authenticate(reason: "Authenticate to change DNS to \(dnsName)") { [weak self] result in
                switch result {
                case .success:
                    self?.performDNSChange(service: service, dnsArg: dnsArg)
                case .cancelled:
                    break
                case .failed(let message):
                    let alert = NSAlert()
                    alert.messageText = "Authentication Failed"
                    alert.informativeText = message
                    alert.runModal()
                case .unavailable:
                    self?.performDNSChange(service: service, dnsArg: dnsArg)
                }
            }
        } else {
            performDNSChange(service: service, dnsArg: dnsArg)
        }
    }

    @MainActor
    private func performDNSChange(service: String, dnsArg: String) {
        if dnsArg != "Empty" {
            UserDefaults.standard.set(dnsArg, forKey: UserDefaultsKey.lastCustomDNS)
        } else {
            UserDefaults.standard.removeObject(forKey: UserDefaultsKey.lastCustomDNS)
        }
        let status = DNSManager.setDNS(service: service, dnsArg: dnsArg)
        if !status.success {
            let alert = NSAlert()
            alert.messageText = "Failed to change DNS settings"
            alert.informativeText = status.message
            alert.runModal()
        }
    }

    // MARK: - UI Styling Methods

    private func setupStatusButton() {
        guard let button = statusItem?.button else { return }
        button.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        button.imagePosition = .imageOnly
    }

    private func renderIcon() {
        guard let button = statusItem?.button else { return }
        button.attributedTitle = NSAttributedString(string: "")
        button.image = StatusIconRenderer.render(
            latencyMs: latestLatencyMs,
            lossLevel: pingManager.lossTracker.level,
            pingStatus: latestPingStatus,
            hasEnoughLossSamples: pingManager.lossTracker.hasEnoughSamples
        )
        button.toolTip = tooltipText()
    }

    private func tooltipText() -> String {
        let pingText = latestLatencyMs.map { "\($0)ms" } ?? (latestPingStatus == .captivePortal ? "Captive Portal" : "Unavailable")
        let lossText: String
        if pingManager.lossTracker.hasEnoughSamples {
            lossText = String(format: "%.1f%%", pingManager.lossTracker.lossPercent)
        } else {
            lossText = "Collecting"
        }
        return "Ping: \(pingText) | Loss: \(lossText)"
    }

    private func refreshPacketLossMenuItem() {
        guard let item = packetLossMenuItem else { return }
        let sampleCount = pingManager.lossTracker.sampleCount
        let windowSize = pingManager.packetLossWindowSize
        let mode = pingManager.packetLossMode.displayName.lowercased()
        if pingManager.lossTracker.hasEnoughSamples {
            let lossText = String(format: "%.1f", pingManager.lossTracker.lossPercent)
            item.title = "📉 Loss: \(lossText)% (\(mode), \(sampleCount)/\(windowSize))"
            item.isHidden = false
        } else if sampleCount > 0 {
            item.title = "📉 Loss: collecting (\(mode), \(sampleCount)/\(windowSize))"
            item.isHidden = false
        } else {
            item.title = ""
            item.isHidden = true
        }
        styleGraphMenuItem(item)
    }

    private func stylePingMenuItem(_ item: NSMenuItem) {
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let attributedTitle = NSAttributedString(string: item.title, attributes: attributes)
        item.attributedTitle = attributedTitle
    }

    private func styleGraphMenuItem(_ item: NSMenuItem) {
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let attributedTitle = NSAttributedString(string: item.title, attributes: attributes)
        item.attributedTitle = attributedTitle
    }

    private func styleInfoMenuItem(_ item: NSMenuItem) {
        let font = NSFont.systemFont(ofSize: 12, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let attributedTitle = NSAttributedString(string: item.title, attributes: attributes)
        item.attributedTitle = attributedTitle
    }

    private func styleSystemMenuItem(_ item: NSMenuItem) {
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let attributedTitle = NSAttributedString(string: item.title, attributes: attributes)
        item.attributedTitle = attributedTitle
    }

    private func styleDNSMenuItem(_ item: NSMenuItem) {
        let font = NSFont.systemFont(ofSize: 12, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let attributedTitle = NSAttributedString(string: item.title, attributes: attributes)
        item.attributedTitle = attributedTitle
    }

}
