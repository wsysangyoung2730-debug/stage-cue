import SwiftUI
import StageCueCore

struct FolderContentsView: View {
    @Environment(CueLibrary.self) private var library
    let folderID: UUID?
    @State private var showComposer = false
    @State private var editingPlan: CuePlan?
    @State private var movingPlan: CuePlan?
    @State private var deletingPlan: CuePlan?
    @State private var errorMessage: String?

    private var folderName: String {
        library.folders.first(where: { $0.id == folderID })?.name ?? "미분류"
    }

    private var plans: [CuePlan] {
        library.plans.filter { $0.folderID == folderID }
    }

    var body: some View {
        List {
            if plans.isEmpty {
                ContentUnavailableView {
                    Label("저장한 연습이 없어요", systemImage: "folder")
                } description: {
                    Text("이 폴더에 무대 지시를 저장해두고, 필요할 때 바로 연습하세요.")
                } actions: {
                    Button("새 연습 만들기", systemImage: "plus") { showComposer = true }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("createPlanInEmptyFolder")
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(plans) { plan in
                        NavigationLink { RehearsalView(plan: plan) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(plan.title).font(.headline)
                                Text("\(plan.steps.count)단계 · \(plan.source == .ai ? "AI 정리 후 확인" : "직접 작성 후 확인")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .contextMenu {
                            Button("수정", systemImage: "pencil") { editingPlan = plan }
                            Button("폴더 이동", systemImage: "folder") { movingPlan = plan }
                            Button("삭제", systemImage: "trash", role: .destructive) { deletingPlan = plan }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("삭제", systemImage: "trash", role: .destructive) { deletingPlan = plan }
                            Button("이동", systemImage: "folder") { movingPlan = plan }.tint(.indigo)
                            Button("수정", systemImage: "pencil") { editingPlan = plan }.tint(.gray)
                        }
                    }
                } header: {
                    Text("저장한 연습 \(plans.count)개")
                } footer: {
                    Text("연습을 길게 누르거나 왼쪽으로 밀면 수정하거나 다른 폴더로 옮길 수 있어요.")
                }
            }
        }
        .navigationTitle(folderName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("새 연습", systemImage: "plus") { showComposer = true }
                    .accessibilityIdentifier("createPlanInFolder")
            }
        }
        .sheet(isPresented: $showComposer) { CueEditorView(initialFolderID: folderID) }
        .sheet(item: $editingPlan) { CueEditorView(existing: $0) }
        .sheet(item: $movingPlan) { MovePlanView(plan: $0) }
        .confirmationDialog("이 연습을 삭제할까요?", isPresented: Binding(
            get: { deletingPlan != nil },
            set: { if !$0 { deletingPlan = nil } }
        ), titleVisibility: .visible) {
            Button("연습 삭제", role: .destructive) {
                guard let plan = deletingPlan else { return }
                do { try library.delete(plan) }
                catch { errorMessage = error.localizedDescription }
                deletingPlan = nil
            }
        }
        .alert("변경하지 못했어요", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

struct FolderManagerView: View {
    @Environment(CueLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var showNamePrompt = false
    @State private var folderName = ""
    @State private var editingFolder: CueFolder?
    @State private var deletingFolder: CueFolder?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        editingFolder = nil
                        folderName = ""
                        showNamePrompt = true
                    } label: {
                        Label("새 폴더 만들기", systemImage: "folder.badge.plus")
                    }
                    .accessibilityIdentifier("createFolderButton")
                } footer: { Text("공연이나 장면별로 연습을 미리 모아두세요.") }

                Section("내 폴더") {
                    ForEach(library.folders) { folder in
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(folder.name).font(.headline)
                                    Text("연습 \(library.plans.filter { $0.folderID == folder.id }.count)개")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "folder.fill").foregroundStyle(Color.accentColor)
                            }
                            Spacer()
                            Menu {
                                Button("이름 변경", systemImage: "pencil") { rename(folder) }
                                Button("폴더 삭제", systemImage: "trash", role: .destructive) { deletingFolder = folder }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("\(folder.name) 폴더 관리")
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("삭제", systemImage: "trash", role: .destructive) { deletingFolder = folder }
                            Button("이름 변경", systemImage: "pencil") { rename(folder) }.tint(.indigo)
                        }
                    }
                    if library.folders.isEmpty {
                        Text("아직 만든 폴더가 없어요.").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("폴더 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
            .alert(editingFolder == nil ? "새 폴더" : "폴더 이름 변경", isPresented: $showNamePrompt) {
                TextField("폴더 이름", text: $folderName)
                    .accessibilityIdentifier("folderNameField")
                Button("취소", role: .cancel) {}
                Button(editingFolder == nil ? "만들기" : "저장") { saveFolder() }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || folderName.count > 60)
            } message: { Text("공연이나 장면 이름을 60자 이내로 입력해주세요.") }
            .confirmationDialog("폴더를 삭제할까요?", isPresented: Binding(
                get: { deletingFolder != nil },
                set: { if !$0 { deletingFolder = nil } }
            ), titleVisibility: .visible) {
                Button("폴더만 삭제", role: .destructive) {
                    guard let folder = deletingFolder else { return }
                    do { try library.deleteFolder(folder) }
                    catch { errorMessage = error.localizedDescription }
                    deletingFolder = nil
                }
            } message: {
                Text("폴더 안의 연습은 삭제되지 않고 미분류로 이동해요.")
            }
            .alert("변경하지 못했어요", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func rename(_ folder: CueFolder) {
        editingFolder = folder
        folderName = folder.name
        showNamePrompt = true
    }

    private func saveFolder() {
        do {
            if let folder = editingFolder {
                try library.renameFolder(folder, name: folderName)
            } else {
                _ = try library.createFolder(name: folderName)
            }
        } catch { errorMessage = error.localizedDescription }
        editingFolder = nil
    }
}

private struct MovePlanView: View {
    @Environment(CueLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    let plan: CuePlan
    @State private var selectedFolderID: UUID?
    @State private var errorMessage: String?

    init(plan: CuePlan) {
        self.plan = plan
        _selectedFolderID = State(initialValue: plan.folderID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(plan.title).font(.headline)
                    Picker("저장할 폴더", selection: $selectedFolderID) {
                        Text("미분류").tag(UUID?.none)
                        ForEach(library.folders) { folder in
                            Text(folder.name).tag(Optional(folder.id))
                        }
                    }
                    .pickerStyle(.inline)
                    .accessibilityIdentifier("moveFolderPicker")
                } footer: { Text("연습 내용은 유지하고 저장 위치만 바꿔요.") }
            }
            .navigationTitle("폴더 이동")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("이동") {
                        do { try library.move(plan, toFolderID: selectedFolderID); dismiss() }
                        catch { errorMessage = error.localizedDescription }
                    }
                    .accessibilityIdentifier("confirmMoveFolder")
                }
            }
            .alert("이동하지 못했어요", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}
