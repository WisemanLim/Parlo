# Parlo

Native iOS interpreter assistant that transcribes, translates, and speaks Korean ↔ English
**fully on-device**. No server, no account. Voice data never leaves the device (privacy).
PRD: [.docs/Parlo-PRD.md](.docs/Parlo-PRD.md).

## Features

- **Live transcription** tap mic and speak → STT transcript shown live in the center.
- **Silence auto-commit** 0.8s of silence auto-triggers translation + speech (no manual stop).
- **Language selection** Korean ↔ English, both directions, swap button.
- **MT** transcript → target language (on-device, Apple Translation); both transcript and translation stay on screen.
- **TTS** speaks the translation (AVSpeechSynthesizer).
- **History** top-right button → saved transcript/translation list; auto-appended per utterance, clearable.
- **Bidirectional mode** (top-left toggle) auto-flips direction after each utterance.

## Architecture

Fully on-device serial pipeline: `VAD → STT → MT → TTS → playback`.

Core idea is **engine abstraction** — STT/MT/TTS each sit behind a protocol, native first,
swappable for pure open-source later with no pipeline change.

| Role | Protocol | Default | Open-source alt |
|------|----------|---------|-----------------|
| STT | `STTEngine` | `SystemSpeechSTTEngine` (SFSpeechRecognizer, on-device/offline) | `WhisperKitSTTEngine` |
| MT | `TranslationEngine` | `AppleTranslationEngine` (Translation, iOS 18) | NLLB/Argos |
| TTS | `TTSEngine` | `SystemTTSEngine` (AVSpeechSynthesizer) | Piper |

> **Apple Translation note:** `TranslationSession` is only vended via `.translationTask` and is
> non-Sendable, so the engine passes translation requests to the view through a **request channel**
> (AsyncStream) and awaits the response. Under Swift 6 strict concurrency the session is consumed by
> an action closure created in a nonisolated free function.

## Requirements

- macOS + Xcode 16+ (verified: Xcode 26.6)
- **Deployment target iOS 18.0** (Apple Translation public API)
- **Minimum device iPhone 12 mini**

## Quick start

```bash
make setup          # verify toolchain/simulators + resolve packages
make dev            # build on simulator (SCHEME=Parlo-Package)
make test           # XCTest (mock-engine pipeline tests)
```

## Testing

- **Automated (mock):** `make test` — 8 pipeline-orchestration cases. See [test/impl/1/result.md](test/impl/1/result.md).
- **On device (manual):** mic/Neural-Engine STT and translation language packs cannot be measured on
  the simulator → requires iPhone 12 mini QA. See [test/impl/1/scenario.md](test/impl/1/scenario.md) M1–M4.

## Enable WhisperKit (open-source STT)

1. Uncomment the WhisperKit dependency in `Package.swift`, then `swift package resolve`.
2. `WhisperKitSTTEngine` (`#if canImport(WhisperKit)`) compiles automatically.
3. `EngineFactory.makeSTT()` returns WhisperKit first.

## Notes / TODO

- A shipping bundle needs an `.xcodeproj` (Info.plist, bundle id, usage strings, signing); the SwiftPM
  manifest here is for source/test structure.
- STT currently native (SFSpeechRecognizer); switch to WhisperKit for the open-source path.
- Latency budget ≤2.0s and WER targets to be tuned after on-device measurement.
- Privacy/compliance: [COMPLIANCE.md](COMPLIANCE.md).
