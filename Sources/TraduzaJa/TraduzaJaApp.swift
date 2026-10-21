import SwiftUI

@main
struct TraduzaJaApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(model)
        } label: {
            Image(systemName: model.busy ? "ellipsis.bubble.fill" : "character.bubble")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppModel: ObservableObject {
    @AppStorage("target") var targetCode = Language.system().code
    @AppStorage("model") var claudeModel = "haiku"
    @Published var busy = false
    @Published var last: (original: String, translated: String)?
    @Published var error: String?
    @Published var trusted = Selection.trusted

    private var hotKey: HotKey?

    var target: Language { Language.find(targetCode) ?? Language.system() }
    /// Se o texto já está no idioma alvo, vai para cá.
    var fallback: Language { target.code == "en" ? Language.find("pt")! : Language.find("en")! }

    init() {
        hotKey = HotKey { [weak self] in Task { await self?.translateSelection() } }
        if !trusted { Selection.askForPermission() }
    }

    func translateSelection() async {
        guard !busy else { return }
        trusted = Selection.trusted
        guard trusted else { Selection.askForPermission(); return }
        guard let text = await Selection.copy(), !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            NSSound.beep(); return
        }
        guard let out = await translate(text) else { return }
        Selection.paste(out)
    }

    func translateClipboard() async {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty,
              let out = await translate(text) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(out, forType: .string)
    }

    private func translate(_ text: String) async -> String? {
        busy = true; error = nil
        defer { busy = false }
        do {
            let out = try await Translator(model: claudeModel).translate(text, to: target, fallback: fallback)
            last = (text, out)
            return out
        } catch {
            self.error = error.localizedDescription
            NSSound.beep()
            return nil
        }
    }
}
