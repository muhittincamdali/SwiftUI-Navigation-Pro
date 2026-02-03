import SwiftUI
import Combine

// MARK: - Flow Step Protocol

/// A protocol representing a single step within a navigation flow.
///
/// Conform to this protocol to define the steps in your flow.
/// Each step should be a unique, identifiable state.
///
/// ```swift
/// enum OnboardingStep: FlowStep {
///     case welcome
///     case profile
///     case permissions
///     case complete
/// }
/// ```
public protocol FlowStep: Hashable, Sendable {
    /// The identifier for this step.
    var stepIdentifier: String { get }
}

public extension FlowStep where Self: RawRepresentable, RawValue == String {
    var stepIdentifier: String { rawValue }
}

public extension FlowStep {
    var stepIdentifier: String { String(describing: self) }
}

// MARK: - Flow Direction

/// The direction of navigation within a flow.
public enum FlowDirection: Sendable {
    /// Moving forward to the next step.
    case forward
    /// Moving backward to the previous step.
    case backward
    /// Jumping to a specific step.
    case jump
    /// Restarting the flow from the beginning.
    case restart
}

// MARK: - Flow Event

/// Events that occur during flow navigation.
public enum FlowEvent<Step: FlowStep>: Sendable {
    /// The flow has started at the initial step.
    case flowStarted(step: Step)
    /// The flow moved to a new step.
    case stepChanged(from: Step?, to: Step, direction: FlowDirection)
    /// The flow was completed.
    case flowCompleted(finalStep: Step)
    /// The flow was cancelled.
    case flowCancelled(atStep: Step)
    /// The flow was reset.
    case flowReset
    /// A validation error occurred at a step.
    case validationFailed(step: Step, error: Error)
}

// MARK: - Flow State

/// The current state of a navigation flow.
public struct FlowState<Step: FlowStep>: Sendable {
    /// The current step in the flow.
    public let currentStep: Step
    /// The index of the current step.
    public let currentIndex: Int
    /// The total number of steps.
    public let totalSteps: Int
    /// The history of visited steps.
    public let history: [Step]
    /// Whether the flow can move forward.
    public let canMoveForward: Bool
    /// Whether the flow can move backward.
    public let canMoveBackward: Bool
    /// The progress through the flow (0.0 to 1.0).
    public var progress: Double {
        guard totalSteps > 1 else { return 1.0 }
        return Double(currentIndex) / Double(totalSteps - 1)
    }
    
    /// Creates a new flow state.
    public init(
        currentStep: Step,
        currentIndex: Int,
        totalSteps: Int,
        history: [Step],
        canMoveForward: Bool,
        canMoveBackward: Bool
    ) {
        self.currentStep = currentStep
        self.currentIndex = currentIndex
        self.totalSteps = totalSteps
        self.history = history
        self.canMoveForward = canMoveForward
        self.canMoveBackward = canMoveBackward
    }
}

// MARK: - Step Validator

/// A validator that determines whether a step can be completed.
public struct StepValidator<Step: FlowStep>: Sendable {
    /// The validation closure.
    private let validate: @Sendable (Step) async throws -> Bool
    
    /// Creates a validator with a synchronous validation closure.
    public init(_ validate: @escaping @Sendable (Step) -> Bool) {
        self.validate = { step in validate(step) }
    }
    
    /// Creates a validator with an async validation closure.
    public init(async validate: @escaping @Sendable (Step) async throws -> Bool) {
        self.validate = validate
    }
    
    /// Validates the given step.
    public func canComplete(_ step: Step) async throws -> Bool {
        try await validate(step)
    }
}

// MARK: - Step Transition

/// Defines a transition between two steps.
public struct StepTransition<Step: FlowStep>: Sendable {
    /// The source step.
    public let from: Step
    /// The destination step.
    public let to: Step
    /// The transition animation.
    public let animation: Animation?
    /// Custom transition effect.
    public let transition: AnyTransition?
    
    /// Creates a step transition.
    public init(
        from: Step,
        to: Step,
        animation: Animation? = .easeInOut(duration: 0.3),
        transition: AnyTransition? = nil
    ) {
        self.from = from
        self.to = to
        self.animation = animation
        self.transition = transition
    }
}

// MARK: - Flow Configuration

