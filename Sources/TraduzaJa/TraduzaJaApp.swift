import Carbon.HIToolbox
import ServiceManagement
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
    /// Erros e traduções, salvos em disco entre sessões.
    @Published var history = History.load() { didSet { history.save() } }
    /// Contador no ícone; zera quando abre o menu.
    @Published var unseen = 0
    @Published var error: String?
    @Published var trusted = Selection.trusted
    @Published var openAtLogin = SMAppService.mainApp.status == .enabled

    private var hotKeys: [HotKey] = []

    var target: Language { Language.find(targetCode) ?? Language.system() }
    /// Se o texto já está no idioma alvo, vai para cá.
    var fallback: Language { target.code == "en" ? Language.find("pt")! : Language.find("en")! }
    var translator: Translator { Translator(model: claudeModel) }

    init() {
        hotKeys = [
            HotKey(id: 1, keyCode: kVK_ANSI_T) { [weak self] in Task { await self?.translateSelection() } },
            HotKey(id: 2, keyCode: kVK_ANSI_G) { [weak self] in Task { await self?.correctLine() } },
            HotKey(id: 3, keyCode: kVK_ANSI_F) { [weak self] in Task { await self?.rewriteSelection(.formal) } },
            HotKey(id: 4, keyCode: kVK_ANSI_C) { [weak self] in Task { await self?.rewriteSelection(.casual) } },
            HotKey(id: 5, keyCode: kVK_ANSI_E) { [weak self] in Task { await self?.explainSelection() } },
        ]
        if !trusted { Selection.askForPermission() }
    }

    // MARK: - Atalhos

    /// ⌃⇧T
    func translateSelection() async {
        guard let text = await grab(selectLine: false) else { return }
        guard let out = await translate(text) else { return }
        Selection.paste(out)
    }

    /// ⌃⇧G: corrige a gramática da seleção, ou da linha do cursor se não tiver seleção.
    func correctLine() async {
        guard let text = await grab(selectLine: true) else { return }
        await work {
            let t = try await self.translator.correct(text, explainIn: self.target)
            log.info("corrigido, \(t.mistakes.count) erros")
            self.learn(t.mistakes)
            // Mantém a quebra de linha se a seleção da linha pegou o \n
            let fixed = text.hasSuffix("\n") && !t.translation.hasSuffix("\n") ? t.translation + "\n" : t.translation
            if fixed != text { Selection.paste(fixed) }
            self.record("correção", text, t.translation)
        }
    }

    /// ⌃⇧F / ⌃⇧C: reescreve a seleção (ou a linha) em tom formal ou casual.
    func rewriteSelection(_ tone: Translator.Tone) async {
        guard let text = await grab(selectLine: true) else { return }
        await work {
            let out = try await self.translator.rewrite(text, tone: tone)
            let fixed = text.hasSuffix("\n") && !out.hasSuffix("\n") ? out + "\n" : out
            Selection.paste(fixed)
            self.record(tone == .formal ? "formal" : "casual", text, out)
        }
    }

    /// ⌃⇧E: explica a seleção num cartão, sem trocar o texto.
    func explainSelection() async {
        guard let text = await grab(selectLine: false) else { return }
        await work {
            let out = try await self.translator.explain(text, in: self.target)
            LessonPanel.shared.showText(title: "“\(text.prefix(60))”", body: out, seconds: 25)
            self.record("explicação", text, out)
        }
    }

    func translateClipboard() async {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty,
              let out = await translate(text) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(out, forType: .string)
    }

    // MARK: - Opções

    func setOpenAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            self.error = "Abrir no login: \(error.localizedDescription)"
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
    }

    func clearLessons() { history.lessons = [] }

    func review(_ id: String, gotIt: Bool) { history.review(id, gotIt: gotIt) }

    // MARK: - Interno

    /// Seleção atual (ou a linha do cursor). nil se não deu para copiar.
    private func grab(selectLine: Bool) async -> String? {
        guard !busy else { return nil }
        trusted = Selection.trusted
        guard trusted else { Selection.askForPermission(); return nil }
        let text = selectLine ? await Selection.copyOrSelectLine() : await Selection.copy()
        guard let text, !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            log.info("nada copiado"); NSSound.beep(); return nil
        }
        return text
    }

    private func work(_ body: @escaping () async throws -> Void) async {
        busy = true; error = nil
        defer { busy = false }
        do { try await body() } catch {
            self.error = error.localizedDescription
            NSSound.beep()
        }
    }

    private func record(_ kind: String, _ original: String, _ result: String) {
        last = (original, result)
        history.add(HistoryEntry(kind: kind, original: original, result: result))
    }

    private func learn(_ mistakes: [Mistake]) {
        guard !mistakes.isEmpty else { return }
        history.learn(mistakes)
        unseen += mistakes.count
        if showLessons { LessonPanel.shared.show(mistakes) }
    }

    private func translate(_ text: String) async -> String? {
        var out: String?
        await work {
            let t = try await self.translator.translate(text, to: self.target, fallback: self.fallback, explainIn: self.target)
            log.info("traduzido, \(t.mistakes.count) erros")
            self.learn(t.mistakes)
            self.record("tradução", text, t.translation)
            out = t.translation
        }
        return out
    }
}
