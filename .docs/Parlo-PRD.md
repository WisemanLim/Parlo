# One-Page PRD: Parlo — Realtime Translation for iOS

> 이 문서는 설문 대신 `.docs/Perplexity-실시간 번역앱 조사.md` 조사 결과 + 지시사항으로 자동 초안화, 이후 사용자 결정(Q1~Q5) 반영본입니다.
> `가정:` 표시는 아직 사용자 확정이 필요한 값입니다. 검토·수정 후 `/wise-dev-standard:recommend` 로 이어가세요.

## 0. 앱명 (확정)

**Parlo** — "말하다"(라틴/이탈리아어). 짧고 글로벌·상표 충돌 낮음. 제목·번들ID에 반영.

<details><summary>검토했던 후보 (기록용)</summary>

| # | 이름 | 의미 / 톤 | 결과 |
|---|------|-----------|------|
| 1 | **Parlo** | "말하다". 짧고 브랜드화 쉬움 | **선택** |
| 2 | VoiceBridge | 음성으로 언어를 잇는다 | 미채택 |
| 3 | Lingo Live | 라이브(실시간) 통역 | 미채택 |
| 4 | Interpreta | "내 손안의 통역사" | 미채택 |
| 5 | EchoLingua | 말한 것을 되울려 다른 언어로 | 미채택 |

> 참고: 작업 환경에 `As It Sounds.app` 존재 → 이름 충돌 회피 위해 후보에서 제외했음.
</details>

## 1. 개요
- **한 줄 요약:** 한국어↔영어를 즉시 전사·번역·음성 출력하는 iOS 네이티브 온디바이스 통역 개인비서.
- **배경 / 왜 지금:** 기존 실시간 통역은 클라우드 의존(음성 외부 전송·사용량 과금)이거나 Android 중심(RTranslator)임. 서버 없는 iOS 온디바이스 앱은 프라이버시·오프라인·무과금이라는 빈틈을 채움.
- **작성자 / 날짜 / 버전:** bclim@wise.com / 2026-07-23 / v0.2 (decisions applied)

## 2. 문제와 대상 (Why & Who)
- **핵심 문제:** 대면 상황에서 언어 장벽. 클라우드 통역앱은 민감한 대화를 외부 서버로 보내고 네트워크·비용에 종속됨.
- **비즈니스 관점:** 서버 운영비 0 → 유료 구독/무료 배포 모두 마진 구조 단순. 프라이버시를 차별점으로 소구.
- **근거 데이터 / VOC:** `가정:` 조사 문서(`.docs/`) — 온디바이스 프라이버시·오프라인 수요, RTranslator가 Android 한정이라는 공백.
- **타깃 사용자:** 해외 여행자, 외국인 응대 소상공인, 프라이버시 민감 사용자(의료/상담 등 대면).
- **대표 사용 상황:** 네트워크가 불안정하거나 대화를 외부로 보내고 싶지 않은 1:1 대면 통역.

## 3. 범위 (What — In / Out)

**이번 릴리즈 핵심 기능 (P0/P1):**
- **P0** STT: 화자 음성 → 텍스트 전사 (온디바이스, 오픈소스 라이브러리).
- **P0** 대상 언어 선택 — **한국어 ↔ 영어 (상호 방향)**.
- **P0** MT: 전사 텍스트 → 대상 언어 번역 (온디바이스).
- **P0** TTS: 번역문 음성 재생.
- **P1** 대화 히스토리 표시(전사/번역 텍스트 화면 로그).
- **P1** 양방향 대화 모드(한↔영 자동 왕복).

**하지 않을 것 (Out of Scope):**
- 서버·백엔드·클라우드 API 연동 일체 (완전 온디바이스).
- 회원가입·계정·동기화.
- 다자(3인+) 회의 통역, 실시간 자막 방송.
- 텍스트 문서 번역(음성 파이프라인에 집중).
- 1차 릴리즈에서 한·영 외 언어쌍 (엔진 추상화로 향후 확장).

## 4. 사용자 경험 (How — User Flow)
- **시나리오 1 (단방향):** 사용자가 대상 언어(영어) 선택 → 마이크 버튼 → 한국어로 말함 → 화면에 한국어 전사 + 영어 번역 표시 → 자동으로 영어 음성 재생.
- **시나리오 2 (양방향, P1):** 한↔영 지정 → 각자 말하면 언어를 감지/토글해 상대 언어로 전사·번역·재생 (RTranslator 대화 모드 유사).

## 5. 성공 지표 (Success)
`가정:` 소비자 신규 앱으로 기준선(baseline) 없음 → 초기 목표값 제안.

