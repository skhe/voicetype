import Foundation
import WhisperKit

@MainActor
class ModelDownloader: ObservableObject {
    @Published var selectedModel = "large-v3"
    @Published var isDownloading = false
    @Published var isComplete = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""

    private var downloadTask: Task<Void, Never>?

    func download() async {
        isDownloading = true
        isComplete = false
        progress = 0
        statusMessage = "正在初始化…"

        downloadTask = Task {
            do {
                statusMessage = "正在下载模型 \(selectedModel)…"
                // Use WhisperKit.download with progress callback
                _ = try await WhisperKit.download(
                    variant: selectedModel,
                    progressCallback: { [weak self] prog in
                        Task { @MainActor [weak self] in
                            self?.progress = prog.fractionCompleted
                            if prog.fractionCompleted < 1.0 {
                                let pct = Int(prog.fractionCompleted * 100)
                                self?.statusMessage = "下载中… \(pct)%"
                            } else {
                                self?.statusMessage = "正在预热模型…"
                            }
                        }
                    }
                )
                if !Task.isCancelled {
                    // Pre-warm by loading the kit
                    _ = try await WhisperKit(model: selectedModel)
                    isComplete = true
                    statusMessage = "模型已就绪"
                }
            } catch {
                if !Task.isCancelled {
                    statusMessage = "下载失败: \(error.localizedDescription)"
                }
            }
            isDownloading = false
        }
        await downloadTask?.value
    }

    func cancel() {
        downloadTask?.cancel()
        isDownloading = false
        progress = 0
        statusMessage = ""
    }
}
