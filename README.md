# VoiceType

轻量级 macOS 语音转文字工具 — 本地 Whisper STT + OpenAI 后处理

## 安装

### 系统要求

- macOS 14.0+（Sonoma）
- Apple Silicon（M1/M2/M3/M4）
- 磁盘空间：App ~50MB + 模型 150MB–3GB

### 下载安装（推荐）

1. 前往 [Releases](https://github.com/skhe/voicetype/releases) 下载最新 `.dmg`
2. 打开 DMG，将 **VoiceType.app** 拖入 `/Applications`
3. 首次启动会弹出设置向导，按步骤完成配置即可

### 从源码构建

```bash
git clone https://github.com/skhe/voicetype
cd voicetype
open Package.swift   # 用 Xcode 打开
```

在 Xcode 中选择 Mac 目标，按 ⌘R 运行。

> **注意**：`swift run` 无法直接运行（macOS SwiftUI 应用需要 .app bundle）。

## 首次启动向导

打开 App 后会依次引导完成：

1. **模型下载** — 选择并下载 Whisper 模型（large-v3 约 3GB，首次需等待）
2. **API Key** — 输入 OpenAI API Key（可选，跳过则不做 AI 后处理）
3. **快捷键** — 自定义录音快捷键（默认 ⌥Space）
4. **权限** — 麦克风权限（必须）+ 辅助功能权限（自动粘贴可选）

## 使用

| 操作 | 说明 |
|------|------|
| **按住 ⌥Space** | 开始录音 |
| **松开 ⌥Space** | 停止录音，自动转录 |
| 转录完成 | 结果写入剪贴板 + 系统通知弹出 |
| 开启自动粘贴 | 转录结果自动粘贴到当前光标位置 |

## 隐私说明

- 语音录音：本地处理，临时文件转录后立即删除
- Whisper 转录：完全本地，通过 Apple Neural Engine 运行
- OpenAI API Key：存储于系统 Keychain，不落地明文
- 剪贴板：仅写入，不读取历史内容

## 技术栈

| 层 | 选型 |
|----|------|
| UI | SwiftUI + MenuBarExtra |
| 全局热键 | KeyboardShortcuts 1.15.0 |
| 录音 | AVAudioEngine（16kHz 单声道 PCM）|
| STT | WhisperKit（本地 CoreML + ANE）|
| 后处理 | OpenAI GPT-4o-mini |
| 输出 | NSPasteboard + CGEvent ⌘V |
| 凭证 | Security.framework Keychain |

## 构建发布包

```bash
# 需要 Developer ID 证书 + 公证凭证
export APPLE_TEAM_ID=XXXXXXXXXX
export APPLE_ID=you@example.com
export APPLE_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx

./scripts/build-release.sh 1.0.0

# 跳过公证（本地测试）
./scripts/build-release.sh 1.0.0 --skip-notarize
```

输出：`build/VoiceType-1.0.0.dmg`
