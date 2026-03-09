import SwiftUI
import KeyboardShortcuts

@main
struct VoiceTypeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var onboardingManager = OnboardingManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            MenuBarIcon(state: appState.status)
        }
        .menuBarExtraStyle(.window)

        // Onboarding window — shown only on first launch
        Window("VoiceType 设置向导", id: "onboarding") {
            OnboardingView()
                .environmentObject(appState)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
