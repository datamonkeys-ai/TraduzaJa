import SwiftUI
import os

let log = Logger(subsystem: "com.louisperner.traduzaja", category: "app")

@main
struct TraduzaJaApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(model)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: model.busy ? "ellipsis.bubble.fill" : "character.bubble")
                if model.unseen > 0 { Text("\(model.unseen)") }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppModel: ObservableObject {
    @AppStorage("target") var targetCode = Language.system().code
    @AppStorage("model") var claudeModel = "haiku"
    @AppStorage("showLessons") var showLessons = true
    @Published var busy = false
    @Published var last: (original: String, translated: String)?
    /// Erros das últimas traduções, mais recente primeiro.
    @Published var lessons: [Mistake] = []
    /// Contador no ícone; zera quando abre o menu.
    @Published var unseen = 0
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
        log.info("atalho (busy=\(self.busy))")
        guard !busy else { return }
        trusted = Selection.trusted
        guard trusted else { Selection.askForPermission(); return }
        guard let text = await Selection.copy(), !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            log.info("nada copiado"); NSSound.beep(); return
        }
        log.info("copiado \(text.count) chars")
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
            let t = try await Translator(model: claudeModel).translate(text, to: target, fallback: fallback, explainIn: target)
            last = (text, t.translation)
            log.info("traduzido, \(t.mistakes.count) erros")
            if !t.mistakes.isEmpty {
                lessons = Array((t.mistakes + lessons.filter { !t.mistakes.contains($0) }).prefix(30))
                unseen += t.mistakes.count
                if showLessons { LessonPanel.shared.show(t.mistakes) }
            }
            return t.translation
        } catch {
            self.error = error.localizedDescription
            NSSound.beep()
            return nil
        }
    }
}
