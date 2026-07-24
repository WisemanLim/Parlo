// Parlo — 파이프라인 단위 시험. mock 엔진으로 STT/MT/TTS 없이 오케스트레이션 로직 검증.
import XCTest
@testable import Parlo

// MARK: - Mocks

@MainActor
final class MockSTTEngine: STTEngine {
    var authError: Error?
    var results: [STTResult] = []
    func requestAuthorization() async throws { if let e = authError { throw e } }
    func startTranscribing(language: Language) throws -> AsyncThrowingStream<STTResult, Error> {
        let snapshot = results
        return AsyncThrowingStream { cont in
            for r in snapshot { cont.yield(r) }
            cont.finish()
        }
    }
    func stopTranscribing() {}
}

@MainActor
final class MockTranslationEngine: TranslationEngine {
    var prepared = false
    var translateError: Error?
    var handler: (String) -> String = { "T:\($0)" }
    func prepare(from: Language, to: Language) async throws { prepared = true }
    func translate(_ text: String, from: Language, to: Language) async throws -> String {
        if let e = translateError { throw e }
        return handler(text)
    }
}

@MainActor
final class MockTTSEngine: TTSEngine {
    var spoken: [(String, Language)] = []
    func speak(_ text: String, language: Language) async { spoken.append((text, language)) }
    func stop() {}
}

@MainActor
private func makeVM(
    pair: LanguagePair = .koToEn
) -> (TranslationViewModel, MockTranslationEngine, MockTTSEngine) {
    let mt = MockTranslationEngine()
    let tts = MockTTSEngine()
    let vm = TranslationViewModel(stt: MockSTTEngine(), mt: mt, tts: tts, pair: pair)
    return (vm, mt, tts)
}

// MARK: - Tests

@MainActor
final class ParloTests: XCTestCase {

    func testLanguageBasics() {
        XCTAssertEqual(Language.korean.localeIdentifier, "ko-KR")
        XCTAssertEqual(Language.english.displayName, "English")
        XCTAssertEqual(LanguagePair.koToEn.reversed, .enToKo)
    }

    func testProcessTranslatesLogsAndSpeaks() async {
        let (vm, _, tts) = makeVM()
        await vm.process(finalTranscript: "안녕하세요")

        XCTAssertEqual(vm.utterances.count, 1)
        let u = vm.utterances[0]
        XCTAssertEqual(u.transcript, "안녕하세요")
        XCTAssertEqual(u.translation, "T:안녕하세요")
        XCTAssertEqual(u.sourceLanguage, .korean)
        XCTAssertEqual(u.targetLanguage, .english)
        XCTAssertEqual(vm.latestTranslation, "T:안녕하세요")
        XCTAssertEqual(tts.spoken.count, 1)
        XCTAssertEqual(tts.spoken[0].0, "T:안녕하세요")
        XCTAssertEqual(tts.spoken[0].1, .english)
        XCTAssertEqual(vm.state, .idle)
    }

    func testEmptyTranscriptSkips() async {
        let (vm, _, tts) = makeVM()
        await vm.process(finalTranscript: "   \n ")
        XCTAssertTrue(vm.utterances.isEmpty)
        XCTAssertTrue(tts.spoken.isEmpty)
        XCTAssertEqual(vm.state, .idle)
    }

    func testBidirectionalFlipsPairAfterProcess() async {
        let (vm, _, _) = makeVM(pair: .koToEn)
        vm.isBidirectional = true
        await vm.process(finalTranscript: "안녕")
        XCTAssertEqual(vm.pair, .enToKo)   // 방향 반전
    }

    func testNonBidirectionalKeepsPair() async {
        let (vm, _, _) = makeVM(pair: .koToEn)
        vm.isBidirectional = false
        await vm.process(finalTranscript: "안녕")
        XCTAssertEqual(vm.pair, .koToEn)
    }

    func testSwapLanguages() {
        let (vm, _, _) = makeVM(pair: .koToEn)
        vm.swapLanguages()
        XCTAssertEqual(vm.pair, .enToKo)
    }

    func testTranslationFailureSetsErrorAndNoLog() async {
        let (vm, mt, tts) = makeVM()
        mt.translateError = EngineError.translationFailed("boom")
        await vm.process(finalTranscript: "안녕")
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.utterances.isEmpty)
        XCTAssertTrue(tts.spoken.isEmpty)
        XCTAssertEqual(vm.state, .idle)
    }

    func testMultipleUtterancesAccumulate() async {
        let (vm, _, _) = makeVM()
        await vm.process(finalTranscript: "하나")
        await vm.process(finalTranscript: "둘")
        XCTAssertEqual(vm.utterances.count, 2)
        XCTAssertEqual(vm.utterances.map(\.transcript), ["하나", "둘"])
    }

    func testProcessKeepsTranscriptAndTranslationVisible() async {
        let (vm, _, _) = makeVM()
        await vm.process(finalTranscript: "안녕하세요")
        // 중앙에 전사·번역 둘 다 남아야 한다.
        XCTAssertEqual(vm.partialTranscript, "안녕하세요")
        XCTAssertEqual(vm.latestTranslation, "T:안녕하세요")
    }

    func testTimeoutRecoversToIdle() async {
        let (vm, mt, tts) = makeVM()
        mt.translateError = EngineError.timeout
        await vm.process(finalTranscript: "안녕")
        XCTAssertNotNil(vm.errorMessage)          // 타임아웃 안내
        XCTAssertEqual(vm.state, .idle)            // 프리즈 없이 복구
        XCTAssertTrue(vm.utterances.isEmpty)
        XCTAssertTrue(tts.spoken.isEmpty)
    }

    func testClearHistory() async {
        let (vm, _, _) = makeVM()
        await vm.process(finalTranscript: "하나")
        XCTAssertEqual(vm.utterances.count, 1)
        vm.clearHistory()
        XCTAssertTrue(vm.utterances.isEmpty)
    }
}
