import AppKit
import AVFoundation
import Carbon
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKeyRef: EventHotKeyRef?
    var recorder: AudioRecorder?
    var transcriber: WhisperTranscriber?
    var isRecording = false
    var targetApp: NSRunningApplication?

    let hotKeyID = EventHotKeyID(signature: OSType(0x57505354), id: UInt32(1)) // 'WPST'
    private var eventHandlerInstalled = false
    private var modifierMonitor: Any?
    private var localModifierMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Set defaults so integer(forKey:) returns correct values before user changes anything
        UserDefaults.standard.register(defaults: [
            "hotkeyKeyCode": 49,       // Space
            "hotkeyModifiers": 2048    // optionKey
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(hotkeyRecordingStarted),
                                               name: .hotkeyRecordingStarted, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reregisterHotKey),
                                               name: .hotkeyChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadModel),
                                               name: .modelChanged, object: nil)

        setupHotKey()
        requestPermissions()

        recorder = AudioRecorder()
        transcriber = WhisperTranscriber()

        startModelLoad()
    }

    // MARK: - Status Icon

    enum AppState { case loading, ready, recording, transcribing }

    func updateStatusIcon(state: AppState) {
        let status = AppStatus.shared
        switch state {
        case .loading:
            status.icon = "⏳"
            status.tooltip = "Dictakey: Loading model..."
        case .ready:
            status.icon = "🎙"
            status.tooltip = "Dictakey: Ready (hold ⌥Space to record)"
        case .recording:
            status.icon = "🔴"
            status.tooltip = "Dictakey: Recording..."
        case .transcribing:
            status.icon = "✍️"
            status.tooltip = "Dictakey: Transcribing..."
        }
    }

    // MARK: - Hotkey Registration

    func setupHotKey() {
        installEventHandler()
        let kc = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        if kc == -1 {
            setupModifierOnlyMonitor()
        } else {
            registerHotKey()
        }
    }

    private func installEventHandler() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true

        let eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        InstallEventHandler(GetApplicationEventTarget(),
                            { (_, event, userData) -> OSStatus in
                                guard let ud = userData else { return OSStatus(eventNotHandledErr) }
                                let delegate = Unmanaged<AppDelegate>.fromOpaque(ud).takeUnretainedValue()
                                var hkID = EventHotKeyID()
                                GetEventParameter(event,
                                                  EventParamName(kEventParamDirectObject),
                                                  EventParamType(typeEventHotKeyID),
                                                  nil,
                                                  MemoryLayout<EventHotKeyID>.size,
                                                  nil,
                                                  &hkID)
                                let kind = GetEventKind(event)
                                if kind == kEventHotKeyPressed {
                                    delegate.hotkeyPressed()
                                } else if kind == kEventHotKeyReleased {
                                    delegate.hotkeyReleased()
                                }
                                return noErr
                            },
                            2,
                            eventTypes,
                            Unmanaged.passUnretained(self).toOpaque(),
                            nil)
    }

    private func registerHotKey() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        let kc = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        guard kc >= 0 else { return } // -1 means modifier-only, handled separately
        let mods = UInt32(UserDefaults.standard.integer(forKey: "hotkeyModifiers"))
        var id = hotKeyID
        RegisterEventHotKey(UInt32(kc), mods, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func setupModifierOnlyMonitor() {
        tearDownModifierMonitor()
        let rawMask = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        let target = NSEvent.ModifierFlags(rawValue: UInt(rawMask))

        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            let active = event.modifierFlags.intersection([.control, .option, .command, .shift])
            DispatchQueue.main.async {
                if active == target && !self.isRecording {
                    self.hotkeyPressed()
                } else if !active.contains(target) && self.isRecording {
                    self.hotkeyReleased()
                }
            }
        }
        modifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler)
        localModifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event); return event
        }
    }

    private func tearDownModifierMonitor() {
        if let m = modifierMonitor { NSEvent.removeMonitor(m); modifierMonitor = nil }
        if let m = localModifierMonitor { NSEvent.removeMonitor(m); localModifierMonitor = nil }
    }

    @objc private func reregisterHotKey() {
        tearDownModifierMonitor()
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        let kc = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        if kc == -1 {
            setupModifierOnlyMonitor()
        } else {
            registerHotKey()
        }
    }

    @objc private func reloadModel() {
        guard !isRecording else { return }
        startModelLoad()
    }

    private static let modelSizes: [String: String] = [
        "tiny":     "~65 MB",
        "base":     "~142 MB",
        "small":    "~483 MB",
        "medium":   "~1.5 GB",
        "large-v3": "~3.1 GB",
    ]

    private func startModelLoad() {
        let modelName = UserDefaults.standard.string(forKey: "whisperModel") ?? "base"
        updateStatusIcon(state: .loading)

        transcriber?.onPhaseChange = { [weak self] phase in
            guard let self else { return }
            let status = AppStatus.shared
            switch phase {
            case .downloading(let fraction):
                let pct = Int(fraction * 100)
                let size = AppDelegate.modelSizes[modelName] ?? ""
                status.icon = "⬇️"
                status.tooltip = "Dictakey: Downloading \(modelName) model \(size)… \(pct)%"
                status.downloadProgress = fraction
            case .loading:
                status.icon = "⏳"
                status.tooltip = "Dictakey: Loading \(modelName) model…"
                status.downloadProgress = nil
            }
        }

        Task {
            await transcriber?.loadModel()
            DispatchQueue.main.async {
                AppStatus.shared.downloadProgress = nil
                self.updateStatusIcon(state: .ready)
            }
        }
    }

    @objc private func hotkeyRecordingStarted() {
        // Suspend active hotkey so it doesn't fire while user presses keys in the recorder
        tearDownModifierMonitor()
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
    }

    // MARK: - Recording Logic

    func hotkeyPressed() {
        guard !isRecording, transcriber?.isModelLoaded == true else { return }
        targetApp = NSWorkspace.shared.frontmostApplication
        isRecording = true
        DispatchQueue.main.async { self.updateStatusIcon(state: .recording) }
        recorder?.startRecording()
    }

    func hotkeyReleased() {
        guard isRecording else { return }
        isRecording = false
        DispatchQueue.main.async { self.updateStatusIcon(state: .transcribing) }

        recorder?.stopRecording { [weak self] audioURL in
            guard let self, let url = audioURL else {
                DispatchQueue.main.async { self?.updateStatusIcon(state: .ready) }
                return
            }

            Task {
                let text = await self.transcriber?.transcribe(audioURL: url) ?? ""
                DispatchQueue.main.async {
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.pasteText(text)
                    }
                    self.updateStatusIcon(state: .ready)
                }
            }
        }
    }

    // MARK: - Paste

    func pasteText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        if !AXIsProcessTrusted() {
            // Re-prompt — likely a new build path invalidated the old permission
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(opts as CFDictionary)
            print("Accessibility not trusted — re-prompting. Text is on clipboard (⌘V).")
            // Still attempt the paste; on some builds the events go through anyway
        }

        let app = targetApp
        targetApp = nil
        app?.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let src = CGEventSource(stateID: .combinedSessionState)
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // V
            keyDown?.flags = .maskCommand
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Permissions

    func requestPermissions() {
        // Microphone
        AVCaptureDevice.requestAccess(for: .audio) { _ in }

        // Accessibility (needed for CGEvent paste simulation)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
