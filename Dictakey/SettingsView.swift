import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedMicUID") private var selectedMicUID: String = ""
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode: Int = 49
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers: Int = 2048 // optionKey

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
