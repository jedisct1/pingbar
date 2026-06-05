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
    private var statsMenuItem: NSMenuItem?
    private var latestLatencyMs: Int?
    private var latestPingStatus: PingManager.PingStatus = .bad

    nonisolated public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        pingManager = PingManager()
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        setupStatusButton()
        renderIcon()
        buildMenu()
        configurePingCallbacks()
        pingManager.start()
        registerSleepWakeObservers()
    }

    public func menuWillOpen(_ menu: NSMenu) {
        ipMenuItems.forEach(menu.removeItem)
        ipMenuItems.removeAll()
        if let dnsMenu = dnsMenuItem { menu.removeItem(dnsMenu) }
        guard let preferencesMenuItem,
              let baseInsertIndex = menu.items.firstIndex(of: preferencesMenuItem)
        else { return }
        var insertIndex = baseInsertIndex
        insertIndex = insertInterfaceItems(into: menu, at: insertIndex)
        insertDNSSubmenu(into: menu, at: insertIndex)
    }

    @MainActor
    @objc private func showPreferences(_ sender: Any?) {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController { [weak self] in
                self?.pingManager.reloadSettingsFromDefaults()
                self?.refreshPacketLossMenuItem()
                self?.renderIcon()
                self?.preferencesWindow = nil
                let launchAtLogin = UserDefaults.standard.bool(
                    forKey: UserDefaultsKey.launchAtLogin
                )
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
        guard let addr = sender.representedObject as? String? else { return }
        guard let iface = NetworkUtilities.defaultInterface(),
              let service = NetworkUtilities.networkServiceName(for: iface)
        else { return }
        let dnsArg = addr ?? "Empty"
        if dnsArg != "Empty" {
            UserDefaults.standard.set(
                dnsArg,
                forKey: UserDefaultsKey.lastCustomDNS
            )
        } else {
            UserDefaults.standard.removeObject(
                forKey: UserDefaultsKey.lastCustomDNS
            )
        }
        let status = DNSManager.setDNS(service: service, dnsArg: dnsArg)
        if !status.success {
            let alert = NSAlert()
            alert.messageText = "Failed to change DNS settings"
            alert.informativeText = status.message
            alert.runModal()
        }
    }

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
        let pingText: String
        if let ms = latestLatencyMs {
            pingText = "\(ms)ms"
        } else if latestPingStatus == .captivePortal {
            pingText = "Captive Portal"
        } else {
            pingText = "Unavailable"
        }
        let lossText: String
        if pingManager.lossTracker.hasEnoughSamples {
            lossText = String(
                format: "%.1f%%",
                pingManager.lossTracker.lossPercent
            )
        } else {
            lossText = "Collecting"
        }
        return "Ping: \(pingText) | Loss: \(lossText)"
    }

    private func refreshPacketLossMenuItem() {
        guard let item = packetLossMenuItem else { return }
        item.title = packetLossTitle(
            lossPercent: pingManager.lossTracker.lossPercent,
            mode: pingManager.packetLossMode.displayName,
            sampleCount: pingManager.lossTracker.sampleCount,
            windowSize: pingManager.packetLossWindowSize,
            hasEnoughSamples: pingManager.lossTracker.hasEnoughSamples
        )
        item.isHidden = item.title.isEmpty
        styleLossMenuItem(item)
    }

    func shouldShowNetworkInterfaces() -> Bool {
        return UserDefaults.standard.showNetworkInterfaces
    }

    func currentDNSSummary(from resolvers: [String]) -> String {
        guard !resolvers.isEmpty else {
            return "Current: Unavailable"
        }

        let names = resolvers.map(DNSManager.displayName(for:))
        let maxShown = 2
        if names.count > maxShown {
            let shown = names.prefix(maxShown).joined(separator: ", ")
            return "Current: \(shown) +\(names.count - maxShown) more"
        }
        return "Current: \(names.joined(separator: ", "))"
    }

    func graphTitle(for pings: [Int]) -> String {
        guard !pings.isEmpty else {
            return ""
        }

        let spark = SparklineRenderer.renderSparkline(pings: pings)
        return "Trend  \(spark)"
    }

    func statsTitle(for pings: [Int]) -> String {
        guard !pings.isEmpty else {
            return ""
        }

        let avg = pings.reduce(0, +) / pings.count
        let sorted = pings.sorted()
        let minPing = sorted.first ?? 0
        let maxPing = sorted.last ?? 0
        let median: Int

        if sorted.count.isMultiple(of: 2) {
            let upperMiddle = sorted.count / 2
            let lowerMiddle = upperMiddle - 1
            median = (sorted[lowerMiddle] + sorted[upperMiddle]) / 2
        } else {
            median = sorted[sorted.count / 2]
        }

        return "avg \(avg)ms | med \(median)ms | min \(minPing)ms | max \(maxPing)ms"
    }

    func packetLossTitle(
        lossPercent: Double,
        mode: String,
        sampleCount: Int,
        windowSize: Int,
        hasEnoughSamples: Bool
    ) -> String {
        guard hasEnoughSamples || sampleCount > 0 else {
            return ""
        }

        let modeLabel = mode.lowercased()
        if hasEnoughSamples {
            return String(format: "Loss  %.1f%% | %@ | %d/%d", lossPercent, modeLabel, sampleCount, windowSize)
        }

        return "Loss  collecting | \(modeLabel) | \(sampleCount)/\(windowSize)"
    }
}

