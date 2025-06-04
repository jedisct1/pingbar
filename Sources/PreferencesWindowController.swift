import Cocoa

class PreferencesViewController: NSViewController {
    let intervalField = NSTextField()
    let hostField = NSTextField()
    let highPingField = NSTextField()
    let customDNSField = NSTextField()
    let revertDNSCheckbox = NSButton(checkboxWithTitle: "Revert DNS to System Default when network is unreachable", target: nil, action: nil)
    let restoreDNSCheckbox = NSButton(checkboxWithTitle: "Restore my custom DNS after passing captive portal", target: nil, action: nil)
    let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch PingBar at login", target: nil, action: nil)
    var onSave: ((String, Double, Int, String, Bool, Bool, Bool) -> Void)?

    override func loadView() {
        let view = NSView()
        self.view = view
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setFrameSize(NSSize(width: 480, height: 340))

        // Set a nice background color
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Header
        let headerLabel = NSTextField(labelWithString: "⚙️ PingBar Preferences")
        headerLabel.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        headerLabel.alignment = .center
        headerLabel.textColor = NSColor.labelColor

        // Section headers
        let networkSectionLabel = NSTextField(labelWithString: "🌐 Network Settings")
        networkSectionLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        networkSectionLabel.textColor = NSColor.secondaryLabelColor

        let dnsSectionLabel = NSTextField(labelWithString: "🔧 DNS Management")
        dnsSectionLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        dnsSectionLabel.textColor = NSColor.secondaryLabelColor

        let systemSectionLabel = NSTextField(labelWithString: "💻 System Integration")
        systemSectionLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        systemSectionLabel.textColor = NSColor.secondaryLabelColor

        // Labels
        let intervalLabel = NSTextField(labelWithString: "⏱ Ping interval (seconds):")
        let hostLabel = NSTextField(labelWithString: "🎯 Target host (URL):")
        let highPingLabel = NSTextField(labelWithString: "⚠️ High ping threshold (ms):")
        let customDNSLabel = NSTextField(labelWithString: "🔧 Custom DNS (optional):")
        intervalLabel.alignment = .right
        hostLabel.alignment = .right
        highPingLabel.alignment = .right
        customDNSLabel.alignment = .right
        intervalLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        hostLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        highPingLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        customDNSLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        intervalLabel.textColor = NSColor.labelColor
        hostLabel.textColor = NSColor.labelColor
        highPingLabel.textColor = NSColor.labelColor
        customDNSLabel.textColor = NSColor.labelColor

        // Fields with enhanced styling
        self.styleTextField(intervalField)
        intervalField.stringValue = String(UserDefaults.standard.double(forKey: "PingInterval") > 0 ? UserDefaults.standard.double(forKey: "PingInterval") : 5.0)
        intervalField.placeholderString = "e.g. 5"

        self.styleTextField(hostField)
        hostField.stringValue = UserDefaults.standard.string(forKey: "PingHost") ?? "https://www.google.com"
        hostField.placeholderString = "e.g. https://www.google.com"

        self.styleTextField(highPingField)
        highPingField.stringValue = String(UserDefaults.standard.integer(forKey: "HighPingThreshold") > 0 ? UserDefaults.standard.integer(forKey: "HighPingThreshold") : 200)
        highPingField.placeholderString = "e.g. 200"

        self.styleTextField(customDNSField)
        customDNSField.stringValue = UserDefaults.standard.string(forKey: "CustomDNSServer") ?? ""
        customDNSField.placeholderString = "e.g. 1.1.1.1 or My Server"

        // Styled checkboxes
        self.styleCheckbox(revertDNSCheckbox)
        self.styleCheckbox(restoreDNSCheckbox)
        self.styleCheckbox(launchAtLoginCheckbox)

        // Enhanced buttons
        let saveButton = NSButton(title: "💾 Save Settings", target: self, action: #selector(saveClicked))
        let cancelButton = NSButton(title: "❌ Cancel", target: self, action: #selector(cancelClicked))
        self.styleButton(saveButton, isPrimary: true)
        self.styleButton(cancelButton, isPrimary: false)
        saveButton.setContentHuggingPriority(.required, for: .horizontal)
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        // Create organized sections
        let headerStack = NSStackView(views: [headerLabel])
        headerStack.orientation = .vertical
        headerStack.spacing = 20
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        // Network settings section
        let networkStack = NSStackView()
        networkStack.orientation = .vertical
        networkStack.spacing = 12
        networkStack.translatesAutoresizingMaskIntoConstraints = false

        let intervalRow = NSStackView(views: [intervalLabel, intervalField])
        intervalRow.orientation = .horizontal
        intervalRow.spacing = 12
        intervalRow.alignment = .centerY

        let hostRow = NSStackView(views: [hostLabel, hostField])
        hostRow.orientation = .horizontal
        hostRow.spacing = 12
        hostRow.alignment = .centerY

        let highPingRow = NSStackView(views: [highPingLabel, highPingField])
        highPingRow.orientation = .horizontal
        highPingRow.spacing = 12
        highPingRow.alignment = .centerY

        let customDNSRow = NSStackView(views: [customDNSLabel, customDNSField])
        customDNSRow.orientation = .horizontal
        customDNSRow.spacing = 12
        customDNSRow.alignment = .centerY

        networkStack.addArrangedSubview(networkSectionLabel)
        networkStack.addArrangedSubview(intervalRow)
        networkStack.addArrangedSubview(hostRow)
        networkStack.addArrangedSubview(highPingRow)
        networkStack.addArrangedSubview(customDNSRow)

        // DNS settings section
        let dnsStack = NSStackView()
        dnsStack.orientation = .vertical
        dnsStack.spacing = 8
        dnsStack.translatesAutoresizingMaskIntoConstraints = false
        dnsStack.addArrangedSubview(dnsSectionLabel)
        dnsStack.addArrangedSubview(revertDNSCheckbox)
        dnsStack.addArrangedSubview(restoreDNSCheckbox)

        // System settings section
        let systemStack = NSStackView()
        systemStack.orientation = .vertical
        systemStack.spacing = 8
        systemStack.translatesAutoresizingMaskIntoConstraints = false
        systemStack.addArrangedSubview(systemSectionLabel)
        systemStack.addArrangedSubview(launchAtLoginCheckbox)

        // Main form stack
        let formStack = NSStackView()
        formStack.orientation = .vertical
        formStack.spacing = 20
        formStack.translatesAutoresizingMaskIntoConstraints = false
        formStack.addArrangedSubview(networkStack)
        formStack.addArrangedSubview(self.createSeparator())
        formStack.addArrangedSubview(dnsStack)
        formStack.addArrangedSubview(self.createSeparator())
        formStack.addArrangedSubview(systemStack)

        // Button stack
        let buttonStack = NSStackView(views: [saveButton, cancelButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.alignment = .centerY
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // Main vertical stack with better spacing
        let mainStack = NSStackView(views: [headerStack, formStack, buttonStack])
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
            intervalLabel.widthAnchor.constraint(equalToConstant: 180),
            hostLabel.widthAnchor.constraint(equalToConstant: 180),
            highPingLabel.widthAnchor.constraint(equalToConstant: 180),
            customDNSLabel.widthAnchor.constraint(equalToConstant: 180)
        ])

        revertDNSCheckbox.state = UserDefaults.standard.bool(forKey: "RevertDNSOnCaptivePortal") ? .on : .off
        restoreDNSCheckbox.state = UserDefaults.standard.bool(forKey: "RestoreCustomDNSAfterCaptive") ? .on : .off
        launchAtLoginCheckbox.state = UserDefaults.standard.bool(forKey: "LaunchAtLogin") ? .on : .off
    }

    @objc func saveClicked() {
        let interval = Double(intervalField.stringValue) ?? 5.0
        let host = hostField.stringValue
        let highPing = Int(highPingField.stringValue) ?? 200
        let customDNS = customDNSField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate custom DNS if provided
        if !customDNS.isEmpty {
            let components = customDNS.components(separatedBy: " ")
            let ipAddress = components[0]

            // Basic IP address validation
            if !isValidIPAddress(ipAddress) {
                let alert = NSAlert()
                alert.messageText = "Invalid DNS Server"
                alert.informativeText = "Please enter a valid IP address for the custom DNS server. Examples:\n• 1.1.1.1\n• 8.8.8.8 Google\n• 192.168.1.1 Home Router"
                alert.alertStyle = .warning
                alert.runModal()
                return
            }
        }

        let revertDNS = (revertDNSCheckbox.state == .on)
        let restoreDNS = (restoreDNSCheckbox.state == .on)
        let launchAtLogin = (launchAtLoginCheckbox.state == .on)
        UserDefaults.standard.set(highPing, forKey: "HighPingThreshold")
        UserDefaults.standard.set(customDNS, forKey: "CustomDNSServer")
        UserDefaults.standard.set(revertDNS, forKey: "RevertDNSOnCaptivePortal")
        UserDefaults.standard.set(restoreDNS, forKey: "RestoreCustomDNSAfterCaptive")
        UserDefaults.standard.set(launchAtLogin, forKey: "LaunchAtLogin")
        onSave?(host, interval, highPing, customDNS, revertDNS, restoreDNS, launchAtLogin)
        self.view.window?.close()
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

    @objc func cancelClicked() {
        self.view.window?.close()
    }

    // MARK: - UI Styling Helper Methods

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

    private func styleCheckbox(_ checkbox: NSButton) {
        checkbox.font = NSFont.systemFont(ofSize: 13)
        checkbox.controlSize = .regular
    }

    private func styleButton(_ button: NSButton, isPrimary: Bool) {
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 13, weight: isPrimary ? .semibold : .regular)
        button.controlSize = .regular

        if isPrimary {
            button.keyEquivalent = "\\r"
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
    convenience init(onSave: @escaping (String, Double, Int, String, Bool, Bool, Bool) -> Void) {
        let vc = PreferencesViewController()
        vc.onSave = onSave
        let window = NSWindow(contentViewController: vc)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 340))
        window.center()
        self.init(window: window)
    }
}