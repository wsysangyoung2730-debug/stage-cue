import Foundation
import Observation
import StageCueCore

@MainActor @Observable
final class CueLibrary {
    private(set) var plans: [CuePlan] = []
    private(set) var folders: [CueFolder] = []
    private(set) var loadError: String?
    private let repository: CuePlanRepository

    init() {
        let directory = URL.applicationSupportDirectory.appending(path: "StageCue", directoryHint: .isDirectory)
        // UI tests use a separate directory. Never erase the user's real library.
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let location = testing
            ? URL.temporaryDirectory.appending(path: "StageCueUITests", directoryHint: .isDirectory)
            : directory
        if testing && ProcessInfo.processInfo.arguments.contains("--reset-test-data") {
            try? FileManager.default.removeItem(at: location)
        }
        repository = CuePlanRepository(directory: location)
        reload()
    }

    func reload() {
        do {
            let saved = try repository.loadLibrary()
            plans = saved.plans
            folders = saved.folders
            loadError = nil
        } catch {
            loadError = "저장한 연습을 불러오지 못했어요. 기존 데이터를 보호하기 위해 저장을 잠시 멈췄어요. \(error.localizedDescription)"
        }
    }

    private func persist(plans: [CuePlan], folders: [CueFolder]) throws {
        guard loadError == nil else { throw LibraryError.unavailable }
        try repository.saveLibrary(CueLibrarySnapshot(folders: folders, plans: plans))
        self.plans = plans
        self.folders = folders
    }

    func save(_ plan: CuePlan) throws {
        var next = plans
        if let index = next.firstIndex(where: { $0.id == plan.id }) { next[index] = plan }
        else { next.insert(plan, at: 0) }
        try persist(plans: next, folders: folders)
    }

    func delete(_ plan: CuePlan) throws {
        try persist(plans: plans.filter { $0.id != plan.id }, folders: folders)
    }

    @discardableResult func createFolder(name: String) throws -> CueFolder {
        let folder = CueFolder(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        try persist(plans: plans, folders: folders + [folder])
        return folder
    }

    func renameFolder(_ folder: CueFolder, name: String) throws {
        var next = folders
        guard let index = next.firstIndex(where: { $0.id == folder.id }) else { return }
        next[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try persist(plans: plans, folders: next)
    }

    func deleteFolder(_ folder: CueFolder) throws {
        let nextPlans = plans.map { plan in
            var next = plan
            if next.folderID == folder.id { next.folderID = nil }
            return next
        }
        try persist(plans: nextPlans, folders: folders.filter { $0.id != folder.id })
    }

    func move(_ plan: CuePlan, toFolderID folderID: UUID?) throws {
        var next = plan
        next.folderID = folderID
        try save(next)
    }

    enum LibraryError: LocalizedError {
        case unavailable
        var errorDescription: String? { "기존 연습을 다시 불러온 뒤 저장해주세요." }
    }
}