extension AppDelegate {
    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let pingItem = NSMenuItem(
            title: "Checking...", action: nil, keyEquivalent: ""
        )
        self.stylePingMenuItem(pingItem)
        menu.addItem(pingItem)

        let graphItem = NSMenuItem(
            title: "", action: nil, keyEquivalent: ""
        )
        self.styleGraphMenuItem(graphItem)
        menu.addItem(graphItem)

        let statsItem = NSMenuItem(
            title: "", action: nil, keyEquivalent: ""
        )
        self.styleStatsMenuItem(statsItem)
        menu.addItem(statsItem)

        let lossItem = NSMenuItem(
            title: "", action: nil, keyEquivalent: ""
        )
        self.styleLossMenuItem(lossItem)
        menu.addItem(lossItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        self.styleSystemMenuItem(prefsItem)
        menu.addItem(prefsItem)

        let quitItem = NSMenuItem(
            title: "Quit PingBar",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        self.styleQuitMenuItem(quitItem)
        menu.addItem(quitItem)

        statusItem?.menu = menu
        self.pingMenuItem = pingItem
        self.graphMenuItem = graphItem
        self.statsMenuItem = statsItem
        self.packetLossMenuItem = lossItem
        self.preferencesMenuItem = prefsItem
        self.graphMenuItem?.isHidden = true
        self.statsMenuItem?.isHidden = true
        self.packetLossMenuItem?.isHidden = true
    }

    private func configurePingCallbacks() {
        pingManager.onPingResult = { [weak self] result in
            guard let self else { return }
            self.latestPingStatus = result.status
            self.latestLatencyMs = result.latencyMs
            self.updateGraphAndStats()
            self.handleDNSRevert(for: result.status)
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
    }

    private func updateGraphAndStats() {
        let pings = pingManager.recentPings
        guard !pings.isEmpty else {
            graphMenuItem?.title = ""
            graphMenuItem?.isHidden = true
            statsMenuItem?.title = ""
            statsMenuItem?.isHidden = true
            return
        }
        graphMenuItem?.title = graphTitle(for: pings)
        if let graphItem = graphMenuItem {
            styleGraphMenuItem(graphItem)
        }
        graphMenuItem?.isHidden = false

        statsMenuItem?.title = statsTitle(for: pings)
        if let statsItem = statsMenuItem {
            styleStatsMenuItem(statsItem)
        }
        statsMenuItem?.isHidden = false
    }

    private func handleDNSRevert(for status: PingManager.PingStatus) {
        let revertDNS = UserDefaults.standard.bool(
            forKey: UserDefaultsKey.revertDNSOnCaptivePortal
        )
        let restoreDNS = UserDefaults.standard.bool(
            forKey: UserDefaultsKey.restoreCustomDNSAfterCaptive
        )
        switch status {
        case .good, .warning:
            guard dnsRevertedForOutage,
                  restoreDNS,
                  let custom = customDNSBeforeCaptive,
                  custom != "Empty"
            else {
                dnsRevertedForOutage = false
                return
            }
            guard let iface = NetworkUtilities.defaultInterface(),
                  let service = NetworkUtilities.networkServiceName(
                      for: iface
                  )
            else { return }
            _ = DNSManager.setDNS(service: service, dnsArg: custom)
            dnsRevertedForOutage = false
            customDNSBeforeCaptive = nil
        case .bad:
            guard revertDNS, !dnsRevertedForOutage else { return }
            guard let iface = NetworkUtilities.defaultInterface(),
                  let service = NetworkUtilities.networkServiceName(
                      for: iface
                  )
            else { return }
            let lastCustom = UserDefaults.standard.string(
                forKey: UserDefaultsKey.lastCustomDNS
            )
            customDNSBeforeCaptive = (lastCustom != "Empty")
                ? lastCustom : nil
            _ = DNSManager.setDNS(service: service, dnsArg: "Empty")
            dnsRevertedForOutage = true
        case .captivePortal:
            break
        }
    }

    private func registerSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    private func insertInterfaceItems(
        into menu: NSMenu,
        at startIndex: Int
    ) -> Int {
        guard shouldShowNetworkInterfaces() else { return startIndex }
        let ifaces = NetworkUtilities.localInterfaceAddresses()
        guard !ifaces.isEmpty else { return startIndex }
        for (idx, (iface, addr)) in ifaces.enumerated() {
            let ipItem = NSMenuItem(
                title: "🌐 \(iface): \(addr)",
                action: nil,
                keyEquivalent: ""
            )
            self.styleNetworkInterfaceMenuItem(ipItem)
            menu.insertItem(ipItem, at: startIndex + idx)
            ipMenuItems.append(ipItem)
        }
        let sep = NSMenuItem.separator()
        menu.insertItem(sep, at: startIndex + ifaces.count)
        ipMenuItems.append(sep)
        return startIndex + ifaces.count + 1
    }

    private func insertDNSSubmenu(into menu: NSMenu, at insertIndex: Int) {
        let dnsResolvers = NetworkUtilities.currentDNSResolvers()
        let dnsMenu = NSMenu(title: "DNS")
        let currentDNSItem = NSMenuItem(
            title: currentDNSSummary(from: dnsResolvers),
            action: nil,
            keyEquivalent: ""
        )
        self.styleInfoMenuItem(currentDNSItem)
        dnsMenu.addItem(currentDNSItem)
        dnsMenu.addItem(.separator())

        var dnsOptions: [(String, String?)] = [
            ("🏠 System Default", nil),
            ("🔒 dnscrypt-proxy (127.0.0.1)", "127.0.0.1"),
            ("☁️ Cloudflare (1.1.1.1)", "1.1.1.1"),
            ("🔍 Google (8.8.8.8)", "8.8.8.8"),
            ("🛡 Quad9 (9.9.9.9)", "9.9.9.9"),
            ("🌏 114DNS (114.114.114.114)", "114.114.114.114")
        ]
        if let customDNSIP = DNSManager.getCustomDNSIP() {
            let displayName = DNSManager.displayName(for: customDNSIP)
            let menuTitle = "⚙️ \(displayName) (\(customDNSIP))"
            dnsOptions.append((menuTitle, customDNSIP))
        }
        let systemDefault = dnsOptions.removeFirst()
        let dnscryptProxy = dnsOptions.removeFirst()
        dnsOptions.sort {
            $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending
        }
        dnsOptions.insert(dnscryptProxy, at: 0)
        dnsOptions.insert(systemDefault, at: 0)
        for (label, addr) in dnsOptions {
            let item = NSMenuItem(
                title: label,
                action: #selector(setDNS(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = addr as AnyObject?
            self.styleDNSMenuItem(item)
            dnsMenu.addItem(item)
        }
        let dnsMenuItem = NSMenuItem(
            title: "DNS",
            action: nil,
            keyEquivalent: ""
        )
        dnsMenuItem.submenu = dnsMenu
        self.styleDNSRootMenuItem(dnsMenuItem)
        menu.insertItem(dnsMenuItem, at: insertIndex)
        self.dnsMenuItem = dnsMenuItem
    }
}

extension AppDelegate {
    private func stylePingMenuItem(_ item: NSMenuItem) {
        let font = NSFont.monospacedSystemFont(ofSize: 17, weight: .semibold)
        styleStaticMenuItem(
            item,
            font: font,
            color: pingHeadlineColor(for: item.title),
            minimumWidth: 350,
            verticalPadding: 5
        )
    }

    private func styleGraphMenuItem(_ item: NSMenuItem) {
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        styleStaticMenuItem(item, font: font, color: .labelColor, minimumWidth: 350, verticalPadding: 3)
    }

    private func styleStatsMenuItem(_ item: NSMenuItem) {
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        styleStaticMenuItem(item, font: font, color: .secondaryLabelColor, minimumWidth: 350, verticalPadding: 2)
    }

    private func styleLossMenuItem(_ item: NSMenuItem) {
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        styleStaticMenuItem(
            item,
            font: font,
            color: packetLossRowColor(),
            minimumWidth: 350,
            verticalPadding: 3
        )
    }

    private func styleInfoMenuItem(_ item: NSMenuItem) {
        let font = NSFont.systemFont(ofSize: 12, weight: .regular)
        styleStaticMenuItem(item, font: font, color: .labelColor)
    }

    private func styleNetworkInterfaceMenuItem(_ item: NSMenuItem) {
        let font = NSFont.systemFont(ofSize: 12, weight: .regular)
        styleStaticMenuItem(
            item,
            font: font,
            color: .secondaryLabelColor,
            verticalPadding: 5
        )
    }

    private func styleSystemMenuItem(_ item: NSMenuItem) {
        item.isEnabled = true
        item.view = nil
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        item.attributedTitle = NSAttributedString(
            string: item.title,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func styleDNSMenuItem(_ item: NSMenuItem) {
        item.isEnabled = true
        item.view = nil
        let font = NSFont.systemFont(ofSize: 12, weight: .regular)
        item.attributedTitle = NSAttributedString(
            string: item.title,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func styleDNSRootMenuItem(_ item: NSMenuItem) {
        styleSystemMenuItem(item)
        if let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "DNS") {
            image.isTemplate = true
            item.image = image
        }
    }

    private func styleQuitMenuItem(_ item: NSMenuItem) {
        styleSystemMenuItem(item)
        if let image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit PingBar") {
            image.isTemplate = true
            item.image = image
        }
    }

    private func pingHeadlineColor(for title: String) -> NSColor {
        if title == "Checking..." {
            return .labelColor
        }

        switch latestPingStatus {
        case .good:
            return .labelColor
        case .warning:
            return .systemOrange
        case .bad:
            return .systemRed
        case .captivePortal:
            return .systemYellow
        }
    }

    private func packetLossRowColor() -> NSColor {
        if !pingManager.lossTracker.hasEnoughSamples {
            return .secondaryLabelColor
        }

        switch pingManager.lossTracker.level {
        case .good:
            return .labelColor
        case .warning:
            return .systemOrange
        case .bad:
            return .systemRed
        }
    }

    private func styleStaticMenuItem(
        _ item: NSMenuItem,
        font: NSFont,
        color: NSColor,
        minimumWidth: CGFloat = 220,
        verticalPadding: CGFloat = 2
    ) {
        item.isEnabled = false
        item.attributedTitle = nil
        if let existing = item.view as? MenuLabelView {
            existing.update(text: item.title, font: font, color: color, minimumWidth: minimumWidth)
        } else {
            item.view = MenuLabelView(
                text: item.title,
                font: font,
                color: color,
                minimumWidth: minimumWidth,
                verticalPadding: verticalPadding
            )
        }
    }
}

final class MenuLabelView: NSView {
    private let label = NSTextField(labelWithString: "")
    private var widthConstraint: NSLayoutConstraint!

    init(text: String, font: NSFont, color: NSColor, minimumWidth: CGFloat, verticalPadding: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        setAccessibilityRole(.staticText)

        widthConstraint = widthAnchor.constraint(equalToConstant: minimumWidth)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: topAnchor, constant: verticalPadding),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -verticalPadding),
            widthConstraint
        ])

        update(text: text, font: font, color: color, minimumWidth: minimumWidth)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(text: String, font: NSFont, color: NSColor, minimumWidth: CGFloat) {
        label.stringValue = text
        label.font = font
        label.textColor = color
        setAccessibilityLabel(text)
        widthConstraint.constant = max(label.intrinsicContentSize.width + 24, minimumWidth)
    }
}
