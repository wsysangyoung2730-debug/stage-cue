import SwiftUI
import StageCueCore

private enum LibraryTab: Hashable {
    case home, folders
}

struct LibraryView: View {
    @State private var selectedTab = LibraryTab.home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("홈", systemImage: "house", value: LibraryTab.home) {
                HomeView { selectedTab = .folders }
            }
            Tab("연습 폴더", systemImage: "folder", value: LibraryTab.folders) {
                PracticeFoldersView()
            }
        }
    }
}

private enum HomePlanChoice: Hashable {
    case sample
    case saved(UUID)
}

private struct HomeRehearsalDestination: Hashable {
    let id = UUID()
    let plan: CuePlan

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private struct HomeView: View {
    @Environment(CueLibrary.self) private var library
    @State private var showComposer = false
    @State private var showSettings = false
    @State private var showPlanPicker = false
    @State private var rehearsal: HomeRehearsalDestination?
    @State private var choice: HomePlanChoice?
    @State private var sample = CuePlan.sample
    let showFolders: () -> Void

    private var recentPlans: [CuePlan] {
        library.plans.sorted { $0.createdAt > $1.createdAt }
    }

    private var selectedPlan: CuePlan {
        switch choice {
        case .sample: return sample
        case .saved(let id):
            return library.plans.first { $0.id == id } ?? recentPlans.first ?? sample
        case nil: return recentPlans.first ?? sample
        }
    }

    private var selectedChoice: HomePlanChoice {
        selectedPlan.id == sample.id ? .sample : .saved(selectedPlan.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("오늘의 무대 안내")
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("예술가의 움직임을 보여, 한발짝씩 함께해요")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 4)

                    if let error = library.loadError {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(error).font(.subheadline).foregroundStyle(.secondary)
                                Button("다시 불러오기") { library.reload() }
                            }
                        } label: { Label("저장소 확인", systemImage: "exclamationmark.circle") }
                    }

                    VStack(spacing: 16) {
                        selectedPlanCard
                        Button {
                            rehearsal = HomeRehearsalDestination(plan: selectedPlan)
                        } label: {
                            Label("안내 시작", systemImage: "speaker.wave.2.fill")
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 20))
                        .controlSize(.large)
                        .accessibilityIdentifier("startGuidance")
                        .accessibilityHint("선택한 연습의 단계 안내를 엽니다")
                    }

                    Button { showComposer = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "doc.badge.plus")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 48, height: 48)
                                .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("새 연습 만들기").font(.headline).foregroundStyle(.primary)
                                Text("AI로 지시를 짧은 단계로 정리해요")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
                        .contentShape(RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("createPlan")

                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("무대 한마디")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("설정", systemImage: "gearshape") { showSettings = true }
                }
            }
            .navigationDestination(item: $rehearsal) { destination in
                RehearsalView(plan: destination.plan)
            }
            .sheet(isPresented: $showComposer) { CueEditorView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPlanPicker) {
                HomePlanPicker(selected: selectedChoice) { selected in
                    choice = selected
                    showPlanPicker = false
                }
            }
        }
    }

    private var selectedPlanCard: some View {
        VStack(spacing: 0) {
            Image("StageHero")
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .clipped()
                .accessibilityHidden(true)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("선택한 연습").font(.caption).foregroundStyle(.secondary)
                    Text(selectedPlan.title)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("selectedPlanTitle")
                    Text(detail(for: selectedPlan))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button { showPlanPicker = true } label: {
                    Label("변경", systemImage: "chevron.up.chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .fixedSize()
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.regular)
                .accessibilityIdentifier("changePlan")
                .accessibilityLabel("연습 변경")
            }
            .padding(18)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.045), radius: 12, y: 4)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("최근 연습").font(.title3.bold()).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("전체 보기", action: showFolders)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("allPracticeFolders")
            }
            .padding(.horizontal, 4)

            if recentPlans.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "folder.badge.plus")
                        .font(.title2).foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("첫 연습을 준비해볼까요?").font(.subheadline.weight(.semibold))
                        Text("저장한 연습을 여기서 바로 시작해요.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentPlans.prefix(3).enumerated()), id: \.element.id) { index, plan in
                        if index > 0 { Divider().padding(.leading, 76) }
                        Button { rehearsal = HomeRehearsalDestination(plan: plan) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "text.bubble.fill")
                                    .font(.title2).foregroundStyle(Color.accentColor)
                                    .frame(width: 46, height: 46)
                                    .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plan.title).font(.headline).foregroundStyle(.primary)
                                    Text(detail(for: plan)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recentPlan-\(plan.id.uuidString)")
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private func detail(for plan: CuePlan) -> String {
        let folder = plan.id == sample.id ? "예시" : library.folders.first { $0.id == plan.folderID }?.name ?? "미분류"
        return "\(folder) · \(plan.steps.count)단계"
    }
}

private struct HomePlanPicker: View {
    @Environment(CueLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    let selected: HomePlanChoice
    let select: (HomePlanChoice) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("저장한 연습") {
                    if library.plans.isEmpty {
                        Text("새 연습을 만들면 여기에 표시돼요.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(library.plans.sorted { $0.createdAt > $1.createdAt }) { plan in
                        let folder = library.folders.first { $0.id == plan.folderID }?.name ?? "미분류"
                        choiceRow(title: plan.title, detail: "\(folder) · \(plan.steps.count)단계", choice: .saved(plan.id))
                            .accessibilityIdentifier("choosePlan-\(plan.id.uuidString)")
                    }
                }
                Section {
                    choiceRow(title: "무대 입장", detail: "예시 · 4단계", choice: .sample)
                        .accessibilityIdentifier("chooseSamplePlan")
                } header: { Text("예시 연습") }
                footer: { Text("예시로 단계 안내와 빠른 말하기를 사용해보세요.") }
            }
            .navigationTitle("연습 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func choiceRow(title: String, detail: String, choice: HomePlanChoice) -> some View {
        Button { select(choice) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if selected == choice {
                    Image(systemName: "checkmark").fontWeight(.semibold)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected == choice ? .isSelected : [])
    }
}

private struct PracticeFoldersView: View {
    @Environment(CueLibrary.self) private var library
    @State private var showFolders = false

    var body: some View {
        NavigationStack {
            List {
                if let error = library.loadError {
                    Section("저장소 확인") {
                        Text(error).foregroundStyle(.red)
                        Button("다시 불러오기") { library.reload() }
                    }
                }
                Section {
                    ForEach(library.folders) { folder in
                        NavigationLink { FolderContentsView(folderID: folder.id) } label: {
                            Label {
                                HStack {
                                    Text(folder.name)
                                    Spacer()
                                    Text("\(library.plans.filter { $0.folderID == folder.id }.count)")
                                        .foregroundStyle(.secondary)
                                }
                            } icon: { Image(systemName: "folder.fill").foregroundStyle(Color.accentColor) }
                        }
                    }
                    NavigationLink { FolderContentsView(folderID: nil) } label: {
                        Label {
                            HStack {
                                Text("미분류")
                                Spacer()
                                Text("\(library.plans.filter { $0.folderID == nil }.count)").foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "tray").foregroundStyle(Color.accentColor) }
                    }
                    Button("폴더 관리", systemImage: "folder.badge.plus") { showFolders = true }
                        .accessibilityIdentifier("manageFolders")
                } header: { Text("내 연습 폴더") }
                footer: { Text("공연별로 폴더를 만들어 장면을 미리 저장해두세요.") }
            }
            .navigationTitle("연습 폴더")
            .sheet(isPresented: $showFolders) { FolderManagerView() }
        }
    }
}
