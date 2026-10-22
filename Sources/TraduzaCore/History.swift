import Foundation

/// Um erro guardado para revisar depois.
public struct Lesson: Codable, Hashable, Identifiable, Sendable {
    public var mistake: Mistake
    public var date: Date
    public var hits = 0      // acertou na revisão
    public var misses = 0    // errou na revisão
    public var id: String { mistake.id }

    public init(mistake: Mistake, date: Date = Date()) {
        self.mistake = mistake; self.date = date
    }

    /// Prioridade de revisão: mais erros e menos acertos primeiro.
    public var weight: Int { 1 + misses * 2 - hits }
}

public struct HistoryEntry: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var kind: String      // "tradução", "correção", "formal", ...
    public var original: String
    public var result: String
    public var date = Date()

    public init(kind: String, original: String, result: String) {
        self.kind = kind; self.original = original; self.result = result
    }
}

/// Histórico salvo em disco (~/Library/Application Support/TraduzaJa/history.json).
public struct History: Codable, Sendable {
    public var lessons: [Lesson] = []
    public var entries: [HistoryEntry] = []

    public static let maxLessons = 500
    public static let maxEntries = 200

    public init() {}

    public static var defaultURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TraduzaJa", isDirectory: true)
        return dir.appendingPathComponent("history.json")
    }

    public static func load(from url: URL = defaultURL) -> History {
        guard let data = try? Data(contentsOf: url) else { return History() }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return (try? d.decode(History.self, from: data)) ?? History()
    }

    public func save(to url: URL = defaultURL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; e.outputFormatting = .prettyPrinted
        try? e.encode(self).write(to: url, options: .atomic)
    }

    /// Adiciona erros novos no topo; o mesmo erro repetido sobe e conta como mais uma falha.
    public mutating func learn(_ mistakes: [Mistake]) {
        for m in mistakes.reversed() {
            if let i = lessons.firstIndex(where: { $0.id == m.id }) {
                var l = lessons.remove(at: i)
                l.misses += 1; l.date = Date(); l.mistake = m
                lessons.insert(l, at: 0)
            } else {
                lessons.insert(Lesson(mistake: m), at: 0)
            }
        }
        if lessons.count > Self.maxLessons { lessons.removeLast(lessons.count - Self.maxLessons) }
    }

    public mutating func add(_ entry: HistoryEntry) {
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries { entries.removeLast(entries.count - Self.maxEntries) }
    }

    public mutating func review(_ id: String, gotIt: Bool) {
        guard let i = lessons.firstIndex(where: { $0.id == id }) else { return }
        if gotIt { lessons[i].hits += 1 } else { lessons[i].misses += 1 }
    }

    /// Fila de revisão: os mais difíceis primeiro, até `limit`.
    public func reviewQueue(limit: Int = 20) -> [Lesson] {
        Array(lessons.sorted { $0.weight > $1.weight }.prefix(limit))
    }
}
