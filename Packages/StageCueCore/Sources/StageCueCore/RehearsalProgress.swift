/// Tracks explicit user advancement. It never infers that a physical action is complete.
public struct RehearsalProgress: Equatable, Sendable {
    public let stepCount: Int
    public private(set) var currentIndex: Int
    public private(set) var isComplete: Bool

    public init(stepCount: Int) {
        self.stepCount = max(0, stepCount)
        self.currentIndex = 0
        self.isComplete = stepCount <= 0
    }

    public mutating func advance() {
        guard !isComplete, stepCount > 0 else { return }
        if currentIndex + 1 < stepCount {
            currentIndex += 1
        } else {
            isComplete = true
        }
    }

    public mutating func goBack() {
        guard stepCount > 0 else { return }
        if isComplete {
            isComplete = false
        } else {
            currentIndex = max(0, currentIndex - 1)
        }
    }

    public mutating func restart() {
        currentIndex = 0
        isComplete = stepCount == 0
    }
}
