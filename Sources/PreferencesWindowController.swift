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
    let revertDNSCheckbox = NSButton(
        checkboxWithTitle: "Revert DNS to System Default when network is unreachable",
        target: nil, action: nil)
    let restoreDNSCheckbox = NSButton(
        checkboxWithTitle: "Restore my custom DNS after passing captive portal",
        target: nil, action: nil)
    let showNetworkInterfacesCheckbox = NSButton(
        checkboxWithTitle: "Show network interfaces section in the menu",
        target: nil, action: nil)
    let launchAtLoginCheckbox = NSButton(
        checkboxWithTitle: "Launch PingBar at login",
        target: nil, action: nil)
    var onSave: (() -> Void)?

    override func loadView() {
        let view = NSView()
        self.view = view
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setFrameSize(NSSize(width: 520, height: 520))
        view.wantsLayer = true

        let headerLabel = NSTextField(labelWithString: "PingBar Preferences")
        headerLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        headerLabel.alignment = .center
        headerLabel.textColor = NSColor.labelColor

        configureFieldValues()

        let formStack = verticalStack(spacing: 20)
        formStack.addArrangedSubview(buildNetworkStack())
        formStack.addArrangedSubview(createSeparator())
        formStack.addArrangedSubview(buildPacketLossStack())
        formStack.addArrangedSubview(createSeparator())
        formStack.addArrangedSubview(buildInterfacesStack())
        formStack.addArrangedSubview(createSeparator())
        formStack.addArrangedSubview(buildDNSStack())
        formStack.addArrangedSubview(createSeparator())
        formStack.addArrangedSubview(buildSystemStack())

        let mainStack = NSStackView(
            views: [headerLabel, formStack, buildButtonStack()])
        mainStack.orientation = .vertical
        mainStack.spacing = 24
        mainStack.edgeInsets = NSEdgeInsets(
            top: 30, left: 30, bottom: 30, right: 30)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)
        activateConstraints(mainStack: mainStack, view: view)
        loadCheckboxStates()
        refreshPacketLossFieldState()
    }

    @objc func saveClicked() {
        let interval = max(1.0, Double(intervalField.stringValue) ?? 5.0)
        let host = hostField.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines)
        let highPing = max(1, Int(highPingField.stringValue) ?? 200)
        let customDNS = customDNSField.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines)
        let isActive = packetLossModePopup.titleOfSelectedItem == "Active"
        let mode: PingManager.PacketLossMode = isActive ? .active : .passive
        let probeInterval = max(
            1.0, Double(packetLossProbeIntervalField.stringValue) ?? 30.0)
        let burstSize = max(
            1, min(Int(packetLossBurstSizeField.stringValue) ?? 5, 100))
        let windowSize = max(
            10, min(Int(packetLossWindowSizeField.stringValue) ?? 50, 500))
        let warnThreshold = max(
            0.1, Double(packetLossWarningThresholdField.stringValue) ?? 3.0)
        let badThreshold = Double(
            packetLossBadThresholdField.stringValue) ?? 10.0

        guard !host.isEmpty, URL(string: host) != nil else {
            showAlert(
                title: "Invalid Target Host",
                message: "Please enter a valid URL such as https://www.google.com")
            return
        }

        if !customDNS.isEmpty {
            let components = customDNS.components(separatedBy: " ")
            let ipAddress = components[0]
            if !isValidIPAddress(ipAddress) {
                showAlert(
                    title: "Invalid DNS Server",
                    message: "Please enter a valid IP address for the custom DNS server."
                        + " Examples:\n\u{2022} 1.1.1.1\n\u{2022} 8.8.8.8 Google"
                        + "\n\u{2022} 192.168.1.1 Home Router")
                return
            }
        }

        guard badThreshold > warnThreshold else {
            showAlert(
                title: "Invalid Packet Loss Thresholds",
                message: "The bad packet loss threshold must be higher than the warning threshold.")
            return
        }

        let revertDNS = (revertDNSCheckbox.state == .on)
        let restoreDNS = (restoreDNSCheckbox.state == .on)
        let showNetworkInterfaces = (showNetworkInterfacesCheckbox.state == .on)
        let launchAtLogin = (launchAtLoginCheckbox.state == .on)

        let defaults = UserDefaults.standard
        defaults.set(interval, forKey: UserDefaultsKey.pingInterval)
        defaults.set(host, forKey: UserDefaultsKey.pingHost)
        defaults.set(highPing, forKey: UserDefaultsKey.highPingThreshold)
        defaults.set(customDNS, forKey: UserDefaultsKey.customDNSServer)
        defaults.set(mode.rawValue, forKey: UserDefaultsKey.packetLossMode)
        defaults.set(probeInterval, forKey: UserDefaultsKey.packetLossProbeInterval)
        defaults.set(burstSize, forKey: UserDefaultsKey.packetLossBurstSize)
        defaults.set(windowSize, forKey: UserDefaultsKey.packetLossWindowSize)
        defaults.set(warnThreshold, forKey: UserDefaultsKey.packetLossWarningThreshold)
        defaults.set(badThreshold, forKey: UserDefaultsKey.packetLossBadThreshold)
        defaults.set(revertDNS, forKey: UserDefaultsKey.revertDNSOnCaptivePortal)
        defaults.set(restoreDNS, forKey: UserDefaultsKey.restoreCustomDNSAfterCaptive)
        defaults.set(showNetworkInterfaces, forKey: UserDefaultsKey.showNetworkInterfaces)
        defaults.set(launchAtLogin, forKey: UserDefaultsKey.launchAtLogin)

        onSave?()
        view.window?.close()
    }

    @objc func cancelClicked() {
        view.window?.close()
    }

    @objc private func packetLossModeChanged() {
        refreshPacketLossFieldState()
    }

}

