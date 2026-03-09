# VoiceType

轻量级 macOS 语音转文字工具 — 本地 Whisper STT + OpenAI 后处理

## 核心功能

- 麦克风录音（⌥Space 按住录音，松开停止）
- WhisperKit 本地语音识别（CoreML + Apple Neural Engine）
- OpenAI API 后处理（去填充词、自我纠正、自动标点）
- 结果输出到剪贴板

## 技术栈

- SwiftUI + MenuBarExtra
- WhisperKit v0.16.0
- KeyboardShortcuts
- AVAudioEngine
- OpenAI API (GPT-4o-mini)
