# test/ — 시험 표준 (Parlo)

`wise-dev-standard` test-runner 표준. 코드 테스트(`AppTests/`, XCTest)와 별개로, **시험 시나리오·결과 증빙**을 여기 보관.

```
test/
├── README.md          # 이 문서
├── dev-env/           # 표준 환경 검증 (스캐폴드 직후 1회)
│   ├── scenario.md
│   └── logs/
└── impl/              # 구현 차수별 (implement 가 <Nth>/ 생성)
```

## 사이클
시나리오 작성 → 빌드·실행 → 오류 시 수정·재시험 → 결과 작성.

## Parlo 특화 시험 축 (온디바이스·서버 없음)
- **오프라인 100%:** 비행기 모드에서 STT→MT→TTS 전 기능 동작, 네트워크 호출 0.
- **종단 지연:** 발화→음성출력 ≤ 2.0s (iPhone 12 mini 실기기 기준, 짧은 문장).
- **실기기 필수:** STT(Neural Engine)·Apple Translation 언어팩은 시뮬레이터와 동작 상이 → iPhone 12 mini 검증.