private extension PreferencesViewController {
    func configureFieldValues() {
        styleTextField(intervalField)
        let interval = defaultDouble(
            for: UserDefaultsKey.pingInterval, fallback: 5.0)
        intervalField.stringValue = String(interval)
        intervalField.placeholderString = "e.g. 5"

        styleTextField(hostField)
        let savedHost = UserDefaults.standard.string(
            forKey: UserDefaultsKey.pingHost)
        hostField.stringValue = savedHost ?? "https://www.google.com"
        hostField.placeholderString = "e.g. https://www.google.com"

        styleTextField(highPingField)
        let highPing = defaultInt(
            for: UserDefaultsKey.highPingThreshold, fallback: 200)
        highPingField.stringValue = String(highPing)
        highPingField.placeholderString = "e.g. 200"

        styleTextField(customDNSField)
        let savedDNS = UserDefaults.standard.string(
            forKey: UserDefaultsKey.customDNSServer)
        customDNSField.stringValue = savedDNS ?? ""
        customDNSField.placeholderString = "e.g. 1.1.1.1 or My Server"

        configurePacketLossModePopup()
        configurePacketLossFields()

        styleCheckbox(revertDNSCheckbox)
        styleCheckbox(restoreDNSCheckbox)
        styleCheckbox(showNetworkInterfacesCheckbox)
        styleCheckbox(launchAtLoginCheckbox)
    }

    func configurePacketLossModePopup() {
        stylePopup(packetLossModePopup)
        packetLossModePopup.addItems(withTitles: ["Passive", "Active"])
        let modeKey = UserDefaultsKey.packetLossMode
        let raw = UserDefaults.standard.string(forKey: modeKey) ?? ""
        let savedMode = PingManager.PacketLossMode(rawValue: raw) ?? .passive
        packetLossModePopup.selectItem(withTitle: savedMode.displayName)
        packetLossModePopup.target = self
        packetLossModePopup.action = #selector(packetLossModeChanged)
    }

