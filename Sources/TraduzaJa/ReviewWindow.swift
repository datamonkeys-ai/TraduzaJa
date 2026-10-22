import AppKit
import SwiftUI

/// Revisão tipo flashcard dos erros guardados: mostra o errado, você pensa, revela o certo.
@MainActor
final class ReviewWindow {
    static let shared = ReviewWindow()
    private var window: NSWindow?

    func show(model: AppModel) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Revisar meus erros"
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.contentView = NSHostingView(rootView: ReviewView(queue: model.history.reviewQueue())
            .environmentObject(model))
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct ReviewView: View {
    @EnvironmentObject var model: AppModel
    let queue: [Lesson]
    @State private var index = 0
    @State private var revealed = false
    @State private var score = 0

    var body: some View {
        VStack(spacing: 18) {
            if index < queue.count {
                let lesson = queue[index]
                Text("\(index + 1) de \(queue.count)").font(.caption).foregroundStyle(.secondary)
                Text("Como fica certo?").font(.headline)
                Text(lesson.mistake.wrong)
                    .font(.title2).strikethrough().foregroundStyle(.red)
                    .multilineTextAlignment(.center)

                if revealed {
                    Text(lesson.mistake.right).font(.title2.bold()).foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                    Text(lesson.mistake.why).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        Button("Errei") { answer(lesson, gotIt: false) }.keyboardShortcut("1", modifiers: [])
                        Button("Acertei") { answer(lesson, gotIt: true) }.keyboardShortcut("2", modifiers: [])
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    Button("Mostrar resposta") { revealed = true }
                        .keyboardShortcut(.space, modifiers: []).buttonStyle(.borderedProminent)
                }
            } else {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(.green)
                Text(queue.isEmpty ? "Nada para revisar ainda." : "Acertou \(score) de \(queue.count)!")
                    .font(.title3)
            }
        }
        .padding(28)
        .frame(width: 460, height: 340)
    }

    private func answer(_ lesson: Lesson, gotIt: Bool) {
        model.review(lesson.id, gotIt: gotIt)
        if gotIt { score += 1 }
        revealed = false
        index += 1
    }
}
