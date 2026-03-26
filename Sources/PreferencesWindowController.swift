import Cocoa

class PreferencesViewController: NSViewController {
    let intervalField = NSTextField()
    let hostField = NSTextField()
    let highPingField = NSTextField()
    let customDNSField = NSTextField()
    let packetLossModePopup = NSPopUpButton()
    let packetLossProbeIntervalField = NSTextField()
    let packetLossBurstSizeField = NSTextField()
    let packetLossWindowSizeField = NSTextField()
    let packetLossWarningThresholdField = NSTextField()
    let packetLossBadThresholdField = NSTextField()
    let revertDNSCheckbox = NSButton(checkboxWithTitle: "Revert DNS to System Default when network is unreachable", target: nil, action: nil)
    let restoreDNSCheckbox = NSButton(checkboxWithTitle: "Restore my custom DNS after passing captive portal", target: nil, action: nil)
    let biometricAuthCheckbox = NSButton(checkboxWithTitle: "Require Touch ID / password to change DNS", target: nil, action: nil)
    let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch PingBar at login", target: nil, action: nil)
    var onSave: (() -> Void)?

    override func loadView() {
        let view = NSView()
        self.view = view
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setFrameSize(NSSize(width: 520, height: 520))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let headerLabel = NSTextField(labelWithString: "⚙️ PingBar Preferences")
        headerLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        headerLabel.alignment = .center
        headerLabel.textColor = NSColor.labelColor

        let networkSectionLabel = sectionLabel("🌐 Network Settings")
        let packetLossSectionLabel = sectionLabel("📉 Packet Loss")
        let dnsSectionLabel = sectionLabel("🔧 DNS Management")
        let systemSectionLabel = sectionLabel("💻 System Integration")

        let intervalLabel = fieldLabel("⏱ Ping interval (seconds):")
        let hostLabel = fieldLabel("🎯 Target host (URL):")
        let highPingLabel = fieldLabel("⚠️ High ping threshold (ms):")
        let customDNSLabel = fieldLabel("🔧 Custom DNS (optional):")
        let packetLossModeLabel = fieldLabel("📊 Loss measurement mode:")
        let packetLossProbeIntervalLabel = fieldLabel("⏱ Active probe interval (s):")
        let packetLossBurstSizeLabel = fieldLabel("📦 Active burst size:")
        let packetLossWindowSizeLabel = fieldLabel("🪟 Loss window size:")
        let packetLossWarningThresholdLabel = fieldLabel("🟡 Warning threshold (%):")
        let packetLossBadThresholdLabel = fieldLabel("🔴 Bad threshold (%):")

        styleTextField(intervalField)
        intervalField.stringValue = String(defaultDouble(for: UserDefaultsKey.pingInterval, fallback: 5.0))
        intervalField.placeholderString = "e.g. 5"

        styleTextField(hostField)
        hostField.stringValue = UserDefaults.standard.string(forKey: UserDefaultsKey.pingHost) ?? "https://www.google.com"
        hostField.placeholderString = "e.g. https://www.google.com"

        styleTextField(highPingField)
        highPingField.stringValue = String(defaultInt(for: UserDefaultsKey.highPingThreshold, fallback: 200))
        highPingField.placeholderString = "e.g. 200"

        styleTextField(customDNSField)
        customDNSField.stringValue = UserDefaults.standard.string(forKey: UserDefaultsKey.customDNSServer) ?? ""
        customDNSField.placeholderString = "e.g. 1.1.1.1 or My Server"

        stylePopup(packetLossModePopup)
        packetLossModePopup.addItems(withTitles: ["Passive", "Active"])
        let savedMode = PingManager.PacketLossMode(rawValue: UserDefaults.standard.string(forKey: UserDefaultsKey.packetLossMode) ?? "") ?? .passive
        packetLossModePopup.selectItem(withTitle: savedMode.displayName)
        packetLossModePopup.target = self
        packetLossModePopup.action = #selector(packetLossModeChanged)

        styleTextField(packetLossProbeIntervalField)
        packetLossProbeIntervalField.stringValue = String(defaultDouble(for: UserDefaultsKey.packetLossProbeInterval, fallback: 30.0))
        packetLossProbeIntervalField.placeholderString = "e.g. 30"

        styleTextField(packetLossBurstSizeField)
        packetLossBurstSizeField.stringValue = String(defaultInt(for: UserDefaultsKey.packetLossBurstSize, fallback: 5))
        packetLossBurstSizeField.placeholderString = "e.g. 5"

        styleTextField(packetLossWindowSizeField)
        packetLossWindowSizeField.stringValue = String(defaultInt(for: UserDefaultsKey.packetLossWindowSize, fallback: 50))
        packetLossWindowSizeField.placeholderString = "e.g. 50"

        styleTextField(packetLossWarningThresholdField)
        packetLossWarningThresholdField.stringValue = String(defaultDouble(for: UserDefaultsKey.packetLossWarningThreshold, fallback: 3.0))
        packetLossWarningThresholdField.placeholderString = "e.g. 3"

        styleTextField(packetLossBadThresholdField)
        packetLossBadThresholdField.stringValue = String(defaultDouble(for: UserDefaultsKey.packetLossBadThreshold, fallback: 10.0))
        packetLossBadThresholdField.placeholderString = "e.g. 10"

        styleCheckbox(revertDNSCheckbox)
        styleCheckbox(restoreDNSCheckbox)
        styleCheckbox(launchAtLoginCheckbox)

        let saveButton = NSButton(title: "💾 Save Settings", target: self, action: #selector(saveClicked))
        let cancelButton = NSButton(title: "❌ Cancel", target: self, action: #selector(cancelClicked))
        styleButton(saveButton, isPrimary: true)
        styleButton(cancelButton, isPrimary: false)
        saveButton.setContentHuggingPriority(.required, for: .horizontal)
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let networkStack = verticalStack(spacing: 12)
        networkStack.addArrangedSubview(networkSectionLabel)
        networkStack.addArrangedSubview(makeRow(label: intervalLabel, control: intervalField))
        networkStack.addArrangedSubview(makeRow(label: hostLabel, control: hostField))
        networkStack.addArrangedSubview(makeRow(label: highPingLabel, control: highPingField))
        networkStack.addArrangedSubview(makeRow(label: customDNSLabel, control: customDNSField))

        let packetLossStack = verticalStack(spacing: 12)
        packetLossStack.addArrangedSubview(packetLossSectionLabel)
        packetLossStack.addArrangedSubview(makeRow(label: packetLossModeLabel, control: packetLossModePopup))
        packetLossStack.addArrangedSubview(makeRow(label: packetLossProbeIntervalLabel, control: packetLossProbeIntervalField))
        packetLossStack.addArrangedSubview(makeRow(label: packetLossBurstSizeLabel, control: packetLossBurstSizeField))
        packetLossStack.addArrangedSubview(makeRow(label: packetLossWindowSizeLabel, control: packetLossWindowSizeField))
        packetLossStack.addArrangedSubview(makeRow(label: packetLossWarningThresholdLabel, control: packetLossWarningThresholdField))
        packetLossStack.addArrangedSubview(makeRow(label: packetLossBadThresholdLabel, control: packetLossBadThresholdField))

        let dnsStack = verticalStack(spacing: 8)
        dnsStack.addArrangedSubview(dnsSectionLabel)
        dnsStack.addArrangedSubview(revertDNSCheckbox)
        dnsStack.addArrangedSubview(restoreDNSCheckbox)
        biometricAuthCheckbox.isHidden = !BiometricAuthManager.isBiometricAvailable
        dnsStack.addArrangedSubview(biometricAuthCheckbox)

        let systemStack = verticalStack(spacing: 8)
        systemStack.addArrangedSubview(systemSectionLabel)
        systemStack.addArrangedSubview(launchAtLoginCheckbox)

        let formStack = verticalStack(spacing: 20)
        formStack.addArrangedSubview(networkStack)
        formStack.addArrangedSubview(createSeparator())
        formStack.addArrangedSubview(packetLossStack)
        formStack.addArrangedSubview(createSeparator())
        formStack.addArrangedSubview(dnsStack)
        formStack.addArrangedSubview(createSeparator())
        formStack.addArrangedSubview(systemStack)

        let buttonStack = NSStackView(views: [saveButton, cancelButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.alignment = .centerY
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = NSStackView(views: [headerLabel, formStack, buttonStack])
        mainStack.orientation = .vertical
        mainStack.spacing = 24
        mainStack.edgeInsets = NSEdgeInsets(top: 30, left: 30, bottom: 30, right: 30)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: view.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            intervalField.widthAnchor.constraint(equalToConstant: 220),
            hostField.widthAnchor.constraint(equalToConstant: 220),
            highPingField.widthAnchor.constraint(equalToConstant: 220),
            customDNSField.widthAnchor.constraint(equalToConstant: 220),
            packetLossProbeIntervalField.widthAnchor.constraint(equalToConstant: 220),
            packetLossBurstSizeField.widthAnchor.constraint(equalToConstant: 220),
            packetLossWindowSizeField.widthAnchor.constraint(equalToConstant: 220),
            packetLossWarningThresholdField.widthAnchor.constraint(equalToConstant: 220),
            packetLossBadThresholdField.widthAnchor.constraint(equalToConstant: 220),
            packetLossModePopup.widthAnchor.constraint(equalToConstant: 220)
        ])

        revertDNSCheckbox.state = UserDefaults.standard.bool(forKey: UserDefaultsKey.revertDNSOnCaptivePortal) ? .on : .off
        restoreDNSCheckbox.state = UserDefaults.standard.bool(forKey: UserDefaultsKey.restoreCustomDNSAfterCaptive) ? .on : .off
        launchAtLoginCheckbox.state = UserDefaults.standard.bool(forKey: UserDefaultsKey.launchAtLogin) ? .on : .off
        biometricAuthCheckbox.state = UserDefaults.standard.bool(forKey: UserDefaultsKey.requireBiometricForDNS) ? .on : .off
        refreshPacketLossFieldState()
    }

    @objc func saveClicked() {
        let interval = max(1.0, Double(intervalField.stringValue) ?? 5.0)
        let host = hostField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let highPing = max(1, Int(highPingField.stringValue) ?? 200)
        let customDNS = customDNSField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let mode = packetLossModePopup.titleOfSelectedItem == "Active" ? PingManager.PacketLossMode.active : .passive
        let packetLossProbeInterval = max(1.0, Double(packetLossProbeIntervalField.stringValue) ?? 30.0)
        let packetLossBurstSize = max(1, min(Int(packetLossBurstSizeField.stringValue) ?? 5, 100))
        let packetLossWindowSize = max(10, min(Int(packetLossWindowSizeField.stringValue) ?? 50, 500))
        let packetLossWarningThreshold = max(0.1, Double(packetLossWarningThresholdField.stringValue) ?? 3.0)
        let packetLossBadThreshold = Double(packetLossBadThresholdField.stringValue) ?? 10.0

        guard !host.isEmpty, URL(string: host) != nil else {
            showAlert(title: "Invalid Target Host", message: "Please enter a valid URL such as https://www.google.com")
            return
        }

        if !customDNS.isEmpty {
            let components = customDNS.components(separatedBy: " ")
            let ipAddress = components[0]
            if !isValidIPAddress(ipAddress) {
                showAlert(title: "Invalid DNS Server", message: "Please enter a valid IP address for the custom DNS server. Examples:\n• 1.1.1.1\n• 8.8.8.8 Google\n• 192.168.1.1 Home Router")
                return
            }
        }

        guard packetLossBadThreshold > packetLossWarningThreshold else {
            showAlert(title: "Invalid Packet Loss Thresholds", message: "The bad packet loss threshold must be higher than the warning threshold.")
            return
        }

        let revertDNS = (revertDNSCheckbox.state == .on)
        let restoreDNS = (restoreDNSCheckbox.state == .on)
        let launchAtLogin = (launchAtLoginCheckbox.state == .on)

        UserDefaults.standard.set(interval, forKey: UserDefaultsKey.pingInterval)
        UserDefaults.standard.set(host, forKey: UserDefaultsKey.pingHost)
        UserDefaults.standard.set(highPing, forKey: UserDefaultsKey.highPingThreshold)
        UserDefaults.standard.set(customDNS, forKey: UserDefaultsKey.customDNSServer)
        UserDefaults.standard.set(mode.rawValue, forKey: UserDefaultsKey.packetLossMode)
        UserDefaults.standard.set(packetLossProbeInterval, forKey: UserDefaultsKey.packetLossProbeInterval)
        UserDefaults.standard.set(packetLossBurstSize, forKey: UserDefaultsKey.packetLossBurstSize)
        UserDefaults.standard.set(packetLossWindowSize, forKey: UserDefaultsKey.packetLossWindowSize)
        UserDefaults.standard.set(packetLossWarningThreshold, forKey: UserDefaultsKey.packetLossWarningThreshold)
        UserDefaults.standard.set(packetLossBadThreshold, forKey: UserDefaultsKey.packetLossBadThreshold)
        UserDefaults.standard.set(revertDNS, forKey: UserDefaultsKey.revertDNSOnCaptivePortal)
        UserDefaults.standard.set(restoreDNS, forKey: UserDefaultsKey.restoreCustomDNSAfterCaptive)
        UserDefaults.standard.set(launchAtLogin, forKey: UserDefaultsKey.launchAtLogin)
        UserDefaults.standard.set(biometricAuthCheckbox.state == .on, forKey: UserDefaultsKey.requireBiometricForDNS)

        onSave?()
        view.window?.close()
    }

    @objc func cancelClicked() {
        view.window?.close()
    }

    @objc private func packetLossModeChanged() {
        refreshPacketLossFieldState()
    }

    private func refreshPacketLossFieldState() {
        let isActive = packetLossModePopup.titleOfSelectedItem == "Active"
        packetLossProbeIntervalField.isEnabled = isActive
        packetLossBurstSizeField.isEnabled = isActive
        packetLossProbeIntervalField.alphaValue = isActive ? 1.0 : 0.55
        packetLossBurstSizeField.alphaValue = isActive ? 1.0 : 0.55
    }

    private func defaultInt(for key: String, fallback: Int) -> Int {
        let value = UserDefaults.standard.integer(forKey: key)
        return value > 0 ? value : fallback
    }

    private func defaultDouble(for key: String, fallback: Double) -> Double {
        let value = UserDefaults.standard.double(forKey: key)
        return value > 0 ? value : fallback
    }

    private func isValidIPAddress(_ ip: String) -> Bool {
        let parts = ip.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        for part in parts {
            guard let number = Int(part), number >= 0 && number <= 255 else {
                return false
            }
        }
        return true
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func sectionLabel(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = NSColor.secondaryLabelColor
        return label
    }

    private func fieldLabel(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.alignment = .right
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor.labelColor
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.widthAnchor.constraint(equalToConstant: 180).isActive = true
        return label
    }

    private func makeRow(label: NSTextField, control: NSView) -> NSStackView {
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    private func verticalStack(spacing: CGFloat) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func styleTextField(_ textField: NSTextField) {
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.isEditable = true
        textField.isBezeled = true
        textField.drawsBackground = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.alignment = .left
        textField.controlSize = .regular
        textField.preferredMaxLayoutWidth = 220
        textField.wantsLayer = true
        textField.layer?.cornerRadius = 4
        textField.layer?.borderWidth = 1
        textField.layer?.borderColor = NSColor.separatorColor.cgColor
    }

    private func stylePopup(_ popup: NSPopUpButton) {
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.font = NSFont.systemFont(ofSize: 13)
        popup.controlSize = .regular
    }

    private func styleCheckbox(_ checkbox: NSButton) {
        checkbox.font = NSFont.systemFont(ofSize: 13)
        checkbox.controlSize = .regular
    }

    private func styleButton(_ button: NSButton, isPrimary: Bool) {
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 13, weight: isPrimary ? .semibold : .regular)
        button.controlSize = .regular
        if isPrimary {
            button.keyEquivalent = "\r"
        }
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        if isPrimary {
            button.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            button.contentTintColor = NSColor.white
        }
    }

    private func createSeparator() -> NSView {
        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }
}

class PreferencesWindowController: NSWindowController {
    convenience init(onSave: @escaping () -> Void) {
        let vc = PreferencesViewController()
        vc.onSave = onSave
        let window = NSWindow(contentViewController: vc)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 520))
        window.center()
        self.init(window: window)
    }
}
