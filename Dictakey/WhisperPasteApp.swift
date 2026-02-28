import ServiceManagement
import SwiftUI

@main
struct DictakeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openSettings) private var openSettings
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    private var appStatus = AppStatus.shared

    var body: some Scene {
        MenuBarExtra {
            Text("Hotkey: ⌥Space (hold to record)")
            Divider()
            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("Launch at login error: \(error)")
                    }
                }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        } label: {
            Text(appStatus.icon)
                .help(appStatus.tooltip)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}
