import AppKit
import ApplicationServices
import Carbon
import Darwin

private enum AppConstants {
    static let defaultInputSourceID = "com.apple.keylayout.US"
    static let inputSourceDefaultsKey = "TargetInputSourceID"

    // Apple consumer-page Spotlight key and keyboard-page F13.
    static let spotlightHIDUsage: UInt64 = 0x0C00000221
    static let f13HIDUsage: UInt64 = 0x0000000700000068
}

private struct HIDKeyMapping: Equatable {
    let source: UInt64
    let destination: UInt64

    var propertyListValue: [String: UInt64] {
        [
            "HIDKeyboardModifierMappingSrc": source,
            "HIDKeyboardModifierMappingDst": destination,
        ]
    }
}

private final class HIDMappingManager {
    private let spotlightMapping = HIDKeyMapping(
        source: AppConstants.spotlightHIDUsage,
        destination: AppConstants.f13HIDUsage
    )
    private var previousSpotlightMapping: HIDKeyMapping?

    @discardableResult
    func install() -> Bool {
        guard let current = readMappings() else {
            return false
        }

        previousSpotlightMapping = current.first {
            $0.source == AppConstants.spotlightHIDUsage
        }

        let updated = current.filter {
            $0.source != AppConstants.spotlightHIDUsage
        } + [spotlightMapping]

        return writeMappings(updated)
    }

    func restore() {
        guard var current = readMappings() else {
            return
        }

        current.removeAll {
            $0.source == AppConstants.spotlightHIDUsage
        }
        if let previousSpotlightMapping {
            current.append(previousSpotlightMapping)
        }

        _ = writeMappings(current)
    }

    private func readMappings() -> [HIDKeyMapping]? {
        let result = runHIDUtil(arguments: ["property", "--get", "UserKeyMapping"])
        guard result.status == 0 else {
            return nil
        }

        let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "(null)" || trimmed.isEmpty {
            return []
        }

        guard
            let data = trimmed.data(using: .utf8),
            let values = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionaries = values as? [[String: Any]]
        else {
            return nil
        }

        return dictionaries.compactMap { dictionary in
            guard
                let source = (dictionary["HIDKeyboardModifierMappingSrc"] as? NSNumber)?.uint64Value,
                let destination = (dictionary["HIDKeyboardModifierMappingDst"] as? NSNumber)?.uint64Value
            else {
                return nil
            }
            return HIDKeyMapping(source: source, destination: destination)
        }
    }

    private func writeMappings(_ mappings: [HIDKeyMapping]) -> Bool {
        let property: [String: Any] = [
            "UserKeyMapping": mappings.map(\.propertyListValue),
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: property),
            let json = String(data: data, encoding: .utf8)
        else {
            return false
        }

        return runHIDUtil(arguments: ["property", "--set", json]).status == 0
    }

    private func runHIDUtil(arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}

private struct InputSourceOption {
    let id: String
    let name: String
}

private func inputSourceProperty<T>(_ source: TISInputSource, _ key: CFString) -> T? {
    guard let pointer = TISGetInputSourceProperty(source, key) else {
        return nil
    }
    return Unmanaged<AnyObject>
        .fromOpaque(pointer)
        .takeUnretainedValue() as? T
}

private func inputSourceID(_ source: TISInputSource) -> String? {
    inputSourceProperty(source, kTISPropertyInputSourceID)
}

private func currentInputSourceID() -> String? {
    inputSourceID(TISCopyCurrentKeyboardInputSource().takeRetainedValue())
}

private func englishInputSources() -> [InputSourceOption] {
    guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
        return []
    }

