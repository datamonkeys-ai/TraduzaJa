import AppKit
import ApplicationServices

/// Copia a seleção do app da frente e cola por cima, simulando ⌘C / ⌘V.
/// Precisa de Acessibilidade (Ajustes > Privacidade e Segurança > Acessibilidade).
enum Selection {
    static var trusted: Bool { AXIsProcessTrusted() }

    static func askForPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Texto selecionado, ou nil se nada mudou no clipboard.
    static func copy() async -> String? {
        let pb = NSPasteboard.general
        // Espera soltar ⌃⇧ do atalho (até ~600 ms), senão o app recebe ⌃⇧⌘C
        for _ in 0..<30 where !CGEventSource.flagsState(.combinedSessionState)
            .intersection([.maskControl, .maskShift, .maskAlternate, .maskCommand]).isEmpty {
            try? await Task.sleep(for: .milliseconds(20))
        }
        let before = pb.changeCount
        press(key: 8) // C
        for _ in 0..<40 { // até ~800 ms
            try? await Task.sleep(for: .milliseconds(20))
            if pb.changeCount != before { return pb.string(forType: .string) }
        }
        return nil
    }

    /// Seleção atual; se não houver, seleciona a linha onde está o cursor (⌘← e ⌘⇧→).
    static func copyOrSelectLine() async -> String? {
        if let text = await copy(), !text.trimmingCharacters(in: .whitespaces).isEmpty { return text }
        press(key: 123) // ←
        try? await Task.sleep(for: .milliseconds(40))
        press(key: 124, flags: [.maskCommand, .maskShift]) // →
        try? await Task.sleep(for: .milliseconds(60))
        return await copy()
    }

    static func paste(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        press(key: 9) // V
    }

    private static func press(key: CGKeyCode, flags: CGEventFlags = .maskCommand) {
        // Os modificadores do atalho já foram soltos em copy()
        let src = CGEventSource(stateID: .combinedSessionState)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: down)
            e?.flags = flags
            e?.post(tap: .cghidEventTap)
        }
    }
}
