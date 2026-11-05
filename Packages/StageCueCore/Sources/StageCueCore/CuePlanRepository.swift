import Foundation

public enum CueStorageError: Error, LocalizedError, Equatable, Sendable {
    case invalidSavedData
    case duplicatePlan
    case duplicateFolder
    case invalidFolderName
    case missingFolder

    public var errorDescription: String? {
        switch self {
        case .invalidSavedData:
            "저장된 장면을 읽지 못했어요. 기존 파일은 그대로 보관되어 있어요."
        case .duplicatePlan:
            "중복된 장면을 확인해주세요."
        case .duplicateFolder:
            "중복된 폴더를 확인해주세요."
        case .invalidFolderName:
            "폴더 이름을 1자 이상 60자 이내로 입력해주세요."
        case .missingFolder:
            "장면을 저장할 폴더를 다시 선택해주세요."
        }
    }
}

/// Synchronous storage for a small local library. Call from one serialized owner.
public struct CuePlanRepository: Sendable {
    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent("plans.json") }

    public init(directory: URL) {
        self.directory = directory
    }

    public func load() throws -> [CuePlan] {
        try loadLibrary().plans
    }

    public func loadLibrary() throws -> CueLibrarySnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return CueLibrarySnapshot() }
        let data = try Data(contentsOf: fileURL)
        do {
            let decoder = JSONDecoder()
            let snapshot: CueLibrarySnapshot
            if let current = try? decoder.decode(CueLibrarySnapshot.self, from: data) {
                snapshot = current
            } else {
                // Version one stored a plan array without folders.
                snapshot = CueLibrarySnapshot(plans: try decoder.decode([CuePlan].self, from: data))
            }
            try validateLibrary(snapshot)
            return snapshot
        } catch {
            // Do not replace a damaged file with an empty library.
            throw CueStorageError.invalidSavedData
        }
    }

    public func save(_ plans: [CuePlan]) throws {
        var snapshot = try loadLibrary()
        snapshot.plans = plans
        try saveLibrary(snapshot)
    }

    public func saveLibrary(_ snapshot: CueLibrarySnapshot) throws {
        try validateLibrary(snapshot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    private func validateLibrary(_ snapshot: CueLibrarySnapshot) throws {
        let folderIDs = Set(snapshot.folders.map(\.id))
        guard folderIDs.count == snapshot.folders.count else { throw CueStorageError.duplicateFolder }
        for folder in snapshot.folders {
            guard !folder.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  folder.name.count <= 60 else { throw CueStorageError.invalidFolderName }
        }
        guard Set(snapshot.plans.map(\.id)).count == snapshot.plans.count else {
            throw CueStorageError.duplicatePlan
        }
        for plan in snapshot.plans {
            if let folderID = plan.folderID, !folderIDs.contains(folderID) {
                throw CueStorageError.missingFolder
            }
            try CueValidation.validate(
                title: plan.title,
                originalInstruction: plan.originalInstruction,
                steps: plan.steps
            )
        }
    }
}
