// Parlo — MT: Apple Translation 프레임워크 (네이티브·온디바이스, iOS 18+, PRD Q2).
//
// TranslationSession 은 non-Sendable + `.translationTask` 로만 획득된다. 세션을 엔진에
// 저장해 나중에 쓰면 Swift 6 격리 위반 → **요청 채널** 패턴 사용:
//   - engine.translate() 는 요청을 스트림에 넣고 응답을 await.
//   - 뷰의 `.translationTask` 클로저가 세션을 로컬로 쥔 채 요청을 소비·응답.
// 확장: TranslationEngine 프로토콜 뒤 → NLLB/Argos 오픈소스로 교체 가능.
import Foundation

/// 번역 요청 1건. 뷰의 translationTask 루프가 처리해 continuation 으로 응답.
struct TranslationRequest: Sendable {
    let text: String
    let continuation: CheckedContinuation<String, Error>
}

@MainActor
final class AppleTranslationEngine: TranslationEngine {
    let requests: AsyncStream<TranslationRequest>
    private let sink: AsyncStream<TranslationRequest>.Continuation

    init() {
        (requests, sink) = AsyncStream.makeStream(of: TranslationRequest.self)
    }

    func prepare(from: Language, to: Language) async throws {
        // 언어팩 준비는 뷰의 `.translationTask { session in session.prepareTranslation() }` 담당.
    }

    /// 번역 최대 대기(초). 초과 시 자동 취소 → UI 프리즈 방지(언어팩 다운로드 지연 등).
    private let timeout: Double = 10

    func translate(_ text: String, from: Language, to: Language) async throws -> String {
        guard !text.isEmpty else { return "" }
        // Sendable 한 sink 만 캡처(self/MainActor 반출 회피). 번역 요청과 타임아웃을 경쟁.
        let sink = self.sink
        let timeoutNs = UInt64(timeout * 1_000_000_000)
        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (c: CheckedContinuation<String, Error>) in
                    sink.yield(TranslationRequest(text: text, continuation: c))
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNs)
                throw EngineError.timeout
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw EngineError.timeout }
            return first
        }
    }
}
