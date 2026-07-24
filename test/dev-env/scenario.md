# dev-env 검증 시나리오 (Parlo / ios-swiftui)

표준 개발환경이 동작하는지 스캐폴드 직후 1회 확인. 결과는 `logs/` 에 남긴다.

| # | 케이스 | 명령 / 절차 | 기대 결과 |
|---|--------|-------------|-----------|
| 1 | Xcode 툴체인 | `xcodebuild -version` | Xcode 16+ 출력 |
| 2 | 시뮬레이터 목록 | `xcrun simctl list devices available \| grep iPhone` | iPhone 시뮬레이터 존재 |
| 3 | SPM resolve | `swift package resolve` (또는 Xcode 자동) | 의존성 해결 성공 |
| 4 | 디버그 빌드 | `make dev` | 시뮬레이터 빌드·부팅 성공 |
| 5 | 테스트 | `make test` | XCTest 스모크 통과 |

주의:
- 배포 타깃 iOS 18.0. iPhone 12 mini 이상 지원.
- STT/번역/TTS 기능 검증은 `test/impl/<Nth>/` 에서 **실기기(iPhone 12 mini)** 로 수행 — 시뮬레이터 부적합.
- 서버 없음 → DB 연결·compose 케이스 해당 없음.
