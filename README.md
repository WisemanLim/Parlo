# Parlo

한국어 ↔ 영어를 **완전 온디바이스**로 전사·번역·음성 출력하는 iOS 네이티브 통역 개인비서.
서버·계정 없음. 음성 데이터가 기기를 벗어나지 않음(프라이버시). PRD: [.docs/Parlo-PRD.md](.docs/Parlo-PRD.md).

## 기능

- **실시간 전사** 마이크 탭 후 발화 → 중앙에 STT 전사가 실시간 표시.
- **무음 자동 확정** 0.8초 무음이면 자동으로 번역·재생(수동 정지 불필요).
- **언어 선택** 한국어 ↔ 영어 상호 방향, 스왑 버튼.
- **MT** 전사문 → 대상 언어 번역 (온디바이스, Apple Translation). 전사·번역 둘 다 중앙 표시.
- **TTS** 번역문 음성 재생 (AVSpeechSynthesizer).
- **히스토리** 우상단 버튼 → 저장된 전사/번역 목록. 통역마다 자동 누적, 모두 지우기.
- **양방향 모드**(좌상단 토글) 발화 1건 처리 후 방향 자동 반전.

## 아키텍처

완전 온디바이스 직렬 파이프라인:

```
VAD → STT → MT → TTS → 재생
```

핵심은 **엔진 추상화**. STT/MT/TTS 를 각각 프로토콜 뒤에 두어 1차는 네이티브로,
이후 순수 오픈소스로 무중단 교체한다.

| 역할 | 프로토콜 | 기본 구현 | 오픈소스 대안 |
|------|----------|-----------|---------------|
| STT | `STTEngine` | `SystemSpeechSTTEngine` (SFSpeechRecognizer, 온디바이스·오프라인) | `WhisperKitSTTEngine` (Q6) |
| MT | `TranslationEngine` | `AppleTranslationEngine` (Translation, iOS 18) | NLLB/Argos |
| TTS | `TTSEngine` | `SystemTTSEngine` (AVSpeechSynthesizer) | Piper |

```
App/Sources/
├── App.swift, ContentView.swift          # 진입점
├── Core/
│   ├── Env.swift
│   ├── Models/                           # Language, LanguagePair, Utterance
│   └── Engines/                          # 프로토콜 + 네이티브/오픈소스 구현 + EngineFactory
└── Features/Translation/
    ├── TranslationViewModel.swift        # 파이프라인 오케스트레이터(@Observable)
    └── TranslationScreen.swift           # SwiftUI UI + Apple Translation 세션 연동
```

> **Apple Translation 연동 노트:** `TranslationSession` 은 `.translationTask` 로만 획득되고
> non-Sendable 이라, 엔진은 **요청 채널**(AsyncStream)로 번역 요청을 뷰에 넘기고 응답을 await 한다.
> Swift 6 strict concurrency 하에서 세션은 nonisolated free 함수가 만든 action 클로저로 소비한다.

## 요구사항

- macOS + Xcode 16+ (검증: Xcode 26.6)
- **배포 타깃 iOS 18.0** (Apple Translation 공개 API 요건)
- **최소 기기 iPhone 12 mini** 이상

## 빠른 시작

프로젝트는 XcodeGen(`project.yml`)으로 생성한다. `.xcodeproj` 는 생성물.

```bash
make generate       # project.yml → Parlo.xcodeproj
make open           # Xcode 에서 열기
make dev            # 시뮬레이터 빌드 (scheme=Parlo)
make test           # XCTest (mock 엔진 파이프라인 시험)
```

Info.plist 는 `project.yml` 의 `INFOPLIST_KEY_*` 로 생성(마이크·음성인식 권한 문자열 포함).
번들ID `com.wise.parlo`, 배포타깃 iOS 18.0.

## 시험

- **자동(mock):** `make test` — 파이프라인 오케스트레이션 8케이스. 결과 [test/impl/1/result.md](test/impl/1/result.md).
- **실기기(수동):** STT(마이크·Neural Engine)·번역 언어팩은 시뮬레이터 실측 불가 →
  iPhone 12 mini 실기기 QA 필요. 시나리오 [test/impl/1/scenario.md](test/impl/1/scenario.md) M1~M4.

## WhisperKit(오픈소스 STT) 활성화

1. Xcode: File ▸ Add Package Dependencies… → `https://github.com/argmaxinc/WhisperKit`
   (또는 `project.yml` 의 `packages:` 에 추가 후 `xcodegen generate`).
2. `WhisperKitSTTEngine`(`#if canImport(WhisperKit)`)이 자동 컴파일.
3. `EngineFactory.makeSTT()` 가 WhisperKit 을 우선 반환.

## 배포

`fastlane/Fastfile` 의 `build`/`beta`(TestFlight) lane. 서명은 match/ASC 키 주입(커밋 금지).
앱 배포 시 Info.plist 에 `NSMicrophoneUsageDescription`·`NSSpeechRecognitionUsageDescription` 필수.
규제·개인정보: [COMPLIANCE.md](COMPLIANCE.md).

## 한계 / TODO

- 실기기/배포 서명: `project.yml` 의 `DEVELOPMENT_TEAM` 주입 필요(시뮬레이터는 불필요, 커밋 금지).
- STT 는 현재 네이티브(SFSpeechRecognizer). 오픈소스 요구 시 WhisperKit 전환(위 절차).
- 지연 예산 ≤2.0s·WER 목표는 실기기 측정 후 튜닝.
