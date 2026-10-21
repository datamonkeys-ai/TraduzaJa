import Carbon.HIToolbox
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
    /// ⌃⇧T: inglês → este idioma; este idioma → inglês
    @AppStorage("target") var targetCode = "pt"
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

    private var hotKeys: [HotKey] = []

    var target: Language { Language.find(targetCode) ?? Language.system() }
    /// Se o texto já está no idioma alvo, vai para cá.
    var fallback: Language { target.code == "en" ? Language.find("pt")! : Language.find("en")! }

    init() {
        hotKeys = [
            HotKey(id: 1, keyCode: kVK_ANSI_T) { [weak self] in Task { await self?.translateSelection() } },
            HotKey(id: 2, keyCode: kVK_ANSI_G) { [weak self] in Task { await self?.correctLine() } },
        ]
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

    /// ⌃⇧G: corrige a gramática da seleção, ou da linha do cursor se não tiver seleção.
    func correctLine() async {
        log.info("corrigir (busy=\(self.busy))")
        guard !busy else { return }
        trusted = Selection.trusted
        guard trusted else { Selection.askForPermission(); return }
        guard let text = await Selection.copyOrSelectLine(), !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            log.info("nada copiado"); NSSound.beep(); return
        }
        busy = true; error = nil
        defer { busy = false }
        do {
            let t = try await Translator(model: claudeModel).correct(text, explainIn: target)
            log.info("corrigido, \(t.mistakes.count) erros")
            learn(t.mistakes)
            // Mantém a quebra de linha se a seleção da linha pegou o \n
            let fixed = text.hasSuffix("\n") && !t.translation.hasSuffix("\n") ? t.translation + "\n" : t.translation
            if fixed != text { Selection.paste(fixed) }
            last = (text, t.translation)
        } catch {
            self.error = error.localizedDescription
            NSSound.beep()
        }
    }

    private func learn(_ mistakes: [Mistake]) {
        guard !mistakes.isEmpty else { return }
        lessons = Array((mistakes + lessons.filter { !mistakes.contains($0) }).prefix(30))
        unseen += mistakes.count
        if showLessons { LessonPanel.shared.show(mistakes) }
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
            learn(t.mistakes)
            return t.translation
        } catch {
            self.error = error.localizedDescription
            NSSound.beep()
            return nil
        }
    }
}
