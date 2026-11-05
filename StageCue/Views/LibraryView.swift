import SwiftUI
import StageCueCore

struct LibraryView: View {
    @Environment(CueLibrary.self) private var library
    @State private var showComposer = false
    @State private var showSettings = false
    @State private var showFolders = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("AI로 풀어 듣는 무대 지시", systemImage: "quote.bubble.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        Text("한 동작씩,\n천천히 연습해요.")
                            .font(.largeTitle.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Text("지시를 정리하고 확인한 뒤, 소리로 들어보세요.")
                            .foregroundStyle(.secondary)
                        Button { showComposer = true } label: {
                            Label("새 연습 만들기", systemImage: "plus")
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("createPlan")
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 12, trailing: 4))

                if let error = library.loadError {
                    Section("저장소 확인") {
                        Text(error).foregroundStyle(.red)
                        Button("다시 불러오기") { library.reload() }
                    }
                }

                Section {
                    NavigationLink {
                        RehearsalView(plan: .sample)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("무대 입장 연습해보기").font(.headline)
                                Text("예시 · 4단계").font(.subheadline).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "play.circle.fill").font(.title).foregroundStyle(Color.accentColor)
                        }
                        .padding(.vertical, 6)
                    }
                    .accessibilityIdentifier("samplePlan")
                } header: { Text("먼저 들어보세요") }
                footer: { Text("미리 작성한 예시로 연습 방식을 살펴볼 수 있어요.") }

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
            .navigationTitle("무대 한마디")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("설정", systemImage: "gearshape") { showSettings = true }
                }
            }
            .sheet(isPresented: $showComposer) { CueEditorView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showFolders) { FolderManagerView() }

        }
    }
}
