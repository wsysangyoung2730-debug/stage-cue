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
                    quickGuidance
                    if progress.currentIndex + 1 < plan.steps.count {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("다음 동작").font(.subheadline).foregroundStyle(.secondary)
                                Text(plan.steps[progress.currentIndex + 1].instruction).font(.headline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text("공연자의 움직임을 확인한 뒤 다음 단계로 넘겨주세요.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(plan.source == .sample ? "예시 · 조력자 안내" : "조력자 안내")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.accentColor)
                Spacer()
                Text("\(plan.steps.count)단계 중 \(progress.currentIndex + 1)단계")
                    .font(.subheadline.weight(.semibold)).accessibilityIdentifier("stepProgress")
            }
            ProgressView(value: Double(progress.currentIndex + 1), total: Double(max(plan.steps.count, 1)))
                .accessibilityHidden(true)
        }
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("지금 안내할 동작")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.accentColor)
            Text(plan.steps[progress.currentIndex].instruction)
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($instructionFocused)
                .accessibilityIdentifier("currentInstruction")
            Button {
                if speaker.isSpeaking { speaker.stop() }
                else { readCurrent() }
            } label: {
                Label(speaker.isSpeaking ? "말하기 멈추기" : "이 단계 말하기", systemImage: speaker.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .accessibilityIdentifier("listenInstruction")
        }
        .padding(20)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
    }

    private var quickGuidance: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("동작 수정 · 빠른 말하기")
                .font(.headline)
            Text("방향과 걸음 수를 누르면 바로 안내해요.")
                .font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                quickButton(.left)
                quickButton(.right)
            }
            HStack(spacing: 10) {
                quickButton(.oneStep)
                quickButton(.twoSteps)
                quickButton(.threeSteps)
            }
            Text("왼쪽·오른쪽은 공연자 기준의 회전 안내예요.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private func quickButton(_ cue: QuickCue) -> some View {
        Button {
            speaker.speak(cue.instruction, rate: speechRate)
        } label: {
            VStack(spacing: 6) {
                if let symbol = cue.symbol {
                    Image(systemName: symbol).font(.title3.weight(.semibold))
                }
                Text(cue.title).font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .accessibilityIdentifier("quickCue-\(cue.rawValue)")
        .accessibilityLabel(cue.title)
        .accessibilityHint("\(cue.instruction) 현재 단계는 바뀌지 않습니다.")
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                speaker.stop(); progress.goBack(); instructionFocused = true
            } label: {
                Label("이전 단계", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.bordered)
            .disabled(progress.currentIndex == 0)
            .accessibilityIdentifier("previousStep")
            Button {
                speaker.stop(); progress.advance(); instructionFocused = true
            } label: {
                HStack {
                    Text("다음 단계")
                    Image(systemName: "chevron.right")
                }
                .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint(progress.currentIndex == plan.steps.count - 1 ? "마지막 단계입니다. 누르면 안내를 마칩니다." : "다음 동작을 확인합니다. 음성은 말하기 버튼을 누르면 재생됩니다.")
            .accessibilityIdentifier("nextStep")
        }
        .controlSize(.large)
    }

    private var completion: some View {
        VStack(spacing: 24) {
            ContentUnavailableView("한 장면의 안내를 마쳤어요", systemImage: "checkmark.circle", description: Text("\(plan.steps.count)개의 단계 안내를 마쳤어요. 필요하면 처음부터 다시 안내할 수 있어요."))
                .accessibilityIdentifier("practiceComplete")
            Button {
                speaker.stop(); progress.restart(); instructionFocused = true
            } label: {
                Label("처음부터 다시 안내", systemImage: "arrow.counterclockwise")
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

private enum QuickCue: String {
    case left, right
    case oneStep = "1step"
    case twoSteps = "2steps"
    case threeSteps = "3steps"

    var title: String {
        switch self {
        case .left: "왼쪽"
        case .right: "오른쪽"
        case .oneStep: "1걸음"
        case .twoSteps: "2걸음"
        case .threeSteps: "3걸음"
        }
    }

    var symbol: String? {
        switch self {
        case .left: "arrow.turn.up.left"
        case .right: "arrow.turn.up.right"
        case .oneStep, .twoSteps, .threeSteps: nil
        }
    }

    var instruction: String {
        switch self {
        case .left: "왼쪽으로 돌아주세요."
        case .right: "오른쪽으로 돌아주세요."
        case .oneStep: "한 걸음 이동하세요."
        case .twoSteps: "두 걸음 이동하세요."
        case .threeSteps: "세 걸음 이동하세요."
        }
    }
}
