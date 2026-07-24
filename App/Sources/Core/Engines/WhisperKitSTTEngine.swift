// Parlo — STT 오픈소스 경로: WhisperKit (MIT, on-device Whisper — PRD Q6).
//
// 활성화 방법:
//   1) Package.swift 의 WhisperKit dependency 주석 해제 후 `swift package resolve`.
//   2) 아래 코드가 자동 컴파일됨(canImport(WhisperKit)).
//   3) EngineFactory 에서 기본 STT 를 WhisperKitSTTEngine 으로 교체.
//
// 기본 빌드/시험 루프는 네이티브 SystemSpeechSTTEngine 을 쓴다(헤드리스 환경은
// Whisper 모델 다운로드·Neural Engine 실행 불가 → 실기기 검증 대상, PRD "실기기 필수").
#if canImport(WhisperKit)
import Foundation
import AVFoundation
import WhisperKit

@MainActor
final class WhisperKitSTTEngine: STTEngine {
    private let modelName: String
    private var pipe: WhisperKit?
    private let audioEngine = AVAudioEngine()
    private var samples: [Float] = []
    private var continuation: AsyncThrowingStream<STTResult, Error>.Continuation?

    init(model: String = "base") { self.modelName = model }

    func requestAuthorization() async throws {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else { throw EngineError.unauthorized }
    }

    func startTranscribing(language: Language) throws -> AsyncThrowingStream<STTResult, Error> {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
        } catch { throw EngineError.audioSessionFailed }

        samples.removeAll()
        let input = audioEngine.inputNode
        // Whisper 는 16kHz mono float. 실제 구현은 AVAudioConverter 로 리샘플 필요.
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let ch = buffer.floatChannelData else { return }
            let frames = Int(buffer.frameLength)
            let slice = Array(UnsafeBufferPointer(start: ch[0], count: frames))
            Task { @MainActor in self?.samples.append(contentsOf: slice) }
        }
        audioEngine.prepare()
        try audioEngine.start()

        return AsyncThrowingStream { continuation in
            self.continuation = continuation
        }
    }

    func stopTranscribing() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        try? AVAudioSession.sharedInstance().setActive(false)
        let captured = samples
        let cont = continuation
        Task { @MainActor in
            do {
                if pipe == nil { pipe = try await WhisperKit(WhisperKitConfig(model: modelName)) }
                let results = try await pipe?.transcribe(audioArray: captured) ?? []
                let text = results.map(\.text).joined(separator: " ")
                cont?.yield(STTResult(text: text, isFinal: true))
                cont?.finish()
            } catch {
                cont?.finish(throwing: EngineError.recognitionFailed(error.localizedDescription))
            }
        }
    }
}
#endif
