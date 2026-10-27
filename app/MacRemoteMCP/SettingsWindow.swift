import Cocoa
import Darwin

class SettingsWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var apiField: NSTextField?
    private var bindMode: NSPopUpButton?
    private var bindAddress: NSTextField?
    private var tlsCheck: NSButton?
    private var certField: NSTextField?
    private var keyField: NSTextField?

    func show() {
        if let w = window, w.isVisible { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }

        // Temporarily show in dock so window can receive focus
        NSApp.setActivationPolicy(.regular)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        w.title = L("settings.window.title")
        w.center()
        w.delegate = self
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.contentView = buildContent()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Reset level after activation so it doesn't stay always-on-top
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            w.level = .normal
        }
        window = w
    }

    private func buildContent() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 900))

        var y = 860

        // ── Title ──
        let title = makeLabel(L("settings.window.title"), size: 18, bold: true)
        title.frame = NSRect(x: 20, y: y, width: 480, height: 28)
        container.addSubview(title)
        y -= 40

        // ── API Key ──
        let apiLabel = makeLabel(L("settings.apikey.label"), size: 13, bold: true)
        apiLabel.frame = NSRect(x: 20, y: y, width: 100, height: 20)
        container.addSubview(apiLabel)
        y -= 28

        let apiFieldLocal = NSTextField(frame: NSRect(x: 20, y: y, width: 340, height: 24))
        apiFieldLocal.stringValue = Config.shared.apiKey
        apiFieldLocal.isEditable = false
        apiFieldLocal.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        apiFieldLocal.tag = 100
        container.addSubview(apiFieldLocal)
        self.apiField = apiFieldLocal

        let copyBtn = NSButton(frame: NSRect(x: 365, y: y, width: 65, height: 24))
        copyBtn.title = L("settings.button.copy")
        copyBtn.bezelStyle = .rounded
        copyBtn.font = NSFont.systemFont(ofSize: 11)
        copyBtn.target = self
        copyBtn.action = #selector(copyApiKey)
        container.addSubview(copyBtn)

        let rotateBtn = NSButton(frame: NSRect(x: 435, y: y, width: 65, height: 24))
        rotateBtn.title = L("settings.button.regenerate")
        rotateBtn.bezelStyle = .rounded
        rotateBtn.font = NSFont.systemFont(ofSize: 11)
        rotateBtn.target = self
        rotateBtn.action = #selector(rotateApiKey)
        container.addSubview(rotateBtn)
        y -= 36

        // ── Ports ──
        let portsLabel = makeLabel(L("settings.ports.label"), size: 13, bold: true)
        portsLabel.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        container.addSubview(portsLabel)
        y -= 28

        let portLabels = [L("settings.port.server"), L("settings.port.playwright"), L("settings.port.authproxy")]
        let portValues = [Config.shared.serverPort, Config.shared.playwrightPort, Config.shared.proxyPort]
        let portKeys = ["PORT", "PLAYWRIGHT_PORT", "PROXY_PORT"]

        for i in 0..<3 {
            let label = makeLabel(portLabels[i], size: 12, bold: false)
            label.frame = NSRect(x: 40, y: y, width: 120, height: 20)
            container.addSubview(label)

            let field = NSTextField(frame: NSRect(x: 170, y: y, width: 80, height: 22))
            field.stringValue = String(portValues[i])
            field.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            field.tag = 201 + i
            container.addSubview(field)

            let keyLabel = makeLabel(portKeys[i], size: 10, bold: false)
            keyLabel.textColor = .secondaryLabelColor
            keyLabel.frame = NSRect(x: 260, y: y, width: 150, height: 20)
            container.addSubview(keyLabel)
            y -= 28
        }
        y -= 8

        // ── Network / TLS ──
        let networkLabel = makeLabel(L("settings.network.title"), size: 13, bold: true)
        networkLabel.frame = NSRect(x: 20, y: y, width: 480, height: 20)
        container.addSubview(networkLabel)
        y -= 30

        let mode = NSPopUpButton(frame: NSRect(x: 20, y: y, width: 215, height: 26))
        mode.addItems(withTitles: [L("settings.network.localhost"), L("settings.network.lan"), L("settings.network.custom")])
        let currentHost = Config.shared.serverHost
        mode.selectItem(at: currentHost == "127.0.0.1" ? 0 : (currentHost.contains(",") || currentHost == "0.0.0.0" || currentHost.contains(":") ? 2 : 1))
        mode.target = self
        mode.action = #selector(networkModeChanged)
        container.addSubview(mode)
        bindMode = mode
        let address = NSTextField(frame: NSRect(x: 245, y: y, width: 255, height: 24))
        address.stringValue = currentHost
        address.placeholderString = "10.0.0.53"
        container.addSubview(address)
        bindAddress = address
        networkModeChanged()
        y -= 26
        let bindHint = makeLabel(L("settings.network.hint"), size: 10, bold: false)
        bindHint.frame = NSRect(x: 20, y: y, width: 480, height: 18)
        bindHint.textColor = .secondaryLabelColor
        container.addSubview(bindHint)
        y -= 28

        let tls = NSButton(checkboxWithTitle: L("settings.tls.enable"), target: nil, action: nil)
        tls.frame = NSRect(x: 20, y: y, width: 480, height: 20)
        tls.state = Config.shared.tlsEnabled ? .on : .off
        container.addSubview(tls)
        tlsCheck = tls
        y -= 30
        for (index, labelText, value) in [(0, L("settings.tls.cert"), Config.shared.tlsCertPath), (1, L("settings.tls.key"), Config.shared.tlsKeyPath)] {
            let label = makeLabel(labelText, size: 11, bold: false)
            label.frame = NSRect(x: 20, y: y, width: 110, height: 20)
            container.addSubview(label)
            let field = NSTextField(frame: NSRect(x: 135, y: y, width: 290, height: 24))
            field.stringValue = value
            field.placeholderString = "/absolute/path/to/file.pem"
            container.addSubview(field)
            if index == 0 { certField = field } else { keyField = field }
            let browse = NSButton(frame: NSRect(x: 430, y: y, width: 70, height: 24))
            browse.title = L("settings.tls.browse")
            browse.bezelStyle = .rounded
            browse.tag = index
            browse.target = self
            browse.action = #selector(browseTLSFile(_:))
            container.addSubview(browse)
            y -= 30
        }
        let tlsHint = makeLabel(L("settings.tls.hint"), size: 10, bold: false)
        tlsHint.frame = NSRect(x: 20, y: y, width: 480, height: 18)
        tlsHint.textColor = .secondaryLabelColor
        container.addSubview(tlsHint)
        y -= 36

        // ── Auto Start ──
        let autoCheck = NSButton(checkboxWithTitle: L("settings.autostart.checkbox"), target: nil, action: nil)
        autoCheck.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        autoCheck.state = Config.shared.autoStart ? .on : .off
        autoCheck.tag = 300
        container.addSubview(autoCheck)
        y -= 36

        // ── Cloudflare Tunnel ──
        let cfLabel = makeLabel(L("settings.cloudflare.label"), size: 13, bold: true)
        cfLabel.frame = NSRect(x: 20, y: y, width: 300, height: 20)
        container.addSubview(cfLabel)
        y -= 24

        let cfDesc = makeLabel(L("settings.cloudflare.desc"), size: 10, bold: false)
        cfDesc.textColor = .secondaryLabelColor
        cfDesc.frame = NSRect(x: 20, y: y, width: 480, height: 16)
        container.addSubview(cfDesc)
        y -= 24

        let cfTokenLabel = makeLabel("Tunnel Token", size: 12, bold: false)
        cfTokenLabel.frame = NSRect(x: 40, y: y, width: 100, height: 20)
        container.addSubview(cfTokenLabel)

        let cfTokenField = NSTextField(frame: NSRect(x: 150, y: y, width: 350, height: 22))
        cfTokenField.stringValue = Config.shared.tunnelToken
        cfTokenField.placeholderString = L("settings.cloudflare.token.placeholder")
        cfTokenField.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        cfTokenField.tag = 400
        container.addSubview(cfTokenField)
        y -= 30

        let setupBtn = NSButton(frame: NSRect(x: 40, y: y, width: 220, height: 28))
        setupBtn.title = L("settings.cloudflare.setup.button")
        setupBtn.bezelStyle = .rounded
        setupBtn.target = self
        setupBtn.action = #selector(runTunnelSetup)
        container.addSubview(setupBtn)

        let helpLabel = makeLabel(L("settings.cloudflare.help"), size: 10, bold: false)
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.frame = NSRect(x: 270, y: y + 4, width: 230, height: 16)
        container.addSubview(helpLabel)
        y -= 36

        // ── Permission Status ──
        let permLabel = makeLabel(L("settings.permissions.label"), size: 13, bold: true)
        permLabel.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        container.addSubview(permLabel)
        y -= 26

        let accStatus = PermissionChecker.checkAccessibility()
        let scrStatus = PermissionChecker.checkScreenRecording()

        let perms = [
            (L("permission.accessibility"), accStatus, true),
            (L("permission.screenrecording"), scrStatus, false),
        ]

        for (name, granted, isAccessibility) in perms {
            let icon = granted ? "✅" : "❌"
            let status = makeLabel("\(icon) \(name)", size: 12, bold: false)
            status.frame = NSRect(x: 40, y: y, width: 200, height: 18)
            container.addSubview(status)

            if !granted {
                let fixBtn = NSButton(frame: NSRect(x: 250, y: y - 2, width: 100, height: 22))
                fixBtn.title = L("permission.button.opensettings")
                fixBtn.bezelStyle = .rounded
                fixBtn.font = NSFont.systemFont(ofSize: 11)
                fixBtn.target = self
                if isAccessibility {
                    fixBtn.action = #selector(openAccessibility)
                } else {
                    fixBtn.action = #selector(openScreenRecording)
                }
                container.addSubview(fixBtn)
            }
            y -= 24
        }
        y -= 16

        // ── Buttons ──
        let saveBtn = NSButton(frame: NSRect(x: 310, y: 16, width: 90, height: 32))
        saveBtn.title = L("settings.button.save")
        saveBtn.bezelStyle = .rounded
        saveBtn.keyEquivalent = "\r"
        saveBtn.target = self
        saveBtn.action = #selector(saveSettings(_:))
        container.addSubview(saveBtn)

        let cancelBtn = NSButton(frame: NSRect(x: 410, y: 16, width: 90, height: 32))
        cancelBtn.title = L("settings.button.close")
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.target = self
        cancelBtn.action = #selector(closeWindow)
        container.addSubview(cancelBtn)

        let envBtn = NSButton(frame: NSRect(x: 20, y: 16, width: 160, height: 32))
        envBtn.title = L("settings.button.editenv")
        envBtn.bezelStyle = .rounded
        envBtn.font = NSFont.systemFont(ofSize: 11)
        envBtn.target = self
        envBtn.action = #selector(openEnvFile)
        container.addSubview(envBtn)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 720))
        scroll.hasVerticalScroller = true
        scroll.documentView = container
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 180))
        scroll.reflectScrolledClipView(scroll.contentView)
        return scroll
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, size: CGFloat, bold: Bool) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        return label
    }

    // MARK: - Actions

    @objc private func networkModeChanged() {
        let isLocal = bindMode?.indexOfSelectedItem == 0
        if isLocal { bindAddress?.stringValue = "127.0.0.1" }
        else if bindMode?.indexOfSelectedItem == 1 && bindAddress?.stringValue == "127.0.0.1" {
            bindAddress?.stringValue = ""
        }
        bindAddress?.isEnabled = !isLocal
    }

    @objc private func browseTLSFile(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            (sender.tag == 0 ? certField : keyField)?.stringValue = url.path
        }
    }

    private func settingsError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L("settings.network.invalid")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc private func copyApiKey() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(apiField?.stringValue ?? Config.shared.apiKey, forType: .string)
    }

    @objc private func rotateApiKey() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L("settings.rotate.confirm.title")
        alert.informativeText = L("settings.rotate.confirm.body")
        alert.addButton(withTitle: L("settings.button.regenerate"))
        alert.addButton(withTitle: L("common.cancel"))
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        // Generate new key
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let newKey = bytes.map { String(format: "%02x", $0) }.joined()

        // Update .env file
        let envPath = Config.shared.configDir + "/.env"
        if var contents = try? String(contentsOfFile: envPath, encoding: .utf8) {
            if let range = contents.range(of: "MCP_API_KEY=.*", options: .regularExpression) {
                contents.replaceSubrange(range, with: "MCP_API_KEY=\(newKey)")
            } else {
                contents += "\nMCP_API_KEY=\(newKey)\n"
            }
            try? contents.write(toFile: envPath, atomically: true, encoding: .utf8)
        }

        // Update UI
        apiField?.stringValue = newKey

        // Copy to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(newKey, forType: .string)

        let doneAlert = NSAlert()
        doneAlert.messageText = L("settings.rotate.done.title")
        doneAlert.informativeText = L("settings.rotate.done.body")
        doneAlert.runModal()
    }

    @objc private func openAccessibility() {
        PermissionChecker.openAccessibilitySettings()
    }

    @objc private func openScreenRecording() {
        PermissionChecker.openScreenRecordingSettings()
    }

    @objc private func openEnvFile() {
        let envFile = Config.shared.configDir + "/.env"
        if FileManager.default.fileExists(atPath: envFile) {
            NSWorkspace.shared.open(URL(fileURLWithPath: envFile))
        }
    }

    @objc private func runTunnelSetup() {
        TunnelSetupWizard.run { [weak self] token in
            guard let token = token, let contentView = self?.window?.contentView else { return }
            // Update the token field in the UI
            if let field = contentView.viewWithTag(400) as? NSTextField {
                field.stringValue = token
            }
        }
    }

    @objc private func saveSettings(_ sender: Any) {
        guard let contentView = window?.contentView else { return }

        // Merge with existing values so saving does not delete tunnel hostname or custom settings.
        let envPath = Config.shared.configDir + "/.env"
        let existingContents: String
        do {
            existingContents = try String(contentsOfFile: envPath, encoding: .utf8)
        } catch {
            settingsError(error.localizedDescription); return
        }
        var envVars = EnvParser.parse(existingContents)
        let host = (bindAddress?.stringValue ?? "127.0.0.1").trimmingCharacters(in: .whitespacesAndNewlines)
        let hosts = host.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let validAddress: (String) -> Bool = { value in
            var ipv4 = in_addr()
            var ipv6 = in6_addr()
            return inet_pton(AF_INET, value, &ipv4) == 1 || inet_pton(AF_INET6, value, &ipv6) == 1
        }
        guard !hosts.isEmpty, hosts.allSatisfy(validAddress) else {
            settingsError(L("settings.network.address_error")); return
        }
        if bindMode?.indexOfSelectedItem == 1 {
            guard hosts.count == 1, !["0.0.0.0", "::", "::1"].contains(hosts[0]), !hosts[0].hasPrefix("127.") else {
                settingsError(L("settings.network.lan_error")); return
            }
        }
        envVars["HOST"] = hosts.joined(separator: ",")
        envVars["TLS_ENABLED"] = tlsCheck?.state == .on ? "true" : "false"
        for (key, field) in [("TLS_CERT_PATH", certField), ("TLS_KEY_PATH", keyField)] {
            let value = field?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
            guard value.rangeOfCharacter(from: .newlines) == nil else {
                settingsError(L("settings.tls.path_error")); return
            }
            if tlsCheck?.state == .on {
                var isDirectory: ObjCBool = false
                guard value.hasPrefix("/"), FileManager.default.fileExists(atPath: value, isDirectory: &isDirectory),
                      !isDirectory.boolValue, FileManager.default.isReadableFile(atPath: value) else {
                    settingsError(L("settings.tls.path_error")); return
                }
            }
            envVars[key] = value
        }
        envVars["MCP_API_KEY"] = apiField?.stringValue ?? Config.shared.apiKey

        // Read port fields
        let portKeys = ["PORT", "PLAYWRIGHT_PORT", "PROXY_PORT"]
        for i in 0..<3 {
            if let field = contentView.viewWithTag(201 + i) as? NSTextField {
                let val = field.stringValue.trimmingCharacters(in: .whitespaces)
                guard let port = Int(val), (1...65535).contains(port) else {
                    settingsError(L("settings.network.port_error")); return
                }
                envVars[portKeys[i]] = String(port)
            }
        }

        // Auto start
        if let check = contentView.viewWithTag(300) as? NSButton {
            envVars["AUTO_START"] = check.state == .on ? "true" : "false"
        }

        // Tunnel token
        if let field = contentView.viewWithTag(400) as? NSTextField {
            let token = field.stringValue.trimmingCharacters(in: .whitespaces)
            envVars["CLOUDFLARE_TUNNEL_TOKEN"] = token
        }

        // Save to .env
        var lines = ["# mac-remote-mcp configuration", ""]
        for key in envVars.keys.sorted() {
            if let val = envVars[key] {
                lines.append("\(key)=\(val)")
            }
        }
        lines.append("")
        do {
            try lines.joined(separator: "\n").write(toFile: envPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: envPath)
        } catch {
            settingsError(error.localizedDescription); return
        }

        // Auto-restart
        Self.relaunchApp()
    }

    static func relaunchApp() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath, "--args", "--relaunch"]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    @objc private func closeWindow() {
        window?.close()
        // Switch back to menu bar only (no dock icon)
        NSApp.setActivationPolicy(.accessory)
    }

    // NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
