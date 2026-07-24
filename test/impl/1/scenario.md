# 시험 시나리오 — 구현 1차 (P0/P1 기능)

대상: PRD §3 이번 릴리즈 핵심 기능. 온디바이스 파이프라인 오케스트레이션.

## 자동 시험 (XCTest, 시뮬레이터)
mock 엔진으로 STT/MT/TTS 실물 없이 로직 검증. 실행: `make test`.

| ID | 시나리오 | 기대 |
|----|----------|------|
| T1 | Language/LanguagePair 기본값 | ko-KR, English, koToEn.reversed==enToKo |
| T2 | 파이프라인 정상 흐름 process("안녕하세요") | 로그 1건 적재, transcript/translation/방향 일치, TTS 1회 호출(target=en), state=idle |
| T3 | 빈 전사 스킵 process("   ") | 로그 0, TTS 0, state=idle |
| T4 | 양방향 모드 반전 | 처리 후 pair koToEn→enToKo |
| T5 | 단방향 유지 | 처리 후 pair 불변 |
| T6 | 언어 스왑 | swapLanguages() → 방향 반전 |
| T7 | 번역 실패 처리 | errorMessage 설정, 로그 0, TTS 0, state=idle |
| T8 | 다건 누적 | 2회 처리 → 로그 2건 순서 유지 |

## 수동 시험 (실기기 — 이 환경 밖)
| ID | 시나리오 | 기대 | 상태 |
|----|----------|------|------|
| M1 | iPhone 12 mini, 한→영, "안녕하세요" 발화 | 화면 "Hello" 표시 + 영어 음성 재생 | 미실행(실기기 필요) |
| M2 | 비행기 모드에서 M1 반복 | 네트워크 0, 전 기능 동작 | 미실행(실기기 필요) |
| M3 | 종단 지연 측정 | ≤ 2.0s (짧은 문장) | 미실행(실기기 필요) |
| M4 | 양방향 모드 대화 | 방향 자동 반전, 상호 통역 | 미실행(실기기 필요) |

주의: STT(SFSpeechRecognizer 온디바이스)·Apple Translation 언어팩·마이크는 시뮬레이터/헤드리스
환경에서 실측 불가 → M1~M4 는 실기기 QA 대상(PRD "실기기 검증 필수").