    func configurePacketLossFields() {
        styleTextField(packetLossProbeIntervalField)
        let probeInterval = defaultDouble(
            for: UserDefaultsKey.packetLossProbeInterval, fallback: 30.0)
        packetLossProbeIntervalField.stringValue = String(probeInterval)
        packetLossProbeIntervalField.placeholderString = "e.g. 30"

        styleTextField(packetLossBurstSizeField)
        let burstSize = defaultInt(
            for: UserDefaultsKey.packetLossBurstSize, fallback: 5)
        packetLossBurstSizeField.stringValue = String(burstSize)
        packetLossBurstSizeField.placeholderString = "e.g. 5"

        styleTextField(packetLossWindowSizeField)
        let windowSize = defaultInt(
            for: UserDefaultsKey.packetLossWindowSize, fallback: 50)
        packetLossWindowSizeField.stringValue = String(windowSize)
        packetLossWindowSizeField.placeholderString = "e.g. 50"

        styleTextField(packetLossWarningThresholdField)
        let warnThreshold = defaultDouble(
            for: UserDefaultsKey.packetLossWarningThreshold, fallback: 3.0)
        packetLossWarningThresholdField.stringValue = String(warnThreshold)
        packetLossWarningThresholdField.placeholderString = "e.g. 3"

        styleTextField(packetLossBadThresholdField)
        let badThreshold = defaultDouble(
            for: UserDefaultsKey.packetLossBadThreshold, fallback: 10.0)
        packetLossBadThresholdField.stringValue = String(badThreshold)
        packetLossBadThresholdField.placeholderString = "e.g. 10"
    }

    func buildNetworkStack() -> NSStackView {
        let stack = verticalStack(spacing: 12)
        stack.addArrangedSubview(sectionLabel("Ping Settings"))
        stack.addArrangedSubview(makeRow(
            label: fieldLabel("Ping interval (seconds):"),
            control: intervalField))
        stack.addArrangedSubview(makeRow(
            label: fieldLabel("Target host (URL):"),
            control: hostField))
        stack.addArrangedSubview(makeRow(
            label: fieldLabel("High ping threshold (ms):"),
            control: highPingField))
        stack.addArrangedSubview(makeRow(
            label: fieldLabel("Custom DNS (optional):"),
            control: customDNSField))
        return stack
    }

    func buildPacketLossStack() -> NSStackView {
        let stack = verticalStack(spacing: 12)
        stack.addArrangedSubview(sectionLabel("Packet Loss"))
        stack.addArrangedSubview(makeRow(
            label: fieldLabel("Loss measurement mode:"),
            control: packetLossModePopup))
        stack.addArrangedSubview(makeRow(
            label: fieldLabel("Active probe interval (s):"),
            control: packetLossProbeIntervalField))
        stack.addArrangedSubview(makeRow(
            label: fieldLabel("Active burst size:"),
            control: packetLossBurstSizeField))
        stack.addArrangedSubview(makeRow(
            label: fieldLabel("Loss window size:"),
            control: packetLossWindowSizeField))
        stack.addArrangedSubview(makeRow(
            label: fieldLabel("Warning threshold (%):"),
            control: packetLossWarningThresholdField))
        stack.addArrangedSubview(makeRow(
            label: fieldLabel("Bad threshold (%):"),
            control: packetLossBadThresholdField))
        return stack
    }

    func buildInterfacesStack() -> NSStackView {
        let stack = verticalStack(spacing: 8)
        stack.addArrangedSubview(sectionLabel("Network Interfaces"))
        stack.addArrangedSubview(showNetworkInterfacesCheckbox)
        return stack
    }

    func buildDNSStack() -> NSStackView {
        let stack = verticalStack(spacing: 8)
        stack.addArrangedSubview(sectionLabel("DNS Management"))
        stack.addArrangedSubview(revertDNSCheckbox)
        stack.addArrangedSubview(restoreDNSCheckbox)
        return stack
    }

    func buildSystemStack() -> NSStackView {
        let stack = verticalStack(spacing: 8)
        stack.addArrangedSubview(sectionLabel("System Integration"))
        stack.addArrangedSubview(launchAtLoginCheckbox)
        return stack
    }

