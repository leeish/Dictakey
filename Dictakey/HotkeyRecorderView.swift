import AppKit
import Carbon
import SwiftUI

extension Notification.Name {
    static let hotkeyRecordingStarted = Notification.Name("Dictakey.hotkeyRecordingStarted")
    static let hotkeyChanged = Notification.Name("Dictakey.hotkeyChanged")
}

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    func makeNSView(context: Context) -> RecorderButton {
        let btn = RecorderButton()
        btn.keyCode = keyCode
        btn.modifiers = modifiers
        btn.onChange = { kc, mods in
            keyCode = kc
            modifiers = mods
        }
        return btn
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        guard !nsView.isRecording else { return }
        nsView.keyCode = keyCode
        nsView.modifiers = modifiers
        nsView.refreshTitle()
    }
}

class RecorderButton: NSButton {
    var keyCode: Int = 49
    var modifiers: Int = Int(optionKey)
    var onChange: ((Int, Int) -> Void)?
    private(set) var isRecording = false
    private var pendingModifier: NSEvent.ModifierFlags?

    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        bezelStyle = .rounded
        target = self
        action = #selector(startRecording)
        refreshTitle()
    }

    required init?(coder: NSCoder) { fatalError() }

    func refreshTitle() {
        title = isRecording ? "Press a key or hold a modifier…" : hotkeyLabel(keyCode: keyCode, modifiers: modifiers)
    }

    @objc private func startRecording() {
        isRecording = true
        pendingModifier = nil
        refreshTitle()
        NotificationCenter.default.post(name: .hotkeyRecordingStarted, object: nil)
        window?.makeFirstResponder(self)
    }

    // A regular key was pressed — save as key+modifier combo
    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        pendingModifier = nil

        // Escape cancels without saving
        if event.keyCode == 53 {
            isRecording = false
            refreshTitle()
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
            window?.makeFirstResponder(nil)
            return
        }

        let kc = Int(event.keyCode)
        let mods = carbonMods(event.modifierFlags)
        isRecording = false
        keyCode = kc
        modifiers = mods
        refreshTitle()
        onChange?(kc, mods)
        NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
        window?.makeFirstResponder(nil)
    }

    // A modifier was pressed or released — detect hold-and-release for modifier-only hotkey
    override func flagsChanged(with event: NSEvent) {
        guard isRecording else { return }

        let active = event.modifierFlags.intersection([.control, .option, .command, .shift])

        if !active.isEmpty {
            pendingModifier = active
        } else if let pending = pendingModifier {
            // Modifier released without any key press — save as modifier-only (keyCode = -1)
            pendingModifier = nil
            isRecording = false
            keyCode = -1
            modifiers = Int(pending.rawValue)
            refreshTitle()
            onChange?(-1, modifiers)
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
            window?.makeFirstResponder(nil)
        }
    }

    // MARK: - Helpers

    private func carbonMods(_ flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.control) { m |= Int(controlKey) }
        if flags.contains(.option)  { m |= Int(optionKey) }
        if flags.contains(.shift)   { m |= Int(shiftKey) }
        if flags.contains(.command) { m |= Int(cmdKey) }
        return m
    }
}

// MARK: - Label helpers (used by AppDelegate tooltip too)

func hotkeyLabel(keyCode: Int, modifiers: Int) -> String {
    if keyCode == -1 {
        // modifier-only: modifiers is NSEvent.ModifierFlags.rawValue
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option)  { s += "⌥" }
        if flags.contains(.shift)   { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s.isEmpty ? "None" : "\(s) (hold)"
    }
    var s = ""
    if modifiers & Int(controlKey) != 0 { s += "⌃" }
    if modifiers & Int(optionKey)  != 0 { s += "⌥" }
    if modifiers & Int(shiftKey)   != 0 { s += "⇧" }
    if modifiers & Int(cmdKey)     != 0 { s += "⌘" }
    s += keyName(keyCode)
    return s
}

func keyName(_ code: Int) -> String {
    let special: [Int: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        116: "PgUp", 121: "PgDn", 115: "Home", 119: "End",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
        97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12"
    ]
    if let name = special[code] { return name }

    guard let sourceRef = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
          let dataRef = TISGetInputSourceProperty(sourceRef, kTISPropertyUnicodeKeyLayoutData) else {
        return "·"
    }
    let layoutData = unsafeBitCast(dataRef, to: CFData.self)
    let layoutPtr = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)
    var deadState: UInt32 = 0
    var length = 0
    var chars = [UniChar](repeating: 0, count: 4)
    UCKeyTranslate(layoutPtr, UInt16(code), UInt16(kUCKeyActionDisplay), 0,
                   UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                   &deadState, 4, &length, &chars)
    return length > 0 ? String(utf16CodeUnits: chars, count: length).uppercased() : "·"
}