/// Configuration options for a flow coordinator.
public struct FlowConfiguration<Step: FlowStep>: Sendable {
    /// The ordered list of steps in the flow.
    public let steps: [Step]
    /// The initial step (defaults to first step).
    public let initialStep: Step?
    /// Whether to allow skipping steps.
    public let allowSkipping: Bool
    /// Whether to allow going back.
    public let allowBackNavigation: Bool
    /// Whether to persist flow state.
    public let persistState: Bool
    /// The storage key for persisted state.
    public let persistenceKey: String?
    /// The default animation for transitions.
    public let defaultAnimation: Animation
    /// Whether to validate before moving forward.
    public let validateOnForward: Bool
    
    /// Creates a flow configuration.
    public init(
        steps: [Step],
        initialStep: Step? = nil,
        allowSkipping: Bool = false,
        allowBackNavigation: Bool = true,
        persistState: Bool = false,
        persistenceKey: String? = nil,
        defaultAnimation: Animation = .easeInOut(duration: 0.3),
        validateOnForward: Bool = true
    ) {
        self.steps = steps
        self.initialStep = initialStep
        self.allowSkipping = allowSkipping
        self.allowBackNavigation = allowBackNavigation
        self.persistState = persistState
        self.persistenceKey = persistenceKey
        self.defaultAnimation = defaultAnimation
        self.validateOnForward = validateOnForward
    }
}

// MARK: - Flow Coordinator

