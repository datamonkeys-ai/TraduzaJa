import AppKit
import SwiftUI

/// Cartão flutuante no topo da tela com os erros do texto original.
/// Não rouba o foco do app em que você está escrevendo.
@MainActor
final class LessonPanel {
    static let shared = LessonPanel()

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func show(_ mistakes: [Mistake], seconds: Double = 12) {
        present(LessonCard(mistakes: mistakes, onClose: close, onHover: hover), seconds: seconds)
    }

    /// Cartão de texto livre (explicação da frase).
    func showText(title: String, body: String, seconds: Double = 20) {
        present(TextCard(title: title, text: body, onClose: close, onHover: hover), seconds: seconds)
    }

    private var close: () -> Void { { [weak self] in self?.hide() } }
    private var hover: (Bool) -> Void {
        { [weak self] inside in if inside { self?.hideTask?.cancel() } else { self?.scheduleHide(after: 4) } }
    }

    private func present<V: View>(_ view: V, seconds: Double) {
        hide()
        let host = NSHostingView(rootView: view)
        host.frame.size = host.fittingSize

        let p = NSPanel(contentRect: host.frame, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.contentView = host
        p.isFloatingPanel = true
        p.level = .statusBar
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: f.midX - host.frame.width / 2, y: f.maxY - host.frame.height - 8))
        }
        ScreenPrivacy.apply(p)
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.2; p.animator().alphaValue = 1 }
        panel = p
        scheduleHide(after: seconds)
    }

    func hide() {
        hideTask?.cancel()
        panel?.orderOut(nil)
        panel = nil
    }

    private func scheduleHide(after seconds: Double) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }
}

struct LessonCard: View {
    let mistakes: [Mistake]
    var onClose: () -> Void
    var onHover: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(mistakes.count == 1 ? "1 coisa para aprender" : "\(mistakes.count) coisas para aprender",
                      systemImage: "graduationcap.fill")
                    .font(.headline)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            ForEach(mistakes.prefix(5)) { MistakeRow(mistake: $0) }
            if mistakes.count > 5 {
                Text("+\(mistakes.count - 5) no menu do TraduzaJa").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onHover(perform: onHover)
    }
}

struct TextCard: View {
    let title: String
    let text: String
    var onClose: () -> Void
    var onHover: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: "lightbulb.fill").font(.headline).lineLimit(2)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            Text(text).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }
        .padding(14)
        .frame(width: 440)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onHover(perform: onHover)
    }
}

struct MistakeRow: View {
    let mistake: Mistake

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(mistake.wrong).strikethrough().foregroundStyle(.red)
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                Text(mistake.right).bold().foregroundStyle(.green)
            }
            Text(mistake.why).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .textSelection(.enabled)
    }
}
