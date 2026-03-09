import SwiftUI
import KeyboardShortcuts

// Thin wrapper so OnboardingView doesn't need to import KeyboardShortcuts directly
struct KeyboardShortcutsRecorderWrapper: View {
    var body: some View {
        KeyboardShortcuts.Recorder("", name: .toggleRecording)
    }
}
