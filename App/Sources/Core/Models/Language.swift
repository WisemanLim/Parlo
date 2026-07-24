// Parlo — 지원 언어. 1차 릴리즈: 한국어 ↔ 영어 (PRD Q4).
// 새 언어는 case 추가만으로 확장(엔진 추상화가 언어쌍 비의존).
import Foundation

enum Language: String, CaseIterable, Identifiable, Sendable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    /// 화면 표기명.
    var displayName: String {
        switch self {
        case .korean: return "한국어"
        case .english: return "English"
        }
    }

    /// BCP-47 / Locale 식별자 (STT·TTS·번역 공통).
    var localeIdentifier: String {
        switch self {
        case .korean: return "ko-KR"
        case .english: return "en-US"
        }
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    /// 양방향 모드에서 상대 언어.
    func opposite(in pair: LanguagePair) -> Language {
        self == pair.source ? pair.target : pair.source
    }
}

/// 출발→도착 언어쌍. 단방향 통역의 방향을 표현.
struct LanguagePair: Equatable, Sendable {
    var source: Language
    var target: Language

    /// 방향 뒤집기 (양방향 모드 토글).
    var reversed: LanguagePair { LanguagePair(source: target, target: source) }

    static let koToEn = LanguagePair(source: .korean, target: .english)
    static let enToKo = LanguagePair(source: .english, target: .korean)
}