| KPI | Baseline | Target | 측정 방법 |
|-----|----------|--------|-----------|
| 발화→음성출력 종단 지연 | 없음 | `가정:` ≤ 2.0s (짧은 문장, iPhone 12 mini 기준) | 온디바이스 파이프라인 타임스탬프 로깅 |
| STT 정확도(WER) | 없음 | `가정:` ≤ 15% (한/영) | 표준 음성셋 오프라인 측정 |
| 오프라인 동작 | — | 100% (네트워크 0 상태 전 기능) | 비행기 모드 시험 |
| 크래시 프리 세션 | 없음 | `가정:` ≥ 99% | Xcode Organizer / MetricKit |

**검증 가능한 수용 기준 (Given-When-Then):**
- Given 비행기 모드, When 한국어로 말함, Then 서버 호출 없이 영어 전사·번역·음성 출력이 완료된다.
- Given 대상 언어 영어 선택, When "안녕하세요" 발화, Then 화면에 "Hello" 번역이 표시되고 음성 재생된다.
- Given iPhone 12 mini(최소 지원 기기), When 한↔영 통역, Then 앱이 크래시 없이 종단 지연 목표 내 동작한다.

## 6. 결정 사항 및 리스크

**확정된 결정 (Q1~Q5):**

| # | 항목 | 결정 | 확장 설계 |
|---|------|------|-----------|
| Q1 | 앱명 | **Parlo** | — |
| Q2 | MT 엔진 | **Apple Translation 프레임워크** (네이티브·온디바이스) | `TranslationEngine` 프로토콜 추상화 → NLLB/Argos 오픈소스 교체 가능 |
| Q3 | TTS | **AVSpeechSynthesizer** (네이티브) | `TTSEngine` 프로토콜 추상화 → Piper(포팅) 교체 가능 |
| Q4 | 언어쌍 | **한국어 ↔ 영어 (양방향)** | 엔진 추상화로 언어쌍 추가 확장 |
| Q5 | 최소 기기 | **iPhone 12 mini** 이상 | 배포 타깃은 §7 참조 |

> 설계 원칙: **엔진 교체 가능성(pluggability)**. STT/MT/TTS 각각을 프로토콜 뒤에 두어, 1차는 네이티브(Apple Translation·AVSpeechSynthesizer)로 빠르게, 이후 순수 오픈소스(NLLB/Argos·Piper)로 무중단 교체.

**리스크 및 메모:**
- **온디바이스 성능:** STT(Whisper 계열) 모델은 RAM·발열·첫 로딩 지연 부담. iPhone 12 mini(4GB RAM)가 성능 하한 → 모델 크기(예: whisper tiny/base) 선택이 종단 지연의 핵심 변수.
- **Apple Translation 가용성:** 공개 온디바이스 번역 API는 iOS 18+ 필요 → 배포 타깃 iOS 18 가정(iPhone 12 mini 지원 범위 내). 언어팩 최초 다운로드 UX 고려.
- **모델 배포:** STT 모델 최초 다운로드/번들(수십~수백 MB)로 앱 용량·온보딩 영향.
- **미결정 (Open Questions):**
  - Q6. **해소** — STT = **WhisperKit**(SwiftPM 배포·MIT) 채택. 모델 크기(tiny/base)는 iPhone 12 mini 실기기 성능 검증 후 튜닝. whisper.cpp 는 대안.
  - Q7. **해소** — 배포 iOS 최소 = **iOS 18.0**(Apple Translation 공개 API 요건, iPhone 12 mini 지원 범위 내).

---

## 7. 기술 메모 (Technical Notes)

> 최종 스택은 `/wise-dev-standard:recommend` 에서 확정. 아래는 결정 반영 초안.

- **아키텍처:** 완전 온디바이스 직렬 파이프라인 — `VAD → STT → MT → TTS → 재생`. 서버 없음.
- **엔진 추상화 (핵심):** `STTEngine` / `TranslationEngine` / `TTSEngine` 프로토콜. 1차 구현은 네이티브, 오픈소스 구현체를 나중에 주입.
- **STT (P0, 오픈소스):** `가정:` **WhisperKit**(Swift, MIT) 또는 **whisper.cpp** — Whisper 모델 온디바이스, CoreML/Metal 가속. → Q6 확정 대상.
- **MT (P0, 확정):** **Apple Translation 프레임워크**(`TranslationSession`, iOS 18+, 온디바이스). 확장: `TranslationEngine` 뒤에 NLLB/Argos(CTranslate2→CoreML) 교체 가능.
- **TTS (P0, 확정):** **AVSpeechSynthesizer**(네이티브, 온디바이스, 한/영 음성). 확장: `TTSEngine` 뒤에 Piper 포팅 교체 가능.
- **UI:** SwiftUI, 단일 화면 통역 + 대화 로그. 개인비서형 단순 인터랙션.
- **최소 기기/OS:** iPhone 12 mini 이상. 배포 타깃 `가정:` iOS 18.0 (Apple Translation 공개 API 요건).
- **지연 예산(초안):** VAD ~100ms + STT ~600ms + MT ~300ms + TTS ~400ms ≈ 목표 ≤ 2.0s (iPhone 12 mini 검증 필요).
- **비기능 요구사항:** 100% 오프라인 동작, 음성 데이터 외부 전송 0, 저사양 기기 그레이스풀 저하.
- **데이터/로깅:** 온디바이스 로컬 로그만(지연·WER 측정용), 개인정보 외부 전송 없음.

