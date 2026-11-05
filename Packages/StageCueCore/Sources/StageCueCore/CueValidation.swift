import Foundation

public enum CueValidationError: Error, LocalizedError, Equatable, Sendable {
    case emptyTitle
    case titleTooLong
    case emptyOriginalInstruction
    case originalInstructionTooLong
    case emptySteps
    case tooManySteps
    case emptyStep(Int)
    case stepTooLong(Int)
    case duplicateStep

    public var errorDescription: String? {
        switch self {
        case .emptyTitle: "장면 이름을 입력해주세요."
        case .titleTooLong: "장면 이름은 60자 이내로 입력해주세요."
        case .emptyOriginalInstruction: "원래 무대 지시를 입력해주세요."
        case .originalInstructionTooLong: "무대 지시는 2,000자 이내로 입력해주세요."
        case .emptySteps: "안내 단계를 한 개 이상 추가해주세요."
        case .tooManySteps: "한 장면에는 안내 단계를 20개까지 저장할 수 있어요."
        case let .emptyStep(number): "\(number)번째 안내 내용을 입력해주세요."
        case let .stepTooLong(number): "\(number)번째 안내는 300자 이내로 입력해주세요."
        case .duplicateStep: "중복된 안내 단계를 확인해주세요."
        }
    }
}

public enum CueValidation {
    public static let maximumTitleLength = 60
    public static let maximumOriginalLength = 2_000
    public static let maximumStepLength = 300
    public static let maximumStepCount = 20

    public static func validate(title: String, originalInstruction: String, steps: [CueStep]) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOriginal = originalInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw CueValidationError.emptyTitle }
        guard title.count <= maximumTitleLength else { throw CueValidationError.titleTooLong }
        guard !cleanOriginal.isEmpty else { throw CueValidationError.emptyOriginalInstruction }
        guard originalInstruction.count <= maximumOriginalLength else {
            throw CueValidationError.originalInstructionTooLong
        }
        guard !steps.isEmpty else { throw CueValidationError.emptySteps }
        guard steps.count <= maximumStepCount else { throw CueValidationError.tooManySteps }
        guard Set(steps.map(\.id)).count == steps.count else { throw CueValidationError.duplicateStep }
        for (index, step) in steps.enumerated() {
            guard !step.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CueValidationError.emptyStep(index + 1)
            }
            guard step.instruction.count <= maximumStepLength else {
                throw CueValidationError.stepTooLong(index + 1)
            }
        }
    }
}