    func buildButtonStack() -> NSStackView {
        let saveButton = NSButton(
            title: "Save Settings", target: self,
            action: #selector(saveClicked))
        let cancelButton = NSButton(
            title: "Cancel", target: self,
            action: #selector(cancelClicked))
        styleButton(saveButton, isPrimary: true)
        styleButton(cancelButton, isPrimary: false)
        saveButton.setContentHuggingPriority(.required, for: .horizontal)
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [saveButton, cancelButton])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    func activateConstraints(mainStack: NSStackView, view: NSView) {
        let fieldWidth: CGFloat = 220
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: view.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            intervalField.widthAnchor.constraint(equalToConstant: fieldWidth),
            hostField.widthAnchor.constraint(equalToConstant: fieldWidth),
            highPingField.widthAnchor.constraint(equalToConstant: fieldWidth),
            customDNSField.widthAnchor.constraint(equalToConstant: fieldWidth),
            packetLossProbeIntervalField.widthAnchor.constraint(
                equalToConstant: fieldWidth),
            packetLossBurstSizeField.widthAnchor.constraint(
                equalToConstant: fieldWidth),
            packetLossWindowSizeField.widthAnchor.constraint(
                equalToConstant: fieldWidth),
            packetLossWarningThresholdField.widthAnchor.constraint(
                equalToConstant: fieldWidth),
            packetLossBadThresholdField.widthAnchor.constraint(
                equalToConstant: fieldWidth),
            packetLossModePopup.widthAnchor.constraint(
                equalToConstant: fieldWidth),
        ])
    }

    func loadCheckboxStates() {
        let defaults = UserDefaults.standard
        revertDNSCheckbox.state = defaults.bool(
            forKey: UserDefaultsKey.revertDNSOnCaptivePortal) ? .on : .off
        restoreDNSCheckbox.state = defaults.bool(
            forKey: UserDefaultsKey.restoreCustomDNSAfterCaptive) ? .on : .off
        showNetworkInterfacesCheckbox.state = defaults.showNetworkInterfaces ? .on : .off
        launchAtLoginCheckbox.state = defaults.bool(
            forKey: UserDefaultsKey.launchAtLogin) ? .on : .off
    }

    func refreshPacketLossFieldState() {
        let isActive = packetLossModePopup.titleOfSelectedItem == "Active"
        packetLossProbeIntervalField.isEnabled = isActive
        packetLossBurstSizeField.isEnabled = isActive
        packetLossProbeIntervalField.alphaValue = isActive ? 1.0 : 0.55
        packetLossBurstSizeField.alphaValue = isActive ? 1.0 : 0.55
    }

    func defaultInt(for key: String, fallback: Int) -> Int {
        let value = UserDefaults.standard.integer(forKey: key)
        return value > 0 ? value : fallback
    }

    func defaultDouble(for key: String, fallback: Double) -> Double {
        let value = UserDefaults.standard.double(forKey: key)
        return value > 0 ? value : fallback
    }

    func isValidIPAddress(_ address: String) -> Bool {
        let parts = address.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        for part in parts {
            guard let number = Int(part), number >= 0 && number <= 255 else {
                return false
            }
        }
        return true
    }

    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    func sectionLabel(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = NSColor.secondaryLabelColor
        return label
    }

    func fieldLabel(_ string: String) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.alignment = .right
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = NSColor.labelColor
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.widthAnchor.constraint(equalToConstant: 180).isActive = true
        return label
    }

    func makeRow(label: NSTextField, control: NSView) -> NSStackView {
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    func verticalStack(spacing: CGFloat) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    func styleTextField(_ textField: NSTextField) {
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.isEditable = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.drawsBackground = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.alignment = .left
        textField.controlSize = .regular
        textField.preferredMaxLayoutWidth = 220
    }

    func stylePopup(_ popup: NSPopUpButton) {
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.font = NSFont.systemFont(ofSize: 13)
        popup.controlSize = .regular
    }

    func styleCheckbox(_ checkbox: NSButton) {
        checkbox.font = NSFont.systemFont(ofSize: 13)
        checkbox.controlSize = .regular
    }

    func styleButton(_ button: NSButton, isPrimary: Bool) {
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(
            ofSize: 13, weight: isPrimary ? .semibold : .regular)
        button.controlSize = .regular
        if isPrimary {
            button.keyEquivalent = "\r"
        }
    }

    func createSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        return separator
    }
}

class PreferencesWindowController: NSWindowController {
    convenience init(onSave: @escaping () -> Void) {
        let controller = PreferencesViewController()
        controller.onSave = onSave
        let window = NSWindow(contentViewController: controller)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 520))
        window.center()
        self.init(window: window)
    }
}
