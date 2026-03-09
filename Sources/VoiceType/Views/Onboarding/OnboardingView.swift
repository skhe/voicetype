import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager()
    @EnvironmentObject var appState: AppState

    var body: some View {
        if manager.isComplete {
            EmptyView()
        } else {
            onboardingContent
                .frame(width: 560, height: 420)
        }
    }

    @ViewBuilder
    private var onboardingContent: some View {
        VStack(spacing: 0) {
            // Progress bar
            HStack(spacing: 4) {
                ForEach(0..<4) { i in
                    Capsule()
                        .fill(i <= manager.currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)

            // Step content
            Group {
                switch manager.currentStep {
                case .modelSetup:
                    ModelSetupStep(manager: manager)
                case .apiKey:
                    APIKeyStep(appState: appState, manager: manager)
                case .shortcut:
                    ShortcutStep(manager: manager)
                case .permissions:
                    PermissionsStep(appState: appState, manager: manager)
                case .done:
                    DoneStep(manager: manager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.regularMaterial)
    }
}

// MARK: - Step 1: Model Setup

struct ModelSetupStep: View {
    @ObservedObject var manager: OnboardingManager
    @StateObject private var downloader = ModelDownloader()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("选择 Whisper 模型")
                .font(.title2.bold())

            Text("VoiceType 使用本地 Whisper 模型进行语音转录，无需联网。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Picker("模型", selection: $downloader.selectedModel) {
                Text("large-v3（~3GB，最准确，推荐）").tag("large-v3")
                Text("small（~500MB，较快）").tag("openai_whisper-small")
                Text("base（~150MB，最快）").tag("openai_whisper-base")
            }
            .pickerStyle(.radioGroup)

            if downloader.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: downloader.progress)
                        .frame(width: 320)
                    Text(downloader.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("取消") { downloader.cancel() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                }
            } else if downloader.isComplete {
                Label("模型已就绪", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                HStack(spacing: 12) {
                    Button("下载模型") {
                        Task { await downloader.download() }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("跳过（手动配置）") {
                        manager.advance()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            if downloader.isComplete {
                Button("继续") { manager.advance() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
    }
}

// MARK: - Step 2: API Key

struct APIKeyStep: View {
    @ObservedObject var appState: AppState
    @ObservedObject var manager: OnboardingManager
    @State private var isVerifying = false
    @State private var verificationResult: VerificationResult?

    enum VerificationResult { case success, failure(String) }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)

            Text("OpenAI API Key")
                .font(.title2.bold())

            Text("用于 AI 后处理：去填充词、自我纠正、自动标点。\n若不需要可跳过，直接使用原始 Whisper 转录结果。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            SecureField("sk-...", text: $appState.openAIKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)

            if let result = verificationResult {
                switch result {
                case .success:
                    Label("API Key 有效", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failure(let msg):
                    Label(msg, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            HStack(spacing: 12) {
                Button(isVerifying ? "验证中…" : "验证并继续") {
                    Task { await verify() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.openAIKey.isEmpty || isVerifying)

                Button("跳过") { manager.advance() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
    }

    private func verify() async {
        isVerifying = true
        verificationResult = nil
        do {
            var req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
            req.setValue("Bearer \(appState.openAIKey)", forHTTPHeaderField: "Authorization")
            req.timeoutInterval = 10
            let (_, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(code) {
                verificationResult = .success
                try? await Task.sleep(nanoseconds: 800_000_000)
                manager.advance()
            } else {
                verificationResult = .failure("无效 Key（HTTP \(code)）")
            }
        } catch {
            verificationResult = .failure("网络错误，请检查连接")
        }
        isVerifying = false
    }
}

// MARK: - Step 3: Shortcut

struct ShortcutStep: View {
    @ObservedObject var manager: OnboardingManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("设置录音快捷键")
                .font(.title2.bold())

            Text("按住快捷键开始录音，松开后自动转录并写入剪贴板。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("当前快捷键：")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                KeyboardShortcutsRecorderWrapper()
                    .frame(width: 200)
            }

            Text("默认为 ⌥Space，可随时在设置中更改。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("继续") { manager.advance() }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

// MARK: - Step 4: Permissions

struct PermissionsStep: View {
    @ObservedObject var appState: AppState
    @ObservedObject var manager: OnboardingManager
    @State private var micGranted = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("授予权限")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 16) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "麦克风权限",
                    subtitle: "录音必需",
                    isGranted: micGranted,
                    action: {
                        Task { await requestMic() }
                    }
                )

                PermissionRow(
                    icon: "accessibility",
                    title: "辅助功能权限",
                    subtitle: "自动粘贴功能需要（可选）",
                    isGranted: AXIsProcessTrusted(),
                    action: {
                        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
                        AXIsProcessTrustedWithOptions(opts as CFDictionary)
                    }
                )
            }
            .frame(width: 360)

            Button("完成设置") { manager.advance() }
                .buttonStyle(.borderedProminent)
                .disabled(!micGranted)
        }
        .padding(32)
        .onAppear { checkMic() }
    }

    private func checkMic() {
        micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func requestMic() async {
        micGranted = await AVCaptureDevice.requestAccess(for: .audio)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isGranted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("授权") { action() }.buttonStyle(.bordered).controlSize(.small)
            }
        }
    }
}

// MARK: - Done

struct DoneStep: View {
    @ObservedObject var manager: OnboardingManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("一切就绪！")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 8) {
                Label("按住 ⌥Space 开始录音", systemImage: "mic.fill")
                Label("松开后自动转录，结果写入剪贴板", systemImage: "doc.on.clipboard")
                Label("菜单栏图标显示当前状态", systemImage: "menubar.rectangle")
            }
            .font(.body)

            Button("开始使用") { manager.complete() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
    }
}
