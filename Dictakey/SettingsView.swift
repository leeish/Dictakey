import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedMicUID") private var selectedMicUID: String = ""
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode: Int = 49
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers: Int = 2048 // optionKey
    @AppStorage("whisperModel") private var whisperModel: String = "base"

    static let modelOptions: [(id: String, label: String, detail: String)] = [
        ("tiny",     "Tiny",     "~65 MB · Fastest, lowest accuracy"),
        ("base",     "Base",     "~142 MB · Good balance of speed and accuracy"),
        ("small",    "Small",    "~483 MB · Better accuracy, slightly slower"),
        ("medium",   "Medium",   "~1.5 GB · High accuracy, slower"),
        ("large-v3", "Large v3", "~3.1 GB · Best accuracy, slowest"),
    ]

    private var appStatus = AppStatus.shared

    // Load devices immediately so the Picker has valid tags on first render
    @State private var inputDevices: [(uid: String, name: String)] = AudioRecorder.availableInputDevices()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Dictakey")
                .font(.title)
                .fontWeight(.bold)

            GroupBox("Microphone") {
                Picker("Input Device", selection: $selectedMicUID) {
                    Text("System Default").tag("")
                    ForEach(inputDevices, id: \.uid) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .pickerStyle(.menu)
                .padding(8)
            }

            GroupBox("Transcription Model") {
                Picker("Model", selection: $whisperModel) {
                    ForEach(Self.modelOptions, id: \.id) { option in
                        Text("\(option.label)  —  \(option.detail)").tag(option.id)
                    }
                }
                .pickerStyle(.menu)
                .padding(8)
                .onChange(of: whisperModel) { _, _ in
                    NotificationCenter.default.post(name: .modelChanged, object: nil)
                }

                if let progress = appStatus.downloadProgress {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Downloading \(whisperModel) model…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: progress)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }

            GroupBox("Hotkey") {
                HStack {
                    Text("Hold to record:")
                    Spacer()
                    HotkeyRecorderView(keyCode: $hotkeyKeyCode, modifiers: $hotkeyModifiers)
                        .frame(width: 140, height: 24)
                }
                .padding(8)
            }

            GroupBox("How to use") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Hold your hotkey to record", systemImage: "mic")
                    Label("Release to transcribe & paste", systemImage: "doc.on.clipboard")
                    Label("Works in any app with a text cursor", systemImage: "cursorarrow.rays")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            GroupBox("Permissions required") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Microphone — for recording audio", systemImage: "mic.badge.plus")
                    Label("Accessibility — for simulating paste", systemImage: "hand.raised")
                    Label("Speech Recognition (optional)", systemImage: "waveform")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            Button("Open Accessibility Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
        .padding(30)
        .frame(width: 380)
    }
}
