import SwiftUI
import KeyboardShortcuts

@main
struct VoiceTypeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var onboardingManager = OnboardingManager()

    var body: some Scene {
        MenuBarExtra {
            // AppLauncher is embedded here so it's always rendered at startup
            // and can call openWindow(id: "onboarding") via @Environment.
            AppLauncher(onboardingManager: onboardingManager)
            MenuBarView()
                .environmentObject(appState)
        } label: {
            MenuBarIcon(state: appState.status)
        }
        .menuBarExtraStyle(.window)

        // Onboarding window.
        // Content is guarded by isComplete so it collapses after the user finishes.
        Window("VoiceType 设置向导", id: "onboarding") {
            if !onboardingManager.isComplete {
                OnboardingView()
                    .environmentObject(appState)
                    .environmentObject(onboardingManager)
            }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - First-launch window opener

/// Zero-size view rendered inside MenuBarExtra content so @Environment(\.openWindow) is available.
/// On first launch it calls openWindow(id: "onboarding") exactly once via onAppear.
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
    }
}
