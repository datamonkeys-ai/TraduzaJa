import SwiftUI

struct MenuView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TraduzaJa").font(.headline)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
            }

            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 2) {
                shortcut("⌃⇧T", "traduz (inglês ↔ \(model.target.label))")
                shortcut("⌃⇧G", "corrige a gramática")
                shortcut("⌃⇧F", "deixa mais formal")
                shortcut("⌃⇧C", "deixa mais casual")
                shortcut("⌃⇧E", "explica a frase")
            }
            .font(.callout).foregroundStyle(.secondary)
            Text("Sem seleção, G/F/C usam a linha do cursor.").font(.caption2).foregroundStyle(.tertiary)

            Picker("Meu idioma", selection: $model.targetCode) {
                ForEach(Language.all) { Text($0.label).tag($0.code) }
            }
            Picker("Modelo", selection: $model.claudeModel) {
                Text("Haiku (rápido)").tag("haiku")
                Text("Sonnet").tag("sonnet")
                Text("Opus").tag("opus")
            }

            Toggle("Mostrar o que errei no topo da tela", isOn: $model.showLessons)
            Toggle("Abrir quando o Mac ligar", isOn: Binding(
                get: { model.openAtLogin }, set: { model.setOpenAtLogin($0) }))

            if !model.trusted {
                Button("Liberar Acessibilidade…") { Selection.askForPermission() }
                    .foregroundStyle(.orange)
            }

            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red).lineLimit(4)
            }

            if let last = model.last {
                Divider()
                Text(last.original).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                Text(last.translated).textSelection(.enabled).lineLimit(6)
            }

            if !model.history.lessons.isEmpty {
                Divider()
                HStack {
                    Label("Para aprender (\(model.history.lessons.count))", systemImage: "graduationcap")
                        .font(.subheadline.bold())
                    Spacer()
                    Button("Revisar") { ReviewWindow.shared.show(model: model) }.font(.caption)
                    Button("Limpar") { model.clearLessons() }.buttonStyle(.link).font(.caption)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(model.history.lessons.prefix(30)) { MistakeRow(mistake: $0.mistake) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
            }

            Divider()
            HStack {
                Button("Traduzir clipboard") { Task { await model.translateClipboard() } }
                Spacer()
                Button("Sair") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { model.trusted = Selection.trusted; model.unseen = 0 }
    }

    private func shortcut(_ keys: String, _ what: String) -> some View {
        GridRow {
            Text(keys).monospaced().foregroundStyle(.primary)
            Text(what)
        }
    }
}
