import SwiftUI
import StageCueCore

struct CueEditorView: View {
    @Environment(CueLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let existing: CuePlan?
    @State private var title: String
    @State private var instruction: String
    @State private var steps: [CueStep]
    @State private var source: CueSource
    @State private var folderID: UUID?
    @State private var showFolderPrompt = false
    @State private var newFolderName = ""
    @State private var isReviewing: Bool
    @State private var approved = false
    @State private var isGenerating = false
    @State private var generationTask: Task<Void, Never>?
    @State private var generationID = UUID()
    @State private var dictationTask: Task<Void, Never>?
    @State private var generator = InstructionGenerator()
    @State private var dictation = DictationService()
    @State private var textBeforeRecording = ""
    @State private var errorMessage: String?
    @State private var confirmDiscard = false
    @FocusState private var focused: Bool

    init(existing: CuePlan? = nil, initialFolderID: UUID? = nil) {
        self.existing = existing
        _folderID = State(initialValue: existing?.folderID ?? initialFolderID)
        _title = State(initialValue: existing?.title ?? "")
        _instruction = State(initialValue: existing?.originalInstruction ?? "")
        _steps = State(initialValue: existing?.steps ?? [])
        _source = State(initialValue: existing?.source ?? .manual)
        _isReviewing = State(initialValue: existing != nil)
    }

    private var validInput: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 60 &&
        !instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && instruction.count <= 2000
    }
    private var canSave: Bool {
        approved && (try? CueValidation.validate(title: title, originalInstruction: instruction, steps: steps)) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if isReviewing { reviewSections } else { inputSections }
            }
            .navigationTitle(isReviewing ? "안내 확인" : "새 연습")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        if !title.isEmpty || !instruction.isEmpty { confirmDiscard = true }
                        else { dismiss() }
                    }
                }
                if isReviewing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") { save() }
                            .disabled(!canSave)
                            .accessibilityIdentifier("savePlan")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("입력 완료") { focused = false }
                }
            }
            .interactiveDismissDisabled(!title.isEmpty || !instruction.isEmpty)
            .confirmationDialog("작성 중인 내용을 닫을까요?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("저장하지 않고 닫기", role: .destructive) { dismiss() }
                Button("계속 작성", role: .cancel) {}
            }
            .alert("확인이 필요해요", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onChange(of: dictation.transcript) { _, text in
                guard !isReviewing else { return }
                instruction = textBeforeRecording + (textBeforeRecording.isEmpty || text.isEmpty ? "" : "\n") + text
            }
            .onChange(of: dictation.errorMessage) { _, value in if let value { errorMessage = value } }
            .onChange(of: steps) { _, _ in approved = false }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    dictationTask?.cancel()
                    generationID = UUID()
                    dictation.stop()
                    generationTask?.cancel()
                    isGenerating = false
                }
            }
            .onDisappear {
                dictationTask?.cancel()
                generationID = UUID()
                generationTask?.cancel()
                dictation.stop()
            }
        }
    }

    @ViewBuilder private var inputSections: some View {
        folderSection
        Section("장면 이름") {
            TextField("예: 무대 입장", text: $title)
                .focused($focused)
                .accessibilityIdentifier("sceneTitle")
                .disabled(isGenerating || dictation.isRecording)
            if title.count > 60 { Text("이름은 60자 이내로 입력해주세요.").foregroundStyle(.red) }
        }
        Section {
            Text("한 번에 여러 동작을 적어도 괜찮아요. 방향과 걸음 수는 원래 지시대로 적어주세요.")
                .font(.subheadline).foregroundStyle(.secondary)
            TextEditor(text: $instruction)
                .frame(minHeight: 150)
                .focused($focused)
                .accessibilityLabel("무대 지시")
                .accessibilityIdentifier("instructionInput")
                .disabled(isGenerating || dictation.isRecording)
            HStack {
                Button {
                    focused = false
                    if dictation.isRecording { dictationTask?.cancel(); dictation.stop() }
                    else {
                        textBeforeRecording = instruction
                        dictationTask?.cancel()
                        dictationTask = Task { await dictation.start() }
                    }
                } label: {
                    Label(dictation.isRecording ? "입력 마치기" : "말로 입력", systemImage: dictation.isRecording ? "stop.circle.fill" : "mic")
                }
                .disabled(isGenerating)
                Spacer()
                Text("\(instruction.count) / 2,000")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(instruction.count > 2000 ? .red : .secondary)
            }
            Button("예시 지시 넣기") {
                dictationTask?.cancel()
                dictation.stop()
                instruction = CuePlan.sample.originalInstruction
                if title.isEmpty { title = CuePlan.sample.title }
            }
            .disabled(isGenerating || dictation.isRecording)
            .accessibilityIdentifier("insertExample")
        } header: { Text("무대 지시") }
        footer: { Text("음성 입력 시 기기 설정에 따라 Apple의 음성 인식 서비스가 사용될 수 있어요.") }
        Section {
            if let message = generator.availabilityMessage {
                Label(message, systemImage: "info.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Button { generate() } label: {
                HStack {
                    if isGenerating { ProgressView().tint(.white) }
                    Label(isGenerating ? "단계를 정리하고 있어요" : "AI로 단계 정리", systemImage: "sparkles")
                }
                .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!validInput || isGenerating || dictation.isRecording || generator.availabilityMessage != nil)
            if isGenerating {
                Button("정리 취소", role: .cancel) { generationID = UUID(); generationTask?.cancel(); isGenerating = false }
            }
            Button("직접 단계 작성") {
                dictationTask?.cancel()
                dictation.stop()
                focused = false
                steps = [CueStep(instruction: instruction.trimmingCharacters(in: .whitespacesAndNewlines))]
                source = .manual
                approved = false
                isReviewing = true
            }
            .disabled(!validInput || isGenerating || dictation.isRecording)
            .accessibilityIdentifier("manualSteps")
        } footer: { Text("AI는 입력한 지시를 짧은 단계로 정리해요. 다음 화면에서 내용을 확인하고 수정할 수 있어요.") }
    }

    @ViewBuilder private var reviewSections: some View {
        folderSection
        Section("원래 지시") {
            Text(title).font(.headline)
            Text(instruction).foregroundStyle(.secondary)
            Button("원문 수정하기") { approved = false; isReviewing = false }
        }
        Section {
            ForEach($steps) { $step in
                let number = (steps.firstIndex(where: { $0.id == step.id }) ?? 0) + 1
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(number)단계").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
                    TextField("한 가지 동작을 입력해주세요", text: $step.instruction, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($focused)
                        .accessibilityLabel("\(number)단계 안내")
                }
                .padding(.vertical, 4)
            }
            .onDelete { steps.remove(atOffsets: $0) }
            .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
            if steps.count < 20 {
                Button("단계 추가", systemImage: "plus") { steps.append(CueStep(instruction: "")) }
            }
            EditButton()
        } header: { Text("\(source == .ai ? "AI가 정리한" : "직접 작성한") 안내 · \(steps.count)단계") }
        footer: { Text("한 단계에 한 동작씩 적어주세요. 편집 버튼으로 순서를 바꾸거나 삭제할 수 있어요. 최대 20단계, 단계당 300자까지 저장할 수 있어요.") }
        Section {
            Toggle("원문과 비교해 방향·걸음 수·순서를 확인했어요", isOn: $approved)
                .accessibilityIdentifier("approveSteps")
        } footer: {
            Text("내용을 확인한 뒤 저장해주세요. 연습할 때는 조력자가 움직임을 보고 직접 안내하고 단계를 넘겨요.")
        }
    }

    private var folderSection: some View {
        Section("저장할 폴더") {
            Picker("폴더", selection: $folderID) {
                Text("미분류").tag(nil as UUID?)
                ForEach(library.folders) { folder in Text(folder.name).tag(Optional(folder.id)) }
            }
            Button("새 폴더 만들기", systemImage: "folder.badge.plus") { showFolderPrompt = true }
                .disabled(isGenerating)
        }
        .alert("새 폴더", isPresented: $showFolderPrompt) {
            TextField("폴더 이름", text: $newFolderName)
            Button("만들기") {
                do { folderID = try library.createFolder(name: newFolderName).id; newFolderName = "" }
                catch { errorMessage = error.localizedDescription }
            }
            Button("취소", role: .cancel) { newFolderName = "" }
        } message: { Text("예: 단독 공연, 워크숍 연습") }
    }

    private func generate() {
        focused = false
        dictationTask?.cancel()
        dictation.stop()
        isGenerating = true
        generationTask?.cancel()
        let input = instruction
        let requestID = UUID()
        generationID = requestID
        generationTask = Task { @MainActor in
            defer { if generationID == requestID { isGenerating = false } }
            do {
                let generated = try await generator.generate(from: input)
                try Task.checkCancellation()
                guard generationID == requestID else { return }
                steps = generated.map { CueStep(instruction: $0) }
                source = .ai
                approved = false
                isReviewing = true
            } catch is CancellationError {
                // Closing or cancelling never replaces the user's draft.
            } catch {
                guard !Task.isCancelled, generationID == requestID else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func save() {
        let plan = CuePlan(
            id: existing?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            originalInstruction: instruction.trimmingCharacters(in: .whitespacesAndNewlines),
            steps: steps.map { CueStep(id: $0.id, instruction: $0.instruction.trimmingCharacters(in: .whitespacesAndNewlines)) },
            source: source,
            createdAt: existing?.createdAt ?? Date(),
            folderID: folderID
        )
        do { try library.save(plan); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
}
