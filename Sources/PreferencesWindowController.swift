import Cocoa

class PreferencesViewController: NSViewController {
    let intervalField = NSTextField()
    let hostField = NSTextField()
    let highPingField = NSTextField()
    let revertDNSCheckbox = NSButton(checkboxWithTitle: "Revert DNS to System Default when network is unreachable", target: nil, action: nil)
    let restoreDNSCheckbox = NSButton(checkboxWithTitle: "Restore my custom DNS after passing captive portal", target: nil, action: nil)
    let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch PingBar at login", target: nil, action: nil)
    var onSave: ((String, Double, Int, Bool, Bool, Bool) -> Void)?

    override func loadView() {
        let view = NSView()
        self.view = view
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setFrameSize(NSSize(width: 400, height: 290))

        // Labels
        let intervalLabel = NSTextField(labelWithString: "Ping interval (seconds):")
        let hostLabel = NSTextField(labelWithString: "Target host (URL):")
        let highPingLabel = NSTextField(labelWithString: "High ping threshold (ms):")
        intervalLabel.alignment = .right
        hostLabel.alignment = .right
        highPingLabel.alignment = .right
        intervalLabel.font = NSFont.systemFont(ofSize: 14)
        hostLabel.font = NSFont.systemFont(ofSize: 14)
        highPingLabel.alignment = .right

        // Fields
        intervalField.font = NSFont.systemFont(ofSize: 14)
        intervalField.isEditable = true
        intervalField.isBezeled = true
        intervalField.drawsBackground = true
        intervalField.translatesAutoresizingMaskIntoConstraints = false
        intervalField.stringValue = String(UserDefaults.standard.double(forKey: "PingInterval") > 0 ? UserDefaults.standard.double(forKey: "PingInterval") : 5.0)
        intervalField.placeholderString = "e.g. 5"
        intervalField.alignment = .left
        intervalField.controlSize = .regular
        intervalField.preferredMaxLayoutWidth = 200

        hostField.font = NSFont.systemFont(ofSize: 14)
        hostField.isEditable = true
        hostField.isBezeled = true
        hostField.drawsBackground = true
        hostField.translatesAutoresizingMaskIntoConstraints = false
        hostField.stringValue = UserDefaults.standard.string(forKey: "PingHost") ?? "https://www.google.com"
        hostField.placeholderString = "e.g. https://www.google.com"
        hostField.alignment = .left
        hostField.controlSize = .regular
        hostField.preferredMaxLayoutWidth = 200

        highPingField.font = NSFont.systemFont(ofSize: 14)
        highPingField.isEditable = true
        highPingField.isBezeled = true
        highPingField.drawsBackground = true
        highPingField.translatesAutoresizingMaskIntoConstraints = false
        highPingField.stringValue = String(UserDefaults.standard.integer(forKey: "HighPingThreshold") > 0 ? UserDefaults.standard.integer(forKey: "HighPingThreshold") : 200)
        highPingField.placeholderString = "e.g. 200"
        highPingField.alignment = .left
        highPingField.controlSize = .regular
        highPingField.preferredMaxLayoutWidth = 200

        // Buttons
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelClicked))
        saveButton.bezelStyle = .rounded
        cancelButton.bezelStyle = .rounded
        saveButton.setContentHuggingPriority(.required, for: .horizontal)
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        // Stack for fields
        let formStack = NSStackView()
        formStack.orientation = .vertical
        formStack.spacing = 16
        formStack.translatesAutoresizingMaskIntoConstraints = false

        // Row 1: Interval
        let intervalRow = NSStackView(views: [intervalLabel, intervalField])
        intervalRow.orientation = .horizontal
        intervalRow.spacing = 12
        intervalRow.alignment = .centerY
        // Row 2: Host
        let hostRow = NSStackView(views: [hostLabel, hostField])
        hostRow.orientation = .horizontal
        hostRow.spacing = 12
        hostRow.alignment = .centerY
        // Row 3: High ping threshold
        let highPingRow = NSStackView(views: [highPingLabel, highPingField])
        highPingRow.orientation = .horizontal
        highPingRow.spacing = 12
        highPingRow.alignment = .centerY
        formStack.addArrangedSubview(intervalRow)
        formStack.addArrangedSubview(hostRow)
        formStack.addArrangedSubview(highPingRow)

        // Add checkboxes to form
        formStack.addArrangedSubview(revertDNSCheckbox)
        formStack.addArrangedSubview(restoreDNSCheckbox)
        formStack.addArrangedSubview(launchAtLoginCheckbox)

        // Button stack
        let buttonStack = NSStackView(views: [saveButton, cancelButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.alignment = .centerY
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // Main vertical stack
        let mainStack = NSStackView(views: [formStack, buttonStack])
        mainStack.orientation = .vertical
        mainStack.spacing = 24
        mainStack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: view.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            intervalField.widthAnchor.constraint(equalToConstant: 200),
            hostField.widthAnchor.constraint(equalToConstant: 200),
            highPingField.widthAnchor.constraint(equalToConstant: 200)
        ])

        revertDNSCheckbox.state = UserDefaults.standard.bool(forKey: "RevertDNSOnCaptivePortal") ? .on : .off
        restoreDNSCheckbox.state = UserDefaults.standard.bool(forKey: "RestoreCustomDNSAfterCaptive") ? .on : .off
        launchAtLoginCheckbox.state = UserDefaults.standard.bool(forKey: "LaunchAtLogin") ? .on : .off
    }

    @objc func saveClicked() {
        let interval = Double(intervalField.stringValue) ?? 5.0
        let host = hostField.stringValue
        let highPing = Int(highPingField.stringValue) ?? 200
        let revertDNS = (revertDNSCheckbox.state == .on)
        let restoreDNS = (restoreDNSCheckbox.state == .on)
        let launchAtLogin = (launchAtLoginCheckbox.state == .on)
        UserDefaults.standard.set(highPing, forKey: "HighPingThreshold")
        UserDefaults.standard.set(revertDNS, forKey: "RevertDNSOnCaptivePortal")
        UserDefaults.standard.set(restoreDNS, forKey: "RestoreCustomDNSAfterCaptive")
        UserDefaults.standard.set(launchAtLogin, forKey: "LaunchAtLogin")
        onSave?(host, interval, highPing, revertDNS, restoreDNS, launchAtLogin)
        self.view.window?.close()
    }

    @objc func cancelClicked() {
        self.view.window?.close()
    }
}

class PreferencesWindowController: NSWindowController {
    convenience init(onSave: @escaping (String, Double, Int, Bool, Bool, Bool) -> Void) {
        let vc = PreferencesViewController()
        vc.onSave = onSave
        let window = NSWindow(contentViewController: vc)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 400, height: 290))
        self.init(window: window)
    }
} 