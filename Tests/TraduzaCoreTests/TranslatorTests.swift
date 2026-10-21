import XCTest
@testable import TraduzaCore

final class TranslatorTests: XCTestCase {
    func testSystemLanguage() {
        XCTAssertEqual(Language.system(preferred: ["pt-BR", "en-US"]).code, "pt")
        XCTAssertEqual(Language.system(preferred: ["xx", "ja_JP"]).code, "ja")
        XCTAssertEqual(Language.system(preferred: ["xx"]).code, "en")
    }

    func testArgumentsDisableTools() {
        let args = Translator(model: "haiku", claudePath: "/x").arguments(systemPrompt: "s")
        XCTAssertEqual(args.first, "-p")
        XCTAssertTrue(args.contains("--no-session-persistence"))
        XCTAssertEqual(args[args.firstIndex(of: "--tools")! + 1], "")
    }

    func testMissingClaude() async {
        let t = Translator(claudePath: nil)
        do {
            _ = try await t.translate("oi", to: Language.find("en")!, fallback: Language.find("pt")!)
            XCTFail("devia falhar")
        } catch {
            XCTAssertTrue(error is TranslatorError)
        }
    }

    /// Chama o claude de verdade. Rode com TRADUZA_LIVE=1 swift test
    func testLiveTranslation() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TRADUZA_LIVE"] == "1")
        let out = try await Translator().translate("Good morning!", to: Language.find("pt")!, fallback: Language.find("en")!)
        XCTAssertTrue(out.lowercased().contains("bom dia"), out)
    }
}
