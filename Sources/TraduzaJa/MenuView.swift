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

            Text("Selecione um texto e aperte ⌘⇧⌥↩")
                .font(.callout).foregroundStyle(.secondary)

            Picker("Traduzir para", selection: $model.targetCode) {
                ForEach(Language.all) { Text($0.label).tag($0.code) }
            }
            Picker("Modelo", selection: $model.claudeModel) {
                Text("Haiku (rápido)").tag("haiku")
                Text("Sonnet").tag("sonnet")
                Text("Opus").tag("opus")
            }

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

            Divider()
            HStack {
                Button("Traduzir clipboard") { Task { await model.translateClipboard() } }
                Spacer()
                Button("Sair") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { model.trusted = Selection.trusted }
    }
}
