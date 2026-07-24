# 시험 결과 — 구현 3차 (번역 타임아웃 / UI 프리즈 수정)

- 일시: 2026-07-24
- 환경: Xcode 26.6, iOS 26.5 시뮬레이터(iPhone 17 Pro), Swift 6.3

## 문제
"번역 중…" 이 무한 지속되고 아무 키도 안 먹힘(UI 프리즈).

## 원인
1. `.translationTask` 의 `prepareTranslation()` 를 요청 루프 앞에서 await → 언어팩 미설치 시 다운로드
   대기로 블로킹되어 요청 루프가 시작 안 됨 → 번역 continuation 영원히 미해결.
2. 번역 대기에 상한이 없어 `state=.translating` 고정 → 마이크 버튼 비활성(프리즈).

## 수정
- `consumeTranslations`: 루프 앞 `prepareTranslation()` 블로킹 제거(translate 가 필요 시 자동 준비).
- `AppleTranslationEngine.translate`: **10초 타임아웃**(TaskGroup 경쟁, Sendable `sink` 만 캡처).
  초과 시 `EngineError.timeout` throw → ViewModel 이 에러 표시 + `.idle` 복구.
- 좌상단 `↔` 버튼 = **양방향 대화 모드** 토글(설명은 아래).

## 자동 시험 (XCTest)
`** TEST SUCCEEDED **` — **11 tests, 0 failures**.
- 신규 testTimeoutRecoversToIdle: 타임아웃 시 errorMessage 설정 + state=idle + 로그/TTS 없음 → PASS.
- 기존 10건 전부 PASS.

## 수동 시험 (실기기)
| ID | 시나리오 | 기대 | 상태 |
|----|----------|------|------|
| M10 | 언어팩 미설치/네트워크 지연으로 번역 지연 | 10초 후 자동 취소 + 안내 알림, 마이크 재사용 가능 | 실기기 |
| M11 | 언어팩 설치 후 정상 번역 | 프리즈 없이 즉시 번역·재생 | 실기기 |

## 판정
빌드·자동 시험 오류 없음. 프리즈 재발 방지(엔진 타임아웃). 언어팩 최초 다운로드 체감은 실기기 확인.
