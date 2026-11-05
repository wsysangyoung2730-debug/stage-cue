import Foundation
import Testing
@testable import StageCueCore

@Test func sampleIsValid() throws {
    let plan = CuePlan.sample
    try CueValidation.validate(title: plan.title, originalInstruction: plan.originalInstruction, steps: plan.steps)
    #expect(plan.steps.count == 4)
    #expect(plan.source == .sample)
}

@Test func validationRejectsEmptyValues() {
    let steps = [CueStep(instruction: "이동하세요.")]
    #expect(throws: CueValidationError.emptyTitle) {
        try CueValidation.validate(title: " \n ", originalInstruction: "이동", steps: steps)
    }
    #expect(throws: CueValidationError.emptyOriginalInstruction) {
        try CueValidation.validate(title: "장면", originalInstruction: " \n ", steps: steps)
    }
    #expect(throws: CueValidationError.emptySteps) {
        try CueValidation.validate(title: "장면", originalInstruction: "이동", steps: [])
    }
    #expect(throws: CueValidationError.emptyStep(2)) {
        try CueValidation.validate(title: "장면", originalInstruction: "이동", steps: steps + [CueStep(instruction: "\n")])
    }
}

@Test func acceptsExactCharacterAndCountLimits() throws {
    let steps = (0..<20).map { _ in CueStep(instruction: String(repeating: "가", count: 300)) }
    try CueValidation.validate(
        title: String(repeating: "가", count: 60),
        originalInstruction: String(repeating: "가", count: 2_000),
        steps: steps
    )
}

@Test func rejectsValuesBeyondLimits() {
    let step = CueStep(instruction: "이동하세요.")
    #expect(throws: CueValidationError.titleTooLong) {
        try CueValidation.validate(title: String(repeating: "가", count: 61), originalInstruction: "이동", steps: [step])
    }
    #expect(throws: CueValidationError.originalInstructionTooLong) {
        try CueValidation.validate(title: "장면", originalInstruction: String(repeating: "가", count: 2_001), steps: [step])
    }
    #expect(throws: CueValidationError.tooManySteps) {
        try CueValidation.validate(title: "장면", originalInstruction: "이동", steps: (0..<21).map { _ in CueStep(instruction: "이동") })
    }
    #expect(throws: CueValidationError.stepTooLong(1)) {
        try CueValidation.validate(title: "장면", originalInstruction: "이동", steps: [CueStep(instruction: String(repeating: "가", count: 301))])
    }
    #expect(throws: CueValidationError.duplicateStep) {
        try CueValidation.validate(title: "장면", originalInstruction: "이동", steps: [step, step])
    }
}

@Test func progressesOnlyWhenExplicitlyAdvanced() {
    var progress = RehearsalProgress(stepCount: 3)
    #expect(progress.currentIndex == 0)
    #expect(!progress.isComplete)
    progress.goBack()
    #expect(progress.currentIndex == 0)
    progress.advance()
    #expect(progress.currentIndex == 1)
    progress.advance()
    #expect(progress.currentIndex == 2)
    #expect(!progress.isComplete)
    progress.advance()
    #expect(progress.isComplete)
    #expect(progress.currentIndex == 2)
    progress.advance()
    #expect(progress.currentIndex == 2)
    progress.goBack()
    #expect(!progress.isComplete)
    #expect(progress.currentIndex == 2)
    progress.goBack()
    #expect(progress.currentIndex == 1)
    progress.restart()
    #expect(progress.currentIndex == 0)
    #expect(!progress.isComplete)
}

@Test(arguments: [0, -1, Int.min]) func noStepsNeverProducesInvalidIndex(count: Int) {
    var progress = RehearsalProgress(stepCount: count)
    #expect(progress.stepCount == 0)
    #expect(progress.currentIndex == 0)
    #expect(progress.isComplete)
    progress.advance()
    progress.goBack()
    progress.restart()
    #expect(progress.currentIndex == 0)
    #expect(progress.isComplete)
}

@Test func singleStepCompletesAndRestarts() {
    var progress = RehearsalProgress(stepCount: 1)
    progress.advance()
    #expect(progress.isComplete)
    progress.restart()
    #expect(!progress.isComplete)
    #expect(progress.currentIndex == 0)
}

@Test func repositoryRoundTripPreservesOrderAndIDs() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = CuePlanRepository(directory: directory)
    #expect(try repository.load().isEmpty)
    var second = CuePlan.sample
    second.title = "다음 장면"
    let plans = [CuePlan.sample, second]
    try repository.save(plans)
    #expect(try repository.load() == plans)
    try repository.save([second])
    #expect(try repository.load() == [second])
    try repository.save([])
    #expect(try repository.load().isEmpty)
}

@Test func corruptFileIsReportedAndPreserved() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = CuePlanRepository(directory: directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let corruptData = Data("{broken".utf8)
    try corruptData.write(to: repository.fileURL)
    #expect(throws: CueStorageError.self) { try repository.load() }
    #expect(try Data(contentsOf: repository.fileURL) == corruptData)
}

