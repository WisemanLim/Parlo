// Parlo — 엔진 추상화 (핵심 설계). STT/MT/TTS 각각 프로토콜 뒤에 둬서
// 1차 네이티브 구현 → 이후 오픈소스(WhisperKit/NLLB/Piper) 무중단 교체 (PRD §7).
import Foundation

enum EngineError: Error, Equatable {
    case unauthorized          // 권한 거부 (마이크/음성인식)
    case unavailable           // 언어팩/모델 미설치, OS 미지원
    case audioSessionFailed
    case recognitionFailed(String)
    case translationFailed(String)
    case timeout               // 번역 지연(언어팩 다운로드/네트워크 등) 자동 취소
}

/// 음성 → 텍스트. 온디바이스. 부분 결과를 스트림으로 흘리고 최종 결과로 종료.
@MainActor
protocol STTEngine: AnyObject {
    /// 인식 권한 요청. 거부 시 throw.
    func requestAuthorization() async throws

    /// 마이크 캡처 시작. `AsyncThrowingStream` 으로 부분/최종 전사를 방출.
    /// 스트림 완료(finish) = 발화 종료.
    func startTranscribing(language: Language) throws -> AsyncThrowingStream<STTResult, Error>

    /// 캡처 중단(사용자가 마이크 off). 진행 중 스트림을 최종 결과로 마감.
    func stopTranscribing()
}

struct STTResult: Equatable, Sendable {
    let text: String
    let isFinal: Bool
}

/// 텍스트 번역. 온디바이스.
@MainActor
protocol TranslationEngine: AnyObject {
    /// 언어쌍 준비(언어팩 확인/다운로드 유도). 미지원 시 throw.
    func prepare(from: Language, to: Language) async throws
    func translate(_ text: String, from: Language, to: Language) async throws -> String
}

/// 텍스트 → 음성. 온디바이스.
@MainActor
protocol TTSEngine: AnyObject {
    func speak(_ text: String, language: Language) async
    func stop()
}
