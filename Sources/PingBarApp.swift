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
        statusItem?.button?.title = "🔴"

        let menu = NSMenu()
        menu.delegate = self
        let pingItem = NSMenuItem(title: "Checking...", action: nil, keyEquivalent: "")
        menu.addItem(pingItem)
        let graphItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(graphItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
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
                self.graphMenuItem?.title = "\(spark)  avg: \(avg)ms  min: \(minPing)  max: \(maxPing)"
                self.graphMenuItem?.isHidden = false
            } else {
                self.graphMenuItem?.title = ""
                self.graphMenuItem?.isHidden = true
            }
            switch status {
            case .good, .warning:
                self.statusItem?.button?.title = (status == .good) ? "🟢" : "🟡"
                if self.dnsRevertedForOutage, restoreDNS, let custom = self.customDNSBeforeCaptive, custom != "Empty" {
                    if let iface = NetworkUtilities.defaultInterface, let service = NetworkUtilities.networkServiceName(for: iface) {
                        _ = DNSManager.setDNSWithOsascript(service: service, dnsArg: custom)
                        self.dnsRevertedForOutage = false
                        self.customDNSBeforeCaptive = nil
                    }
                } else {
                    self.dnsRevertedForOutage = false
                }
            case .bad:
                self.statusItem?.button?.title = "🔴"
                if revertDNS, !self.dnsRevertedForOutage {
                    if let iface = NetworkUtilities.defaultInterface, let service = NetworkUtilities.networkServiceName(for: iface) {
                        let lastCustom = UserDefaults.standard.string(forKey: "LastCustomDNS")
                        self.customDNSBeforeCaptive = (lastCustom != "Empty") ? lastCustom : nil
                        _ = DNSManager.setDNSWithOsascript(service: service, dnsArg: "Empty")
                        self.dnsRevertedForOutage = true
                    }
                }
            case .captivePortal:
                self.statusItem?.button?.title = "🟠"
            }
            self.pingMenuItem?.title = result
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
            insertIndex += 1
        }
        let ifaces = NetworkUtilities.localInterfaceAddresses()
        if !ifaces.isEmpty {
            for (idx, (iface, ip)) in ifaces.enumerated() {
                let ipItem = NSMenuItem(title: "\(iface): \(ip)", action: nil, keyEquivalent: "")
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
                let display = DNSManager.dnsNameMap[dns] ?? dns
                let dnsItem = NSMenuItem(title: "DNS: \(display)", action: nil, keyEquivalent: "")
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
            ("System Default", nil),
            ("dnscrypt-proxy (127.0.0.1)", "127.0.0.1"),
            ("Cloudflare (1.1.1.1)", "1.1.1.1"),
            ("Google (8.8.8.8)", "8.8.8.8"),
            ("Quad9 (9.9.9.9)", "9.9.9.9"),
            ("114DNS (114.114.114.114)", "114.114.114.114")
        ]
        let systemDefault = dnsOptions.removeFirst()
        let dnscryptProxy = dnsOptions.removeFirst()
        dnsOptions.sort { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
        dnsOptions.insert(dnscryptProxy, at: 0)
        dnsOptions.insert(systemDefault, at: 0)
        for (label, ip) in dnsOptions {
            let item = NSMenuItem(title: label, action: #selector(setDNS(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ip as AnyObject?
            dnsMenu.addItem(item)
        }
        let dnsMenuItem = NSMenuItem(title: "Set DNS for Default Interface", action: nil, keyEquivalent: "")
        dnsMenuItem.submenu = dnsMenu
        menu.insertItem(dnsMenuItem, at: insertIndex)
        self.dnsMenuItem = dnsMenuItem
    }


    @MainActor
    @objc private func showPreferences(_ sender: Any?) {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController { [weak self] host, interval, highPing, revertDNS, restoreDNS, launchAtLogin in
                UserDefaults.standard.set(interval, forKey: "PingInterval")
                UserDefaults.standard.set(host, forKey: "PingHost")
                UserDefaults.standard.set(highPing, forKey: "HighPingThreshold")
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
        guard let iface = NetworkUtilities.defaultInterface, let service = NetworkUtilities.networkServiceName(for: iface) else { return }
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

} 