@Test func invalidSaveDoesNotOverwriteExistingLibrary() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = CuePlanRepository(directory: directory)
    let plan = CuePlan.sample
    try repository.save([plan])
    var invalid = plan
    invalid.steps = []
    #expect(throws: CueValidationError.emptySteps) { try repository.save([invalid]) }
    #expect(try repository.load() == [plan])
    #expect(throws: CueStorageError.self) { try repository.save([plan, plan]) }
    #expect(try repository.load() == [plan])
}

@Test func semanticallyInvalidSavedFileIsReported() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = CuePlanRepository(directory: directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var invalid = CuePlan.sample
    invalid.steps = []
    let data = try JSONEncoder().encode([invalid])
    try data.write(to: repository.fileURL)
    #expect(throws: CueStorageError.self) { try repository.load() }
    #expect(try Data(contentsOf: repository.fileURL) == data)
}

@Test func folderLibraryRoundTripMoveAndDelete() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = CuePlanRepository(directory: directory)
    #expect(try repository.loadLibrary() == CueLibrarySnapshot())
    let first = CueFolder(name: "첫 공연")
    let second = CueFolder(name: "다음 공연")
    var plan = CuePlan.sample
    plan.folderID = first.id
    let original = CueLibrarySnapshot(folders: [first, second], plans: [plan])
    try repository.saveLibrary(original)
    #expect(try repository.loadLibrary() == original)
    plan.folderID = second.id
    var moved = CueLibrarySnapshot(folders: [first, second], plans: [plan])
    try repository.saveLibrary(moved)
    #expect(try repository.loadLibrary().plans.first?.folderID == second.id)
    moved.folders.removeAll { $0.id == first.id }
    try repository.saveLibrary(moved)
    #expect(try repository.loadLibrary() == moved)
    moved.plans[0].folderID = nil
    moved.folders.removeAll()
    try repository.saveLibrary(moved)
    #expect(try repository.loadLibrary() == moved)
    try repository.saveLibrary(CueLibrarySnapshot())
    #expect(try repository.loadLibrary() == CueLibrarySnapshot())
}

@Test func planOnlySavePreservesFolders() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = CuePlanRepository(directory: directory)
    let folder = CueFolder(name: "리허설")
    var plan = CuePlan.sample
    plan.folderID = folder.id
    try repository.saveLibrary(CueLibrarySnapshot(folders: [folder], plans: [plan]))
    try repository.save([])
    #expect(try repository.loadLibrary() == CueLibrarySnapshot(folders: [folder]))
    try repository.save([plan])
    #expect(try repository.load() == [plan])
}

@Test func legacyArrayWithoutFolderIDMigratesOnNextSave() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = CuePlanRepository(directory: directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let plan = CuePlan.sample
    // JSONEncoder omits a nil optional, matching the original schema.
    let legacyData = try JSONEncoder().encode([plan])
    #expect(!String(decoding: legacyData, as: UTF8.self).contains("folderID"))
    try legacyData.write(to: repository.fileURL)
    #expect(try repository.loadLibrary() == CueLibrarySnapshot(plans: [plan]))
    #expect(try Data(contentsOf: repository.fileURL) == legacyData)
    let folder = CueFolder(name: "기존 장면")
    try repository.saveLibrary(CueLibrarySnapshot(folders: [folder], plans: [plan]))
    let current = try JSONDecoder().decode(CueLibrarySnapshot.self, from: Data(contentsOf: repository.fileURL))
    #expect(current.folders == [folder])
    #expect(current.plans == [plan])
}

@Test func invalidFolderChangesCannotDestroySavedPlans() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = CuePlanRepository(directory: directory)
    let folder = CueFolder(name: "연습")
    var plan = CuePlan.sample
    plan.folderID = folder.id
    let valid = CueLibrarySnapshot(folders: [folder], plans: [plan])
    try repository.saveLibrary(valid)
    #expect(throws: CueStorageError.missingFolder) {
        try repository.saveLibrary(CueLibrarySnapshot(plans: [plan]))
    }
    #expect(throws: CueStorageError.duplicateFolder) {
        try repository.saveLibrary(CueLibrarySnapshot(folders: [folder, folder], plans: [plan]))
    }
    #expect(throws: CueStorageError.invalidFolderName) {
        try repository.saveLibrary(CueLibrarySnapshot(folders: [CueFolder(name: " \n ")]))
    }
    #expect(throws: CueStorageError.invalidFolderName) {
        try repository.saveLibrary(CueLibrarySnapshot(folders: [CueFolder(name: String(repeating: "가", count: 61))]))
    }
    #expect(try repository.loadLibrary() == valid)
    try repository.saveLibrary(CueLibrarySnapshot(folders: [CueFolder(name: String(repeating: "가", count: 60))]))
}

@Test func malformedLibraryIsReportedAndNotOverwrittenByLegacyWrapper() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = CuePlanRepository(directory: directory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var plan = CuePlan.sample
    plan.folderID = UUID()
    let invalidData = try JSONEncoder().encode(CueLibrarySnapshot(plans: [plan]))
    try invalidData.write(to: repository.fileURL)
    #expect(throws: CueStorageError.invalidSavedData) { try repository.loadLibrary() }
    #expect(throws: CueStorageError.invalidSavedData) { try repository.save([]) }
    #expect(try Data(contentsOf: repository.fileURL) == invalidData)
}
