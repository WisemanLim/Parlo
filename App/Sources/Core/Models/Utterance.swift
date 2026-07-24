// Parlo — 대화 로그 1건 (P1 히스토리). 전사 원문 + 번역문 + 방향.
import Foundation

struct Utterance: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceLanguage: Language
    let targetLanguage: Language
    let transcript: String      // STT 원문
    let translation: String     // MT 결과
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceLanguage: Language,
        targetLanguage: Language,
        transcript: String,
        translation: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.transcript = transcript
        self.translation = translation
        self.createdAt = createdAt
    }
}