/// A coordinator that manages multi-step navigation flows.
///
/// `FlowCoordinator` provides a structured way to handle sequential
/// navigation patterns like onboarding, wizards, or checkout flows.
///
/// ```swift
/// @StateObject private var flow = FlowCoordinator(
///     configuration: .init(steps: [
///         .welcome,
///         .profile,
///         .permissions,
///         .complete
///     ])
/// )
///
/// var body: some View {
///     FlowView(coordinator: flow) { step in
///         switch step {
///         case .welcome: WelcomeView()
///         case .profile: ProfileView()
///         case .permissions: PermissionsView()
///         case .complete: CompleteView()
///         }
///     }
/// }
/// ```
@MainActor
public final class FlowCoordinator<Step: FlowStep>: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The current step in the flow.
    @Published public private(set) var currentStep: Step
    
    /// The index of the current step.
    @Published public private(set) var currentIndex: Int = 0
    
    /// The history of visited steps.
    @Published public private(set) var history: [Step] = []
    
    /// Whether the flow is currently transitioning.
    @Published public private(set) var isTransitioning: Bool = false
    
    /// The most recent error that occurred.
    @Published public private(set) var lastError: Error?
    
    /// Whether the flow has been completed.
    @Published public private(set) var isCompleted: Bool = false
    
    /// Whether the flow has been cancelled.
    @Published public private(set) var isCancelled: Bool = false
    
    // MARK: - Properties
    
    /// The flow configuration.
    public let configuration: FlowConfiguration<Step>
    
    /// Step validators.
    private var validators: [Step: StepValidator<Step>] = [:]
    
    /// Custom transitions between steps.
    private var transitions: [String: StepTransition<Step>] = [:]
    
    /// The event publisher.
    private let eventSubject = PassthroughSubject<FlowEvent<Step>, Never>()
    
    /// Publisher for flow events.
    public var events: AnyPublisher<FlowEvent<Step>, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Data associated with each step.
    private var stepData: [Step: Any] = [:]
    
    /// Cancellables for subscriptions.
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// The total number of steps in the flow.
    public var totalSteps: Int { configuration.steps.count }
    
    /// Whether the flow can move forward.
    public var canMoveForward: Bool {
        currentIndex < totalSteps - 1 && !isTransitioning
    }
    
    /// Whether the flow can move backward.
    public var canMoveBackward: Bool {
        configuration.allowBackNavigation && currentIndex > 0 && !isTransitioning
    }
    
    /// The progress through the flow (0.0 to 1.0).
    public var progress: Double {
        guard totalSteps > 1 else { return 1.0 }
        return Double(currentIndex) / Double(totalSteps - 1)
    }
    
    /// The current flow state.
    public var state: FlowState<Step> {
        FlowState(
            currentStep: currentStep,
            currentIndex: currentIndex,
            totalSteps: totalSteps,
            history: history,
            canMoveForward: canMoveForward,
            canMoveBackward: canMoveBackward
        )
    }
    
    /// Whether this is the first step.
    public var isFirstStep: Bool { currentIndex == 0 }
    
    /// Whether this is the last step.
    public var isLastStep: Bool { currentIndex == totalSteps - 1 }
    
    /// The next step, if available.
    public var nextStep: Step? {
        guard canMoveForward else { return nil }
        return configuration.steps[currentIndex + 1]
    }
    
    /// The previous step, if available.
    public var previousStep: Step? {
        guard currentIndex > 0 else { return nil }
        return configuration.steps[currentIndex - 1]
    }
    
    // MARK: - Initialization
    
    /// Creates a flow coordinator with the given configuration.
    ///
    /// - Parameter configuration: The flow configuration.
    public init(configuration: FlowConfiguration<Step>) {
        precondition(!configuration.steps.isEmpty, "Flow must have at least one step")
        
        self.configuration = configuration
        self.currentStep = configuration.initialStep ?? configuration.steps[0]
        
        if let initial = configuration.initialStep,
           let index = configuration.steps.firstIndex(of: initial) {
            self.currentIndex = index
        }
        
        self.history = [currentStep]
        
        if configuration.persistState {
            restoreState()
        }
        
        eventSubject.send(.flowStarted(step: currentStep))
    }
    
    /// Creates a flow coordinator with a simple list of steps.
    ///
    /// - Parameter steps: The ordered steps in the flow.
    public convenience init(steps: [Step]) {
        self.init(configuration: FlowConfiguration(steps: steps))
    }
    
    // MARK: - Navigation
    
    /// Moves to the next step in the flow.
    ///
    /// - Parameter animation: Optional custom animation.
    /// - Returns: Whether the navigation was successful.
    @discardableResult
    public func next(animation: Animation? = nil) async -> Bool {
        guard canMoveForward else { return false }
        
        if configuration.validateOnForward {
            do {
                guard try await validateCurrentStep() else {
                    return false
                }
            } catch {
                lastError = error
                eventSubject.send(.validationFailed(step: currentStep, error: error))
                return false
            }
        }
        
        let nextIndex = currentIndex + 1
        let nextStep = configuration.steps[nextIndex]
        
        await transition(to: nextStep, at: nextIndex, direction: .forward, animation: animation)
        return true
    }
    
    /// Moves to the previous step in the flow.
    ///
    /// - Parameter animation: Optional custom animation.
    /// - Returns: Whether the navigation was successful.
    @discardableResult
    public func previous(animation: Animation? = nil) async -> Bool {
        guard canMoveBackward else { return false }
        
        let prevIndex = currentIndex - 1
        let prevStep = configuration.steps[prevIndex]
        
        await transition(to: prevStep, at: prevIndex, direction: .backward, animation: animation)
        return true
    }
    
    /// Jumps to a specific step in the flow.
    ///
    /// - Parameters:
    ///   - step: The step to jump to.
    ///   - animation: Optional custom animation.
    /// - Returns: Whether the navigation was successful.
    @discardableResult
    public func jump(to step: Step, animation: Animation? = nil) async -> Bool {
        guard let index = configuration.steps.firstIndex(of: step) else { return false }
        guard step != currentStep else { return false }
        
        if !configuration.allowSkipping && index > currentIndex + 1 {
            return false
        }
        
        await transition(to: step, at: index, direction: .jump, animation: animation)
        return true
    }
    
    /// Restarts the flow from the beginning.
    ///
    /// - Parameter animation: Optional custom animation.
    public func restart(animation: Animation? = nil) async {
        let firstStep = configuration.steps[0]
        history = []
        stepData = [:]
        isCompleted = false
        isCancelled = false
        lastError = nil
        
        await transition(to: firstStep, at: 0, direction: .restart, animation: animation)
        eventSubject.send(.flowReset)
    }
    
    /// Completes the flow.
    public func complete() {
        guard !isCompleted else { return }
        isCompleted = true
        eventSubject.send(.flowCompleted(finalStep: currentStep))
        
        if configuration.persistState {
            clearPersistedState()
        }
    }
    
    /// Cancels the flow.
    public func cancel() {
        guard !isCancelled else { return }
        isCancelled = true
        eventSubject.send(.flowCancelled(atStep: currentStep))
        
        if configuration.persistState {
            clearPersistedState()
        }
    }
    
    // MARK: - Validation
    
    /// Registers a validator for a specific step.
    ///
    /// - Parameters:
    ///   - step: The step to validate.
    ///   - validator: The validator to use.
    public func registerValidator(for step: Step, validator: StepValidator<Step>) {
        validators[step] = validator
    }
    
    /// Registers a simple validation closure for a step.
    ///
    /// - Parameters:
    ///   - step: The step to validate.
    ///   - validate: The validation closure.
    public func registerValidator(for step: Step, validate: @escaping @Sendable (Step) -> Bool) {
        validators[step] = StepValidator(validate)
    }
    
    /// Validates the current step.
    ///
    /// - Returns: Whether the step is valid.
    public func validateCurrentStep() async throws -> Bool {
        guard let validator = validators[currentStep] else { return true }
        return try await validator.canComplete(currentStep)
    }
    
    // MARK: - Step Data
    
    /// Sets data for a specific step.
    ///
    /// - Parameters:
    ///   - data: The data to store.
    ///   - step: The step to associate the data with.
    public func setData<T>(_ data: T, for step: Step) {
        stepData[step] = data
    }
    
    /// Gets data for a specific step.
    ///
    /// - Parameters:
    ///   - type: The type of data to retrieve.
    ///   - step: The step to get data for.
    /// - Returns: The data, if available.
    public func getData<T>(_ type: T.Type, for step: Step) -> T? {
        stepData[step] as? T
    }
    
    /// Clears data for a specific step.
    ///
    /// - Parameter step: The step to clear data for.
    public func clearData(for step: Step) {
        stepData.removeValue(forKey: step)
    }
    
    /// Clears all step data.
    public func clearAllData() {
        stepData.removeAll()
    }
    
    // MARK: - Transitions
    
    /// Registers a custom transition between two steps.
    ///
    /// - Parameter transition: The transition definition.
    public func registerTransition(_ transition: StepTransition<Step>) {
        let key = transitionKey(from: transition.from, to: transition.to)
        transitions[key] = transition
    }
    
    // MARK: - Private Methods
    
    private func transition(
        to step: Step,
        at index: Int,
        direction: FlowDirection,
        animation: Animation?
    ) async {
        isTransitioning = true
        
        let fromStep = currentStep
        let effectiveAnimation = animation ?? getTransitionAnimation(from: fromStep, to: step)
        
        withAnimation(effectiveAnimation) {
            currentStep = step
            currentIndex = index
        }
        
        history.append(step)
        eventSubject.send(.stepChanged(from: fromStep, to: step, direction: direction))
        
        if configuration.persistState {
            persistState()
        }
        
        try? await Task.sleep(nanoseconds: 300_000_000)
        isTransitioning = false
    }
    
    private func transitionKey(from: Step, to: Step) -> String {
        "\(from.stepIdentifier)->\(to.stepIdentifier)"
    }
    
    private func getTransitionAnimation(from: Step, to: Step) -> Animation {
        let key = transitionKey(from: from, to: to)
        return transitions[key]?.animation ?? configuration.defaultAnimation
    }
    
    private func persistState() {
        guard let key = configuration.persistenceKey else { return }
        let data: [String: Any] = [
            "currentIndex": currentIndex,
            "historyCount": history.count
        ]
        UserDefaults.standard.set(data, forKey: key)
    }
    
    private func restoreState() {
        guard let key = configuration.persistenceKey,
              let data = UserDefaults.standard.dictionary(forKey: key),
              let index = data["currentIndex"] as? Int,
              index < totalSteps else { return }
        
        currentIndex = index
        currentStep = configuration.steps[index]
    }
    
    private func clearPersistedState() {
        guard let key = configuration.persistenceKey else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Flow View

/// A view that displays the current step in a flow.
public struct FlowView<Step: FlowStep, Content: View>: View {
    @ObservedObject private var coordinator: FlowCoordinator<Step>
    private let content: (Step) -> Content
    
    /// Creates a flow view.
    ///
    /// - Parameters:
    ///   - coordinator: The flow coordinator.
    ///   - content: A view builder for each step.
    public init(
        coordinator: FlowCoordinator<Step>,
        @ViewBuilder content: @escaping (Step) -> Content
    ) {
        self.coordinator = coordinator
        self.content = content
    }
    
    public var body: some View {
        content(coordinator.currentStep)
            .id(coordinator.currentStep.stepIdentifier)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
    }
}

// MARK: - Flow Progress View

/// A view that displays the progress through a flow.
public struct FlowProgressView<Step: FlowStep>: View {
    @ObservedObject private var coordinator: FlowCoordinator<Step>
    private let tintColor: Color
    private let backgroundColor: Color
    private let height: CGFloat
    private let showStepIndicators: Bool
    
    /// Creates a flow progress view.
    ///
    /// - Parameters:
    ///   - coordinator: The flow coordinator.
    ///   - tintColor: The progress bar color.
    ///   - backgroundColor: The background color.
    ///   - height: The height of the progress bar.
    ///   - showStepIndicators: Whether to show step indicators.
    public init(
        coordinator: FlowCoordinator<Step>,
        tintColor: Color = .blue,
        backgroundColor: Color = .gray.opacity(0.3),
        height: CGFloat = 4,
        showStepIndicators: Bool = false
    ) {
        self.coordinator = coordinator
        self.tintColor = tintColor
        self.backgroundColor = backgroundColor
        self.height = height
        self.showStepIndicators = showStepIndicators
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(backgroundColor)
                
                Rectangle()
                    .fill(tintColor)
                    .frame(width: geometry.size.width * coordinator.progress)
                    .animation(.easeInOut(duration: 0.3), value: coordinator.progress)
                
                if showStepIndicators {
                    HStack(spacing: 0) {
                        ForEach(0..<coordinator.totalSteps, id: \.self) { index in
                            Circle()
                                .fill(index <= coordinator.currentIndex ? tintColor : backgroundColor)
                                .frame(width: height * 2, height: height * 2)
                            
                            if index < coordinator.totalSteps - 1 {
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, height)
                }
            }
        }
        .frame(height: showStepIndicators ? height * 2 : height)
        .clipShape(Capsule())
    }
}

// MARK: - Flow Navigation Bar

/// A navigation bar for flow navigation.
public struct FlowNavigationBar<Step: FlowStep>: View {
    @ObservedObject private var coordinator: FlowCoordinator<Step>
    private let backTitle: String
    private let nextTitle: String
    private let completeTitle: String
    private let onComplete: () -> Void
    
    /// Creates a flow navigation bar.
    ///
    /// - Parameters:
    ///   - coordinator: The flow coordinator.
    ///   - backTitle: The back button title.
    ///   - nextTitle: The next button title.
    ///   - completeTitle: The complete button title.
    ///   - onComplete: Action when flow completes.
    public init(
        coordinator: FlowCoordinator<Step>,
        backTitle: String = "Back",
        nextTitle: String = "Next",
        completeTitle: String = "Complete",
        onComplete: @escaping () -> Void = {}
    ) {
        self.coordinator = coordinator
        self.backTitle = backTitle
        self.nextTitle = nextTitle
        self.completeTitle = completeTitle
        self.onComplete = onComplete
    }
    
    public var body: some View {
        HStack {
            if coordinator.canMoveBackward {
                Button(action: {
                    Task { await coordinator.previous() }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(backTitle)
                    }
                }
            } else {
                Spacer()
                    .frame(width: 80)
            }
            
            Spacer()
            
            Text("\(coordinator.currentIndex + 1) of \(coordinator.totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if coordinator.isLastStep {
                Button(action: {
                    coordinator.complete()
                    onComplete()
                }) {
                    Text(completeTitle)
                        .fontWeight(.semibold)
                }
            } else {
                Button(action: {
                    Task { await coordinator.next() }
                }) {
                    HStack {
                        Text(nextTitle)
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(!coordinator.canMoveForward)
            }
        }
        .padding()
    }
}

// MARK: - Environment Key

private struct FlowCoordinatorKey: EnvironmentKey {
    static let defaultValue: AnyObject? = nil
}

public extension EnvironmentValues {
    /// The current flow coordinator in the environment.
    var flowCoordinator: AnyObject? {
        get { self[FlowCoordinatorKey.self] }
        set { self[FlowCoordinatorKey.self] = newValue }
    }
}

// MARK: - View Extension

public extension View {
    /// Injects a flow coordinator into the environment.
    ///
    /// - Parameter coordinator: The flow coordinator.
    /// - Returns: A view with the coordinator in its environment.
    func flowCoordinator<Step: FlowStep>(_ coordinator: FlowCoordinator<Step>) -> some View {
        environment(\.flowCoordinator, coordinator)
    }
}
