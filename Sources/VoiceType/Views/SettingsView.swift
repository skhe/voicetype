import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAPIKey = false

    var body: some View {
        Form {
            Section("快捷键") {
                KeyboardShortcuts.Recorder(for: .toggleRecording)
            }

            Section("语言") {
                Picker("识别语言", selection: $appState.language) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                }
                .pickerStyle(.radioGroup)
                Text("语言影响语音识别准确率和后处理输出")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("OpenAI 后处理") {
                Toggle("启用 AI 后处理", isOn: $appState.enablePostProcessing)

                HStack {
                    Text("API Key")
                    Spacer()
                    if showAPIKey {
                        TextField("sk-...", text: $appState.openAIKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                    } else {
                        SecureField("sk-...", text: $appState.openAIKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)
                    }
                    Button(showAPIKey ? "隐藏" : "显示") {
                        showAPIKey.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
                .disabled(!appState.enablePostProcessing)

                if appState.openAIKey.isEmpty && appState.enablePostProcessing {
                    Text("⚠️ 未设置 API Key，将跳过后处理直接输出原始转录")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Whisper 模型") {
                Picker("模型", selection: $appState.whisperModel) {
                    Text("large-v3（~3GB，最准确）").tag("large-v3")
                    Text("base（~150MB，较快）").tag("openai_whisper-base")
                    Text("small（~500MB，平衡）").tag("openai_whisper-small")
                }
                .pickerStyle(.radioGroup)

                Text("模型首次使用时自动下载并缓存到本地")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("输出") {
                Toggle("转录完成后自动粘贴到当前位置（需要辅助功能权限）", isOn: $appState.autoPaste)
                    .onChange(of: appState.autoPaste) { _, newValue in
                        if newValue {
                            requestAccessibilityPermission()
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .padding()
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
