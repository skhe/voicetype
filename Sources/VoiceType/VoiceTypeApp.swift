import SwiftUI
import KeyboardShortcuts

@main
struct VoiceTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate.appState)
        } label: {
            MenuBarIcon(state: appDelegate.appState.status)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}

// MARK: - App Delegate

/// Single source of truth for AppState and OnboardingManager.
/// Opens the onboarding window directly via NSWindow+NSHostingController in
/// applicationDidFinishLaunching so it appears before any user interaction
/// — regardless of whether MenuBarExtra content has been rendered yet.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let appState = AppState()
    let onboardingManager = OnboardingManager()

    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !OnboardingManager.isCompleted else { return }
        openOnboardingWindow()
    }

    private func openOnboardingWindow() {
        let content = OnboardingView()
            .environmentObject(appState)
            .environmentObject(onboardingManager)
            .onReceive(onboardingManager.$isComplete) { [weak self] complete in
                if complete {
                    self?.onboardingWindow?.close()
                    self?.onboardingWindow = nil
                }
            }

        let controller = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: controller)
        window.title = "VoiceType 设置向导"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
