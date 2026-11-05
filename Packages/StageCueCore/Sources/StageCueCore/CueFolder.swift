import Foundation

public struct CueFolder: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public struct CueLibrarySnapshot: Codable, Equatable, Sendable {
    public var folders: [CueFolder]
    public var plans: [CuePlan]

    public init(folders: [CueFolder] = [], plans: [CuePlan] = []) {
        self.folders = folders
        self.plans = plans
    }
}
