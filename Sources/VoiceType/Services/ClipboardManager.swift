import AppKit
import CoreGraphics

struct ClipboardManager {
    func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Writes `text` to clipboard, sends ⌘V, then restores the previous clipboard
    /// contents after a short delay so the user's existing clipboard is preserved.
    func pasteAndRestore(_ text: String) async {
        guard AXIsProcessTrusted() else { return }

        let pasteboard = NSPasteboard.general

        // Snapshot all existing pasteboard items (all data types)
        let snapshot: [[NSPasteboard.PasteboardType: Data]] = (pasteboard.pasteboardItems ?? []).map { item in
            var types: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    types[type] = data
                }
            }
            return types
        }

        // Write transcription and simulate ⌘V
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        sendCmdV()

        // Wait for the receiving app to process the paste event before restoring
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Restore previous clipboard contents
        pasteboard.clearContents()
        let restoredItems = snapshot.map { typeMap -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in typeMap {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }

    func paste() {
        guard AXIsProcessTrusted() else { return }
        sendCmdV()
    }

    private func sendCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
