import AppKit

/// Esconde as janelas do app de capturas e compartilhamento de tela (Zoom, Meet, Teams, screenshots).
/// Usa NSWindow.sharingType = .none em toda janela do app, inclusive as que aparecem depois.
@MainActor
enum ScreenPrivacy {
    static var hidden: Bool {
        get { UserDefaults.standard.object(forKey: "hideFromSharing") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "hideFromSharing"); applyAll() }
    }

    private static var observers: [NSObjectProtocol] = []

    /// Chame uma vez no começo do app.
    static func install() {
        guard observers.isEmpty else { return }
        let nc = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didUpdateNotification,
                     NSWindow.didChangeOcclusionStateNotification] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let w = note.object as? NSWindow else { return }
                MainActor.assumeIsolated { apply(w) }
            })
        }
        applyAll()
    }

    static func apply(_ w: NSWindow) {
        let want: NSWindow.SharingType = hidden ? .none : .readOnly
        if w.sharingType != want { w.sharingType = want }
    }

    static func applyAll() { NSApp.windows.forEach(apply) }
}
