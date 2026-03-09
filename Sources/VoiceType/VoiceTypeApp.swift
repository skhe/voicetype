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

        // Onboarding window — opens automatically on first launch via onChange below.
        // Closed when OnboardingManager.isComplete becomes true.
        Window("VoiceType 设置向导", id: "onboarding") {
            if !onboardingManager.isComplete {
                OnboardingView()
                    .environmentObject(appState)
                    .environmentObject(onboardingManager)
            }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .handlesExternalEvents(matching: [])

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - First-launch window opener

/// Wraps the app entry point so we can use @Environment(\.openWindow) after the scene graph is set up.
struct AppLauncher: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var onboardingManager: OnboardingManager

    var body: some View {
        EmptyView()
            .onAppear {
                if !onboardingManager.isComplete {
                    openWindow(id: "onboarding")
                }
            }
            .onChange(of: onboardingManager.isComplete) { _, complete in
                if complete {
                    // Close the window by removing the scene's content (handled by
                    // the conditional `if !isComplete` inside the Window scene).
                }
            }
    }
}