## 8. 실행 연결 (Epic / Story 힌트)
- Epic A: 오디오 입력 + VAD 파이프라인.
- Epic B: 온디바이스 STT 통합(`STTEngine`, WhisperKit, 모델 다운로드·캐시).
- Epic C: 온디바이스 MT 통합(`TranslationEngine`, Apple Translation, 한↔영 언어팩).
- Epic D: TTS 재생(`TTSEngine`, AVSpeechSynthesizer, 한/영 음성).
- Epic E: 언어 선택 UI + 대화 로그(SwiftUI).
- Epic F: 양방향 대화 모드(P1).

---

## 9. 스택 확정 (recommend 결과)

`/wise-dev-standard:recommend` 산출. 프로파일 **`ios-swiftui`** (`kind: mobile`, iOS 전용).

| 항목 | 선택 | 대안 | 근거 |
|---|---|---|---|
| 종류 | 모바일 앱(`kind: mobile`) | — | PRD: iOS Native 온디바이스 |
| 업종(KSIC) | `ict-saas` (J) | — | 소비자 SW 베이스라인. 서버·멀티테넌시 델타는 온디바이스라 대부분 N/A |
| 타깃 플랫폼 | iOS 전용 | — | §1.7-1 |
| 언어 | Swift | — | 네이티브 성능 + Apple Translation/AVSpeech 직접 사용 |
| 패키지/빌드 | SwiftPM (Xcode `.xcode-version` 핀) | CocoaPods(레거시만) | WhisperKit SwiftPM 배포 |
| UI | SwiftUI + `@Observable`(iOS 17+) | UIKit interop | 단일 화면 통역 + 대화 로그, HIG |
| 온디바이스 저장 | SwiftData | GRDB(SQLite) | 대화 히스토리·설정. 서버 DB 없음 |
| STT | WhisperKit (오픈소스·MIT) | whisper.cpp | Q6 해소 |
| MT | Apple Translation (iOS 18+) | NLLB/Argos(추상화 교체) | Q2 확정 |
| TTS | AVSpeechSynthesizer | Piper(추상화 교체) | Q3 확정 |
| 배포 타깃 | iOS 18.0 / iPhone 12 mini+ | — | Q5·Q7 |
| 빌드 플레이버 | local(Debug·시뮬) / staging(TestFlight·adhoc) / prod(Release) | — | 서버 없음 → `api_base`·dev 환경 생략 |
| 실행 | iOS Simulator + **실기기 검증 필수**(Neural Engine·언어팩) | — | STT/번역은 시뮬레이터와 동작 상이 |
| 배포 | Fastlane(match) → TestFlight → App Store | — | 프로파일 `ops.deploy` |
| 시험러너 | XCTest + XCUITest, 증빙 `test/dev-env/` + `test/impl/<Nth>/` | — | §6.5. 추가: 오프라인·지연 예산 측정 |
| 백엔드 | 없음 | — | Out of Scope |
| 프로파일 | `ios-swiftui` | flutter-app(향후 Android 동시 출시 시) | — |

**도메인 오버레이 (`ict-saas`):**
- 한국 규제: 개인정보보호법(PIPA) — 마이크 음성=PII이나 **외부 전송 0·온디바이스 처리**로 최소화 자연 충족. `NSMicrophoneUsageDescription` 목적 고지 + App Store 개인정보 라벨 필수. 정보통신망법·ISMS-P·CSAP는 서버 없어 N/A.
- 데이터 등급: 음성/전사 텍스트=민감(로컬만 저장·삭제 기능 권장), 로컬 로그=내부.
- 인프라 델타: 멀티테넌시·OTel·API 게이트웨이 N/A. CI(GitHub Actions macOS + Fastlane)만.
- 추가 시험(대체): 비행기 모드 100% 동작, 네트워크 호출 0 검증, 종단 지연 ≤2.0s 측정.

**구현 노트:** 구현 단계는 Claude Code 기본 모델 사용(에이전트 model override 없음).
