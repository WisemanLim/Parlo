// Parlo — TTS: AVSpeechSynthesizer (네이티브·온디바이스, PRD Q3).
// 확장: TTSEngine 프로토콜 뒤 → Piper 등 오픈소스로 교체 가능.
import AVFoundation

@MainActor
final class SystemTTSEngine: NSObject, TTSEngine {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: Language) async {
        guard !text.isEmpty else { return }
        // 재생 전 오디오 세션을 재생 모드로.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.localeIdentifier)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.continuation = cont
            self.synthesizer.speak(utterance)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        finish()
    }

    private func finish() {
        continuation?.resume()
        continuation = nil
    }
}

extension SystemTTSEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finish() }
    }
}
