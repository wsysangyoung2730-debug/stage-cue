import Foundation

public struct CueStep: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var instruction: String

    public init(id: UUID = UUID(), instruction: String) {
        self.id = id
        self.instruction = instruction
    }
}

public enum CueSource: String, Codable, Sendable {
    case ai
    case manual
    case sample
}

/// A plan saved after a helper has reviewed its instructions.
public struct CuePlan: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var originalInstruction: String
    public var steps: [CueStep]
    public var source: CueSource
    public var createdAt: Date
    public var folderID: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        originalInstruction: String,
        steps: [CueStep],
        source: CueSource,
        createdAt: Date = Date(),
        folderID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.originalInstruction = originalInstruction
        self.steps = steps
        self.source = source
        self.createdAt = createdAt
        self.folderID = folderID
    }

    public static var sample: CuePlan {
        CuePlan(
            title: "무대 입장",
            originalInstruction: "오른쪽으로 돌아 세 걸음 이동한 다음, 관객을 보고 대사를 시작하세요.",
            steps: [
                CueStep(instruction: "오른쪽으로 돌아주세요."),
                CueStep(instruction: "세 걸음 이동하세요."),
                CueStep(instruction: "관객 쪽을 바라보세요."),
                CueStep(instruction: "대사를 시작하세요.")
            ],
            source: .sample
        )
    }
}
