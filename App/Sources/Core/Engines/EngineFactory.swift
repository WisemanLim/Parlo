// Parlo — 엔진 조립. 기본은 네이티브. 오픈소스로 교체하려면 여기만 바꾼다.
import Foundation

enum EngineFactory {
    /// 기본 STT: 네이티브 온디바이스(SFSpeechRecognizer).
    /// 오픈소스 WhisperKit 활성화 시 아래 주석을 교체.
    @MainActor static func makeSTT() -> STTEngine {
        #if canImport(WhisperKit)
        return WhisperKitSTTEngine(model: "base")
        #else
        return SystemSpeechSTTEngine()
        #endif
    }

    @MainActor static func makeTranslation() -> AppleTranslationEngine {
        AppleTranslationEngine()
    }

    @MainActor static func makeTTS() -> TTSEngine {
        SystemTTSEngine()
    }
}
