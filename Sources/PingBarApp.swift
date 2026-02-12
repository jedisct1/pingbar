import Cocoa
import Foundation
import Security

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var pingManager: PingManager!
    private var pingMenuItem: NSMenuItem?
    private var preferencesWindow: PreferencesWindowController?
    private var ipMenuItems: [NSMenuItem] = []
    private var dnsMenuItem: NSMenuItem?
    private var dnsRevertedForOutage = false
    private var customDNSBeforeCaptive: String?
    private var graphMenuItem: NSMenuItem?

    nonisolated public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        pingManager = PingManager()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupStatusButton()
        updateStatusIndicator(.bad)

        let menu = NSMenu()
        menu.delegate = self

        let pingItem = NSMenuItem(title: "Checking...", action: nil, keyEquivalent: "")
        self.stylePingMenuItem(pingItem)
        menu.addItem(pingItem)

        let graphItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        self.styleGraphMenuItem(graphItem)
        menu.addItem(graphItem)

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

        pingManager.onPingResult = { [weak self] status, result in
            guard let self else { return }
            let revertDNS = UserDefaults.standard.bool(forKey: "RevertDNSOnCaptivePortal")
            let restoreDNS = UserDefaults.standard.bool(forKey: "RestoreCustomDNSAfterCaptive")
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
            switch status {
            case .good, .warning:
                self.updateStatusIndicator(status)
                if self.dnsRevertedForOutage, restoreDNS, let custom = self.customDNSBeforeCaptive, custom != "Empty" {
                    if let iface = NetworkUtilities.defaultInterface(), let service = NetworkUtilities.networkServiceName(for: iface) {
                        _ = DNSManager.setDNSWithOsascript(service: service, dnsArg: custom)
                        self.dnsRevertedForOutage = false
                        self.customDNSBeforeCaptive = nil
                    }
                } else {
                    self.dnsRevertedForOutage = false
                }
            case .bad:
                self.updateStatusIndicator(.bad)
                if revertDNS, !self.dnsRevertedForOutage {
                    if let iface = NetworkUtilities.defaultInterface(), let service = NetworkUtilities.networkServiceName(for: iface) {
                        let lastCustom = UserDefaults.standard.string(forKey: "LastCustomDNS")
                        self.customDNSBeforeCaptive = (lastCustom != "Empty") ? lastCustom : nil
                        _ = DNSManager.setDNSWithOsascript(service: service, dnsArg: "Empty")
                        self.dnsRevertedForOutage = true
                    }
                }
            case .captivePortal:
                self.updateStatusIndicator(.captivePortal)
            }
            self.pingMenuItem?.title = result
            if let pingItem = self.pingMenuItem {
                self.stylePingMenuItem(pingItem)
            }
        }
        pingManager.start()

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    public func menuWillOpen(_ menu: NSMenu) {
        ipMenuItems.forEach(menu.removeItem)
        ipMenuItems.removeAll()
        if let dnsMenu = dnsMenuItem { menu.removeItem(dnsMenu) }
        if let graphItem = graphMenuItem, menu.items.contains(graphItem) { menu.removeItem(graphItem) }
        var insertIndex = 0
        if let pingItem = pingMenuItem, let pingIdx = menu.items.firstIndex(of: pingItem) {
            insertIndex = pingIdx + 1
        }
        if let graphItem = graphMenuItem {
            menu.insertItem(graphItem, at: insertIndex)
            insertIndex += 1
            let sep = NSMenuItem.separator()
            menu.insertItem(sep, at: insertIndex)
            ipMenuItems.append(sep)
            insertIndex += 1
        }
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
            preferencesWindow = PreferencesWindowController { [weak self] host, interval, highPing, customDNS, revertDNS, restoreDNS, launchAtLogin in
                UserDefaults.standard.set(interval, forKey: "PingInterval")
                UserDefaults.standard.set(host, forKey: "PingHost")
                UserDefaults.standard.set(highPing, forKey: "HighPingThreshold")
                UserDefaults.standard.set(customDNS, forKey: "CustomDNSServer")
                UserDefaults.standard.set(revertDNS, forKey: "RevertDNSOnCaptivePortal")
                UserDefaults.standard.set(restoreDNS, forKey: "RestoreCustomDNSAfterCaptive")
                UserDefaults.standard.set(launchAtLogin, forKey: "LaunchAtLogin")
                self?.pingManager.updateSettings(host: host, interval: interval)
                self?.pingManager.highPingThreshold = highPing
                self?.preferencesWindow = nil
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
        if dnsArg != "Empty" {
            UserDefaults.standard.set(dnsArg, forKey: "LastCustomDNS")
        } else {
            UserDefaults.standard.removeObject(forKey: "LastCustomDNS")
        }
        let status = DNSManager.setDNSWithOsascript(service: service, dnsArg: dnsArg)
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
        button.imagePosition = .noImage
    }

    private func updateStatusIndicator(_ status: PingManager.PingStatus) {
        guard let button = statusItem?.button else { return }

        let attributes: [NSAttributedString.Key: Any]

        switch status {
        case .good:
            attributes = [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.systemGreen
            ]
            let attributedTitle = NSAttributedString(string: "●", attributes: attributes)
            button.attributedTitle = attributedTitle
        case .warning:
            attributes = [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.systemYellow
            ]
            let attributedTitle = NSAttributedString(string: "●", attributes: attributes)
            button.attributedTitle = attributedTitle
        case .bad:
            attributes = [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.systemRed
            ]
            let attributedTitle = NSAttributedString(string: "●", attributes: attributes)
            button.attributedTitle = attributedTitle
        case .captivePortal:
            attributes = [
                .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.systemOrange
            ]
            let attributedTitle = NSAttributedString(string: "●", attributes: attributes)
            button.attributedTitle = attributedTitle
        }
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
