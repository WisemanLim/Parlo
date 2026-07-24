// Parlo — 통역 파이프라인 오케스트레이터. VAD→STT→MT→TTS 를 조율하고 대화 로그를 관리.
// 엔진은 프로토콜로 주입 → mock 으로 단위 시험 가능.
import Foundation
import Observation
import Translation

@MainActor
@Observable
final class TranslationViewModel {
    enum State: Equatable { case idle, listening, translating, speaking }

    // 주입 엔진
    private let stt: STTEngine
    private let mt: TranslationEngine
    private let tts: TTSEngine
    /// Apple Translation 은 세션 주입이 필요 → 뷰(.translationTask)와 연결.
    private var appleMT: AppleTranslationEngine? { mt as? AppleTranslationEngine }

    // 관측 상태
    private(set) var state: State = .idle
    private(set) var partialTranscript: String = ""
    private(set) var latestTranslation: String = ""
    private(set) var utterances: [Utterance] = []
    var errorMessage: String?

    /// 통역 방향(source→target). 스왑/양방향 토글로 변경.
    var pair: LanguagePair
    /// 양방향 대화 모드(P1): 발화 1건 처리 후 방향 자동 반전.
    var isBidirectional: Bool = false

    private var listenTask: Task<Void, Never>?
    private var silenceTask: Task<Void, Never>?

    init(
        stt: STTEngine,
        mt: TranslationEngine,
        tts: TTSEngine,
        pair: LanguagePair = .koToEn
    ) {
        self.stt = stt
        self.mt = mt
        self.tts = tts
        self.pair = pair
    }

    @MainActor
    convenience init(pair: LanguagePair = .koToEn) {
        self.init(
            stt: EngineFactory.makeSTT(),
            mt: EngineFactory.makeTranslation(),
            tts: EngineFactory.makeTTS(),
            pair: pair
        )
    }

    // MARK: - Apple Translation 세션 연동 (뷰에서 호출)

    /// 뷰의 `.translationTask` 가 쓸 설정. 언어쌍 기반.
    var translationConfiguration: TranslationSession.Configuration {
        TranslationSession.Configuration(
            source: Locale.Language(identifier: pair.source.localeIdentifier),
            target: Locale.Language(identifier: pair.target.localeIdentifier)
        )
    }

    /// 뷰의 `.translationTask` 가 소비할 번역 요청 스트림(Apple Translation 사용 시).
    var translationRequests: AsyncStream<TranslationRequest>? {
        appleMT?.requests
    }

    // MARK: - 언어 제어

    func swapLanguages() {
        pair = pair.reversed
    }

    func setPair(_ newPair: LanguagePair) {
        pair = newPair
    }

    func clearHistory() {
        utterances.removeAll()
    }

    // MARK: - 통역 제어

    func toggleListening() {
        switch state {
        case .idle: startListening()
        default: stopListening()
        }
    }

    func startListening() {
        guard state == .idle else { return }
        errorMessage = nil
        partialTranscript = ""
        latestTranslation = ""
        state = .listening

        listenTask = Task { [weak self] in
            guard let self else { return }
            var processed = false
            do {
                try await self.stt.requestAuthorization()
                let stream = try self.stt.startTranscribing(language: self.pair.source)
                for try await result in stream {
                    self.partialTranscript = result.text
                    if result.isFinal {
                        processed = true
                        self.cancelSilence()
                        await self.process(finalTranscript: result.text)
                        break
                    } else {
                        // 부분 결과마다 무음 타이머 재설정(0.8s 무음 → 자동 확정).
                        self.scheduleSilenceFinalize()
                    }
                }
                // 스트림이 최종 없이 종료(무음 확정/사용자 중단) → 부분 결과로 처리.
                if !processed {
                    self.cancelSilence()
                    if self.state == .listening, !self.partialTranscript.isEmpty {
                        await self.process(finalTranscript: self.partialTranscript)
                    } else if self.state == .listening {
                        self.state = .idle
                    }
                }
            } catch {
                self.cancelSilence()
                self.fail(error)
            }
        }
    }

    func stopListening() {
        cancelSilence()
        stt.stopTranscribing()   // 입력 종료 → 스트림 마무리 후 for-await 가 process 호출
    }

    /// 무음 자동 확정: 마지막 부분 결과 이후 0.8s 동안 새 결과가 없으면 입력을 닫아
    /// 최종 인식을 받고 번역·재생으로 넘어간다. 실시간 통역 체감의 핵심.
    private func scheduleSilenceFinalize() {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)   // 0.8s
            guard let self, !Task.isCancelled else { return }
            if self.state == .listening {
                self.stt.stopTranscribing()   // 입력 종료 → 스트림 종료 → process
            }
        }
    }

    private func cancelSilence() {
        silenceTask?.cancel()
        silenceTask = nil
    }

    /// 파이프라인 코어: 전사 최종본 → 번역 → 로그 적재 → 음성 재생 → (양방향 시 방향 반전).
    /// 단위 시험의 진입점. 번역 지연은 엔진의 10초 타임아웃(EngineError.timeout)으로 자동 취소.
    func process(finalTranscript text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { state = .idle; return }

        let source = pair.source
        let target = pair.target
        do {
            state = .translating
            let translated = try await mt.translate(trimmed, from: source, to: target)
            latestTranslation = translated

            utterances.append(Utterance(
                sourceLanguage: source,
                targetLanguage: target,
                transcript: trimmed,
                translation: translated
            ))

            state = .speaking
            await tts.speak(translated, language: target)

            if isBidirectional { pair = pair.reversed }
            // 전사·번역 둘 다 화면에 남긴다(다음 발화 시작 시 초기화).
            partialTranscript = trimmed
            state = .idle
        } catch {
            fail(error)   // 타임아웃 포함 모든 오류 → 에러 메시지 + idle 복구
        }
    }

    private func fail(_ error: Error) {
        if let e = error as? EngineError {
            errorMessage = Self.message(for: e)
        } else {
            errorMessage = error.localizedDescription
        }
        state = .idle
    }

    static func message(for error: EngineError) -> String {
        switch error {
        case .unauthorized: return "마이크·음성 인식 권한이 필요합니다. 설정에서 허용해 주세요."
        case .unavailable: return "이 언어의 온디바이스 모델/언어팩을 사용할 수 없습니다."
        case .audioSessionFailed: return "오디오 세션을 시작하지 못했습니다."
        case .recognitionFailed(let m): return "음성 인식 실패: \(m)"
        case .translationFailed(let m): return "번역 실패: \(m)"
        case .timeout: return "번역이 지연되어 취소했습니다. 언어팩 다운로드 상태나 네트워크를 확인해 주세요."
        }
    }
}
