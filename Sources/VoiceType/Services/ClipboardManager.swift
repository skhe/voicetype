import AppKit
import CoreGraphics

struct ClipboardManager {
    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func paste() {
        guard AXIsProcessTrusted() else { return }
        let src = CGEventSource(stateID: .hidSystemState)

        // Cmd+V key down
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)

        // Cmd+V key up
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
