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
        let before = pb.changeCount
        press(key: 8) // C
        for _ in 0..<20 { // até ~400 ms
            try? await Task.sleep(for: .milliseconds(20))
            if pb.changeCount != before { return pb.string(forType: .string) }
        }
        return nil
    }

    static func paste(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        press(key: 9) // V
    }

    private static func press(key: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        // Solta ⇧⌥ que ainda estão apertados do atalho, senão vira ⌘⇧⌥C
        src?.setLocalEventsFilterDuringSuppressionState([.permitLocalMouseEvents, .permitSystemDefinedEvents],
                                                        state: .eventSuppressionStateSuppressionInterval)
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: down)
            e?.flags = .maskCommand
            e?.post(tap: .cghidEventTap)
        }
    }
}
