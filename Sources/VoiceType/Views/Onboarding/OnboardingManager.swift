import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case modelSetup = 0
    case apiKey
    case shortcut
    case permissions
    case done
}

@MainActor
class OnboardingManager: ObservableObject {
    @Published var currentStep: OnboardingStep = .modelSetup
    @Published var isComplete: Bool

    static let completedKey = "onboardingComplete"

    /// Synchronous check usable before @MainActor context (e.g. in App.init)
    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    init() {
        self.isComplete = UserDefaults.standard.bool(forKey: Self.completedKey)
    }

    func advance() {
        let next = currentStep.rawValue + 1
        if let step = OnboardingStep(rawValue: next) {
            currentStep = step
        }
        if currentStep == .done {
            complete()
        }
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        isComplete = true
    }
}
