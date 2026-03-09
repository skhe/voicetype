import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: appState.status.systemImageName)
                    .foregroundStyle(statusColor)
                    .symbolEffect(.pulse, isActive: isActive)
                Text(appState.status.description)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Last transcription
            if !appState.lastTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最近转录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appState.lastTranscription)
                        .font(.body)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
            }

            // Shortcut hint
            HStack {
                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                KeyboardShortcuts.Recorder("录音快捷键", name: .toggleRecording)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Actions
            Button("设置…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .buttonStyle(.plain)

            Button("退出 VoiceType") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .buttonStyle(.plain)
            .padding(.bottom, 4)
        }
        .frame(width: 320)
    }

    private var statusColor: Color {
        switch appState.status {
        case .idle, .starting: return .secondary
        case .recording: return .red
        case .transcribing: return .blue
        case .postProcessing: return .purple
        case .error: return .orange
        }
    }

    private var isActive: Bool {
        switch appState.status {
        case .idle, .error: return false
        default: return true
        }
    }
}

struct MenuBarIcon: View {
    let state: RecordingStatus

    var body: some View {
        Image(systemName: state.systemImageName)
            .symbolRenderingMode(.hierarchical)
    }
}
