import XCTest
@testable import TraduzaCore

final class HistoryTests: XCTestCase {
    let a = Mistake(wrong: "I has", right: "I have", why: "verbo")
    let b = Mistake(wrong: "buyed", right: "bought", why: "irregular")

    func testLearnDedupesAndBumps() {
        var h = History()
        h.learn([a, b])
        h.learn([a])
        XCTAssertEqual(h.lessons.map(\.id), [a.id, b.id])
        XCTAssertEqual(h.lessons[0].misses, 1)
    }

    func testReviewQueueHardestFirst() {
        var h = History()
        h.learn([a, b])
        h.review(b.id, gotIt: false)
        h.review(a.id, gotIt: true)
        XCTAssertEqual(h.reviewQueue().first?.id, b.id)
    }

    func testSaveLoadRoundTrip() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("traduza-hist-\(UUID()).json")
        var h = History()
        h.learn([a])
        h.add(HistoryEntry(kind: "tradução", original: "oi", result: "hi"))
        h.save(to: url)
        let back = History.load(from: url)
        XCTAssertEqual(back.lessons.first?.mistake, a)
        XCTAssertEqual(back.entries.first?.result, "hi")
    }

    func testLiveRewriteAndExplain() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TRADUZA_LIVE"] == "1")
        let t = Translator()
        let formal = try await t.rewrite("hey can u send me the file asap", tone: .formal)
        print("FORMAL:", formal)
        XCTAssertFalse(formal.lowercased().contains(" u "))
        let exp = try await t.explain("It's raining cats and dogs", in: Language.find("pt")!)
        print("EXPLAIN:", exp)
        XCTAssertTrue(exp.lowercased().contains("chov"), exp)
    }
}
