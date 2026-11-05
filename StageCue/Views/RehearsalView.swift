import SwiftUI
import StageCueCore

struct RehearsalView: View {
    let plan: CuePlan
    @Environment(\.scenePhase) private var scenePhase
    @State private var progress: RehearsalProgress
    @State private var speaker = SpeechPlayer()
    @State private var showSettings = false
    @AppStorage("speechRate") private var speechRate = 0.45
    @AccessibilityFocusState private var instructionFocused: Bool

    init(plan: CuePlan) {
        self.plan = plan
        _progress = State(initialValue: RehearsalProgress(stepCount: plan.steps.count))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if progress.isComplete {
                    completion
                } else {
                    introduction
                    instructionCard
                    if progress.currentIndex + 1 < plan.steps.count {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("다음 동작").font(.subheadline).foregroundStyle(.secondary)
                                Text(plan.steps[progress.currentIndex + 1].instruction).font(.headline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text("이동을 마치면 다음 단계를 눌러주세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                if let error = speaker.errorMessage {
                    Label(error, systemImage: "speaker.slash")
                        .font(.subheadline).foregroundStyle(.red)
                }
            }
            .padding(24)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            if !progress.isComplete {
                controls
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("음성 설정", systemImage: "speaker.wave.2") { speaker.stop(); showSettings = true }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { speaker.stop() } }
        .onDisappear { speaker.stop() }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(plan.source == .sample ? "예시 연습" : "연습 안내")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.accentColor)
            Text("한 동작씩,\n천천히 연습해요.")
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text("\(plan.steps.count)단계 중 \(progress.currentIndex + 1)단계")
                .font(.headline).accessibilityIdentifier("stepProgress")
            ProgressView(value: Double(progress.currentIndex + 1), total: Double(max(plan.steps.count, 1)))
                .accessibilityHidden(true)
        }
    }

    private var instructionCard: some View {
        VStack(spacing: 24) {
            Text("지금 할 동작")
                .font(.headline).foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "figure.walk")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(plan.steps[progress.currentIndex].instruction)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($instructionFocused)
                .accessibilityIdentifier("currentInstruction")
            Button {
                if speaker.isSpeaking { speaker.stop() }
                else { readCurrent() }
            } label: {
                Label(speaker.isSpeaking ? "안내 멈추기" : "안내 듣기", systemImage: speaker.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .accessibilityIdentifier("listenInstruction")
        }
        .padding(24)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
    }

    private var controls: some View {
        VStack(spacing: 14) {
            Button {
                speaker.stop()
                progress.advance()
                instructionFocused = true
            } label: {
                Label(progress.currentIndex == plan.steps.count - 1 ? "연습 완료" : "다음 단계", systemImage: progress.currentIndex == plan.steps.count - 1 ? "checkmark" : "arrow.right")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .accessibilityIdentifier("nextStep")
            HStack {
                Button {
                    speaker.stop(); progress.goBack(); instructionFocused = true
                } label: {
                    Label("이전 단계", systemImage: "arrow.left").frame(maxWidth: .infinity, minHeight: 30)
                }
                .disabled(progress.currentIndex == 0)
                Button { readCurrent() } label: {
                    Label("다시 듣기", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity, minHeight: 30)
                }
            }
            .buttonStyle(.bordered).controlSize(.large)
            Text("현재 위치나 동작 완료 여부는 자동으로 판단하지 않아요.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var completion: some View {
        VStack(spacing: 24) {
            ContentUnavailableView("한 장면을 연습했어요", systemImage: "checkmark.circle", description: Text("\(plan.steps.count)개의 안내를 모두 확인했어요. 원하는 만큼 다시 연습해보세요."))
                .accessibilityIdentifier("practiceComplete")
            Button {
                speaker.stop(); progress.restart(); instructionFocused = true
            } label: {
                Label("처음부터 다시 연습", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    private func readCurrent() {
        guard !progress.isComplete else { return }
        speaker.speak(plan.steps[progress.currentIndex].instruction, rate: speechRate)
    }
}
