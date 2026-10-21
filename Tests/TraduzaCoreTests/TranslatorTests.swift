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

    func testParseJSONWithFences() {
        let raw = "```json\n{\"translation\": \" Olá \", \"mistakes\": [{\"wrong\": \"I has\", \"right\": \"I have\", \"why\": \"verbo\"}, {\"wrong\": \"x\", \"right\": \"x\", \"why\": \"\"}]}\n```"
        let t = Translation.parse(raw)
        XCTAssertEqual(t.translation, "Olá")
        XCTAssertEqual(t.mistakes, [Mistake(wrong: "I has", right: "I have", why: "verbo")])
    }

    func testParsePlainText() {
        XCTAssertEqual(Translation.parse("  Bom dia \n"), Translation(translation: "Bom dia"))
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
        let pt = Language.find("pt")!
        let out = try await Translator().translate("Good morning! I has two cat.", to: pt, fallback: Language.find("en")!, explainIn: pt)
        XCTAssertTrue(out.translation.lowercased().contains("bom dia"), out.translation)
        XCTAssertFalse(out.mistakes.isEmpty, "devia achar 'I has' / 'two cat'")
        print(out)
    }

    func testLiveCorrection() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TRADUZA_LIVE"] == "1")
        let out = try await Translator().correct("She dont like apples.", explainIn: Language.find("pt")!)
        XCTAssertTrue(out.translation.contains("doesn't") || out.translation.contains("does not"), out.translation)
        XCTAssertFalse(out.mistakes.isEmpty)
        print(out)
    }
}
