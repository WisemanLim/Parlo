// Parlo — 통역 메인 화면. 언어 선택 + 마이크 + 대화 로그 + 양방향 토글.
import SwiftUI
import Translation

struct TranslationScreen: View {
    @State private var viewModel = TranslationViewModel()
    @State private var showHistory = false

    var body: some View {
        // Sendable 스트림만 캡처(viewModel 캡처 시 클로저가 MainActor 격리 → 세션 전송 위반).
        let requests = viewModel.translationRequests
        let configuration = viewModel.translationConfiguration
        return NavigationStack {
            VStack(spacing: 0) {
                languageBar
                Divider()
                liveArea          // 중앙: 실시간 전사 + 번역
                micButton
            }
            .navigationTitle("Parlo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 좌상단: 양방향 대화 모드 토글
                ToolbarItem(placement: .topBarLeading) {
                    Toggle(isOn: $viewModel.isBidirectional) {
                        Label("양방향", systemImage: "arrow.left.arrow.right")
                    }
                    .toggleStyle(.button)
                }
                // 우상단: 히스토리 (저장된 전사/번역 목록)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Label("히스토리", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(utterances: viewModel.utterances) {
                    viewModel.clearHistory()
                }
            }
            // Apple Translation 세션 연결. 언어쌍 변경 시 재실행.
            // 세션을 로컬로 쥔 채 엔진의 번역 요청을 소비·응답(요청 채널 패턴).
            // action 클로저를 nonisolated free 함수에서 생성 → MainActor 격리 상속을 끊는다.
            .translationTask(configuration, action: translationAction(requests: requests))
            .alert("오류", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("확인") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var languageBar: some View {
        HStack {
            Text(viewModel.pair.source.displayName)
                .frame(maxWidth: .infinity)
            Button {
                viewModel.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.title2)
            }
            .disabled(viewModel.state != .idle)
            Text(viewModel.pair.target.displayName)
                .frame(maxWidth: .infinity)
        }
        .font(.headline)
        .padding()
    }

    // 중앙 컨텐츠: 발화 중 STT 전사(대형), 확정 후 대상 언어 번역(강조).
    private var liveArea: some View {
        VStack(spacing: 20) {
            Spacer()
            if viewModel.partialTranscript.isEmpty && viewModel.latestTranslation.isEmpty {
                Text("마이크를 눌러 말하세요")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            } else {
                // 전사(원문)
                Text(viewModel.partialTranscript)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                // 번역(대상 언어)
                if !viewModel.latestTranslation.isEmpty {
                    Text(viewModel.latestTranslation)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
            }
            Spacer()
            Text(statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.latestTranslation)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var micButton: some View {
        Button {
            viewModel.toggleListening()
        } label: {
            Image(systemName: viewModel.state == .listening ? "stop.circle.fill" : "mic.circle.fill")
                .resizable()
                .frame(width: 72, height: 72)
                .foregroundStyle(viewModel.state == .listening ? .red : .accentColor)
        }
        .padding()
        .disabled(viewModel.state == .translating || viewModel.state == .speaking)
    }

    private var statusText: String {
        switch viewModel.state {
        case .idle: return "마이크를 눌러 말하세요"
        case .listening: return "듣는 중… (말을 멈추면 자동 번역)"
        case .translating: return "번역 중…"
        case .speaking: return "재생 중…"
        }
    }
}

/// 히스토리 시트: 저장된 전사/번역 목록. 우상단 버튼으로 진입.
private struct HistoryView: View {
    let utterances: [Utterance]
    let onClear: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if utterances.isEmpty {
                    ContentUnavailableView("히스토리 없음", systemImage: "clock",
                                           description: Text("통역한 내용이 여기에 저장됩니다."))
                } else {
                    List(utterances.reversed()) { u in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(u.sourceLanguage.displayName) → \(u.targetLanguage.displayName)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(u.transcript)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(u.translation)
                                .font(.body)
                        }
                    }
                }
            }
            .navigationTitle("히스토리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                if !utterances.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("모두 지우기", role: .destructive) { onClear() }
                    }
                }
            }
        }
    }
}

/// nonisolated 컨텍스트에서 action 클로저를 만든다 → 클로저가 MainActor 격리를 상속하지 않아
/// session 을 nonisolated 메서드에 안전하게 넘길 수 있다.
private func translationAction(
    requests: AsyncStream<TranslationRequest>?
) -> (TranslationSession) async -> Void {
    return { session in
        await consumeTranslations(session, requests: requests)
    }
}

/// TranslationSession 으로 요청 채널을 소비해 번역을 수행.
private func consumeTranslations(
    _ session: TranslationSession,
    requests: AsyncStream<TranslationRequest>?
) async {
    // prepareTranslation() 을 여기서 await 하지 않는다 — 언어팩 미설치 시 다운로드를 기다리며
    // 블로킹돼 요청 루프가 시작되지 않고 번역이 영원히 대기(UI 프리즈)한다.
    // session.translate() 가 필요 시 자동 준비하며, ViewModel 의 10초 타임아웃이 보호한다.
    guard let requests else { return }
    for await req in requests {
        do {
            let response = try await session.translate(req.text)
            req.continuation.resume(returning: response.targetText)
        } catch {
            req.continuation.resume(throwing: error)
        }
    }
}

#Preview {
    TranslationScreen()
}
