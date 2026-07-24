// Parlo — STT 기본 구현: SFSpeechRecognizer (네이티브·온디바이스).
// requiresOnDeviceRecognition=true 로 오프라인 강제(음성 외부 전송 0, PRD 비기능 요구).
// 오픈소스 대안은 WhisperKitSTTEngine (Q6) — canImport 시 교체.
import Foundation
import Speech
import AVFoundation

@MainActor
final class SystemSpeechSTTEngine: STTEngine {
    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestAuthorization() async throws {
        // 권한 콜백은 TCC 가 백그라운드 큐에서 호출한다. 완료 클로저가 @MainActor 로 추론되면
        // Swift 6 가 non-main 큐에서 main-actor 검사를 수행해 EXC_BREAKPOINT 로 크래시.
        // → 완료 클로저를 @Sendable(nonisolated)로 만들어 어느 큐에서든 안전하게 실행.
        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                cont.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { throw EngineError.unauthorized }

        let micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { @Sendable granted in
                cont.resume(returning: granted)
            }
        }
        guard micGranted else { throw EngineError.unauthorized }
    }

    func startTranscribing(language: Language) throws -> AsyncThrowingStream<STTResult, Error> {
        // 재진입 방어: 이전 세션 잔여물(탭/엔진/태스크) 정리 후 시작.
        teardown()

        let recognizer = SFSpeechRecognizer(locale: language.locale)
        guard let recognizer, recognizer.isAvailable else { throw EngineError.unavailable }
        self.recognizer = recognizer

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw EngineError.audioSessionFailed
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true   // 오프라인 강제
        }
        self.request = request

        let inputNode = audioEngine.inputNode
        // 하드웨어 입력 포맷. 세션 활성 후에도 무효(0Hz/0ch)일 수 있어 반드시 검증 —
        // 무효 포맷으로 installTap 하면 try 로 못 잡는 치명 예외(crash)가 난다.
        let format = inputNode.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            teardown()
            throw EngineError.audioSessionFailed
        }
        // 탭 콜백은 오디오 실시간 스레드에서 호출된다. @MainActor 로 추론되면 Swift 6 가
        // non-main 스레드에서 main-actor 검사를 수행해 EXC_BREAKPOINT 크래시.
        // → @Sendable(nonisolated) 클로저 + nonisolated(unsafe) 캡처(append 는 스레드 안전).
        nonisolated(unsafe) let tapRequest = request
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
            tapRequest.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            teardown()
            throw EngineError.audioSessionFailed
        }

        return AsyncThrowingStream { continuation in
            self.task = recognizer.recognitionTask(with: request) { @Sendable result, error in
                if let result {
                    let r = STTResult(text: result.bestTranscription.formattedString, isFinal: result.isFinal)
                    continuation.yield(r)
                    if result.isFinal { continuation.finish() }
                }
                if let error {
                    continuation.finish(throwing: EngineError.recognitionFailed(error.localizedDescription))
                }
            }
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in self.teardown() }
            }
        }
    }

    func stopTranscribing() {
        // 그레이스풀 종료: 오디오 캡처만 멈추고 입력을 닫아 최종 인식 결과를 받는다.
        // 실제 정리(task 취소·세션 비활성)는 스트림 종료(onTermination)에서 수행.
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
    }

    private func teardown() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        // 탭은 running 여부와 무관하게 항상 제거(잔여 탭 중복 설치 시 크래시 방지). no-op 안전.
        audioEngine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
