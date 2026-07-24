# 시험 결과 — 구현 1차

- 일시: 2026-07-23
- 환경: Xcode 26.6, iOS 26.5 시뮬레이터(iPhone 17 Pro), Swift 6.3, 배포타깃 iOS 18
- 명령: `xcodebuild -scheme Parlo-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`

## 빌드
`** BUILD SUCCEEDED **`

주요 이슈·수정:
- Swift 6 strict concurrency: `TranslationSession`(non-Sendable, nonisolated async 메서드)을
  MainActor 클로저에서 await 시 "sending 'session' risks data races".
  → **요청 채널 패턴** + **nonisolated free 함수가 action 클로저 생성**으로 해소(격리 상속 차단).

## 자동 시험 (XCTest)
`** TEST SUCCEEDED **` — **8 tests, 0 failures**.

| ID | 결과 |
|----|------|
| T1 testLanguageBasics | PASS |
| T2 testProcessTranslatesLogsAndSpeaks | PASS |
| T3 testEmptyTranscriptSkips | PASS |
| T4 testBidirectionalFlipsPairAfterProcess | PASS |
| T5 testNonBidirectionalKeepsPair | PASS |
| T6 testSwapLanguages | PASS |
| T7 testTranslationFailureSetsErrorAndNoLog | PASS |
| T8 testMultipleUtterancesAccumulate | PASS |

Executed 8 tests, with 0 failures in 0.013s.

## 수동 시험 (실기기)
M1~M4 미실행 — 헤드리스 환경은 마이크·Neural Engine·언어팩 실측 불가. iPhone 12 mini 실기기 QA 대상.

## 판정
자동 시험 기준 **오류 없음(PASS)**. 파이프라인 오케스트레이션(전사→번역→로그→재생, 양방향 반전,
오류 처리) 검증 완료. 실물 엔진 종단 검증은 실기기 단계로 이월.
