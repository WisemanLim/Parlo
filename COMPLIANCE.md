# COMPLIANCE — 정보통신·SaaS (KSIC J)

> 자동 생성. 근거: `domains/ict-saas.yaml` + KSIC 통합표. 규제는 변하므로 references 로 재확인.
> **Parlo 특수성:** 서버·백엔드 없는 **완전 온디바이스** 소비자 앱 → SaaS 규제 대부분 **해당 없음(N/A)**. 아래에 실제 적용분만 표기.

## 분류 / Classification
KSIC **J**(정보통신) · ISIC J · NACE J · NAICS 51.

## 한국 규제
| 규제 | 적용 | 조치 |
|------|------|------|
| 개인정보보호법(PIPA) | **적용** | 마이크 음성·전사 텍스트 = PII. **외부 전송 0·온디바이스 처리**로 최소화 원칙 자연 충족. 대화 로그 로컬 저장 시 **삭제 기능** 제공. |
| 정보통신망법 | N/A | 네트워크 서비스·서버 없음 |
| ISMS-P | N/A | 대형 ICT 서비스 아님, 서버 인프라 없음 |
| CSAP(클라우드) | N/A | 클라우드 판매 아님 |

## 국제 기준
- GDPR: EU 사용자 대상 시 — 온디바이스 처리로 데이터 이전·저장 리스크 최소. 개인정보 처리방침에 "데이터가 기기를 벗어나지 않음" 명시 권장.
- SOC 2 / ISO 27001: 서버 통제 대상 없음 → N/A.

## 데이터 등급
| 데이터 | 등급 | 비고 |
|--------|------|------|
| 마이크 음성 | 민감 | 처리 후 미보관 원칙, 외부 전송 금지 |
| 전사/번역 텍스트 | 민감 | 로컬만 저장, 사용자 삭제 가능 |
| 로컬 로그(지연·WER) | 내부 | 온디바이스만, 외부 전송 없음 |

## 앱 배포 필수 조치 (App Store)
- `NSMicrophoneUsageDescription` — 마이크 사용 목적 고지 (Info.plist).
- `NSSpeechRecognitionUsageDescription` — 음성 인식 사용 시(STT).
- App Store 개인정보 라벨: "데이터 수집 안 함" 선언 가능(온디바이스, 전송 없음).

## 인프라 델타
멀티테넌시·OpenTelemetry·API 게이트웨이·시크릿 관리 전부 **N/A**(서버 없음).
적용: CI(GitHub Actions macOS 러너 + Fastlane), 코드 서명(match/ASC 키 — 커밋 금지).

## 추가 시험 (test/ 반영)
SaaS 표준(크로스테넌트·OpenAPI 계약) N/A → 대체 축:
- 비행기 모드 100% 동작(네트워크 호출 0) 검증.
- 종단 지연 ≤ 2.0s 측정(iPhone 12 mini).

## 출처 / References
- https://isms-p.or.kr/sysm/intro/selectSysmCertDetail.do (ISMS-P)
- https://isms.kisa.or.kr/main/csap/notice/ (CSAP 2025)
- 개인정보보호법 §32-2 (유출통지)