    return sources.compactMap { source in
        guard
            let isSelectable: Bool = inputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable),
            isSelectable,
            let languages: [String] = inputSourceProperty(source, kTISPropertyInputSourceLanguages),
            languages.contains(where: { $0 == "en" || $0.hasPrefix("en-") }),
            let id = inputSourceID(source),
            let name: String = inputSourceProperty(source, kTISPropertyLocalizedName)
        else {
            return nil
        }
        return InputSourceOption(id: id, name: name)
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

private func selectedTargetInputSourceID() -> String {
    UserDefaults.standard.string(forKey: AppConstants.inputSourceDefaultsKey)
        ?? AppConstants.defaultInputSourceID
}

@discardableResult
private func selectInputSource(id: String) -> Bool {
    let filter = [kTISPropertyInputSourceID: id] as CFDictionary
    guard
        let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
        let source = sources.first
    else {
        return false
    }

    return TISSelectInputSource(source) == noErr
}

private func makeTemporaryKeyWindow() -> NSWindow? {
    guard let screen = NSScreen.main else {
        return nil
    }

    let frame = screen.visibleFrame
    let window = NSWindow(
        contentRect: NSRect(x: frame.maxX - 11, y: frame.minY + 8, width: 3, height: 3),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.titlebarAppearsTransparent = true
    window.isOpaque = false
    window.backgroundColor = .clear
    window.level = .screenSaver
    window.collectionBehavior = [.canJoinAllSpaces, .stationary]
    window.makeKeyAndOrderFront(nil)

    NSApplication.shared.activate(ignoringOtherApps: true)
    return window
}

@discardableResult
private func switchToTargetInputSource() -> Bool {
    let targetID = selectedTargetInputSourceID()
    if currentInputSourceID() == targetID {
        return true
    }

    guard selectInputSource(id: targetID) else {
        return false
    }

    // macOS 26 may defer a background TISSelectInputSource call until an app
    // receives keyboard focus. A tiny temporary key window forces that update.
    let temporaryWindow = makeTemporaryKeyWindow()
    let deadline = Date().addingTimeInterval(1.0)
    let earliestClose = Date().addingTimeInterval(0.15)

    while Date() < deadline {
        if currentInputSourceID() == targetID && Date() >= earliestClose {
            break
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }

    temporaryWindow?.orderOut(nil)
    return currentInputSourceID() == targetID
}

private func postSpotlightShortcut() {
    guard let source = CGEventSource(stateID: .hidSystemState) else {
        return
    }

    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: false)
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
}

private func switchThenOpenSpotlight() {
    if switchToTargetInputSource() {
        postSpotlightShortcut()
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let mappingManager = HIDMappingManager()
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var statusItem: NSStatusItem?
    private var stateMenuItem: NSMenuItem?
    private var inputSourcesMenu = NSMenu()
    private var permissionTimer: Timer?
    private var terminationSignalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        installTerminationSignalHandlers()
        let mappingApplied = mappingManager.install()
        let trustedOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(trustedOptions)

        configureStatusItem(mappingApplied: mappingApplied, trusted: trusted)
        if trusted {
            startKeyMonitors()
        } else {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                guard AXIsProcessTrusted() else {
                    return
                }
                timer.invalidate()
                self?.permissionTimer = nil
                self?.stateMenuItem?.title = "F4 opens Spotlight in English"
                self?.startKeyMonitors()
            }
        }
    }

    private func installTerminationSignalHandlers() {
        for signalValue in [SIGTERM, SIGINT] {
            Darwin.signal(signalValue, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: signalValue, queue: .main)
            source.setEventHandler {
                NSApplication.shared.terminate(nil)
            }
            source.resume()
            terminationSignalSources.append(source)
        }
    }

    private func startKeyMonitors() {
        guard globalKeyMonitor == nil else {
            return
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(kVK_F13), !event.isARepeat else {
                return
            }
            DispatchQueue.main.async {
                self?.handleHotKey()
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(kVK_F13), !event.isARepeat else {
                return event
            }
            self?.handleHotKey()
            return nil
        }
    }

    private func configureStatusItem(mappingApplied: Bool, trusted: Bool) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "magnifyingglass",
            accessibilityDescription: "Spotlight English"
        )

        let menu = NSMenu()
        let stateTitle: String
        if !mappingApplied {
            stateTitle = "Could not configure the Spotlight key"
        } else if !trusted {
            stateTitle = "Accessibility permission is required"
        } else {
            stateTitle = "F4 opens Spotlight in English"
        }

        let state = NSMenuItem(title: stateTitle, action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)
        stateMenuItem = state

        if !trusted {
            let settingsItem = NSMenuItem(
                title: "Open Accessibility Settings…",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            settingsItem.target = self
            menu.addItem(settingsItem)
        }

        rebuildInputSourcesMenu()
        let inputSourceItem = NSMenuItem(title: "English Input Source", action: nil, keyEquivalent: "")
        inputSourceItem.submenu = inputSourcesMenu
        menu.addItem(inputSourceItem)
        menu.addItem(.separator())

        let testItem = NSMenuItem(
            title: "Test Now",
            action: #selector(testNow),
            keyEquivalent: ""
        )
        testItem.target = self
        menu.addItem(testItem)

        let quitItem = NSMenuItem(
            title: "Quit Spotlight English",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func rebuildInputSourcesMenu() {
        inputSourcesMenu.removeAllItems()
        let selectedID = selectedTargetInputSourceID()

        for option in englishInputSources() {
            let item = NSMenuItem(
                title: option.name,
                action: #selector(selectTargetInputSource(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = option.id
            item.state = option.id == selectedID ? .on : .off
            inputSourcesMenu.addItem(item)
        }
    }

    @objc private func selectTargetInputSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else {
            return
        }
        UserDefaults.standard.set(id, forKey: AppConstants.inputSourceDefaultsKey)
        rebuildInputSourcesMenu()
    }

    @objc private func testNow() {
        switchThenOpenSpotlight()
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        mappingManager.restore()
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }

    private func handleHotKey() {
        switchThenOpenSpotlight()
    }
}

if CommandLine.arguments.contains("--validate-hid-mapping") {
    let manager = HIDMappingManager()
    guard manager.install() else {
        fputs("Could not install the temporary HID mapping\n", stderr)
        exit(3)
    }
    manager.restore()
    print("HID mapping install and restore succeeded")
    exit(0)
}

if CommandLine.arguments.contains("--switch-only") {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)

    guard switchToTargetInputSource() else {
        fputs("Input source did not change to \(selectedTargetInputSourceID())\n", stderr)
        exit(2)
    }

    print(selectedTargetInputSourceID())
    exit(0)
}

let application = NSApplication.shared
private let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
