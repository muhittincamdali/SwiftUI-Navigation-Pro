import SwiftUI
import Combine

// MARK: - Hero ID

/// A unique identifier for hero transition elements.
public struct HeroID: Hashable, Sendable {
    /// The string identifier.
    public let id: String
    /// The namespace for this hero element.
    public let namespace: String
    
    /// Creates a hero ID.
    ///
    /// - Parameters:
    ///   - id: The unique identifier.
    ///   - namespace: The namespace (default: "default").
    public init(_ id: String, namespace: String = "default") {
        self.id = id
        self.namespace = namespace
    }
    
    /// Creates a hero ID from any hashable value.
    ///
    /// - Parameters:
    ///   - value: The value to use as ID.
    ///   - namespace: The namespace (default: "default").
    public init<T: Hashable>(_ value: T, namespace: String = "default") {
        self.id = String(describing: value)
        self.namespace = namespace
    }
}

// MARK: - Hero State

/// The state of a hero element during transition.
public enum HeroState: Sendable {
    /// The element is at rest (no transition).
    case idle
    /// The element is transitioning.
    case transitioning(progress: CGFloat)
    /// The element has completed its transition.
    case completed
}

// MARK: - Hero Properties

/// Properties that define how a hero element transitions.
public struct HeroProperties: Sendable {
    /// The frame of the element.
    public var frame: CGRect
    /// The corner radius of the element.
    public var cornerRadius: CGFloat
    /// The opacity of the element.
    public var opacity: CGFloat
    /// The scale of the element.
    public var scale: CGFloat
    /// The rotation angle of the element.
    public var rotation: Angle
    /// The anchor point for transformations.
    public var anchor: UnitPoint
    /// The z-index for layering.
    public var zIndex: Double
    
    /// Creates hero properties.
    public init(
        frame: CGRect = .zero,
        cornerRadius: CGFloat = 0,
        opacity: CGFloat = 1,
        scale: CGFloat = 1,
        rotation: Angle = .zero,
        anchor: UnitPoint = .center,
        zIndex: Double = 0
    ) {
        self.frame = frame
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.scale = scale
        self.rotation = rotation
        self.anchor = anchor
        self.zIndex = zIndex
    }
    
    /// Interpolates between two hero properties.
    ///
    /// - Parameters:
    ///   - to: The target properties.
    ///   - progress: The interpolation progress (0.0 to 1.0).
    /// - Returns: Interpolated properties.
    public func interpolate(to: HeroProperties, progress: CGFloat) -> HeroProperties {
        let p = min(max(progress, 0), 1)
        return HeroProperties(
            frame: CGRect(
                x: frame.origin.x + (to.frame.origin.x - frame.origin.x) * p,
                y: frame.origin.y + (to.frame.origin.y - frame.origin.y) * p,
                width: frame.width + (to.frame.width - frame.width) * p,
                height: frame.height + (to.frame.height - frame.height) * p
            ),
            cornerRadius: cornerRadius + (to.cornerRadius - cornerRadius) * p,
            opacity: opacity + (to.opacity - opacity) * p,
            scale: scale + (to.scale - scale) * p,
            rotation: Angle(degrees: rotation.degrees + (to.rotation.degrees - rotation.degrees) * Double(p)),
            anchor: UnitPoint(
                x: anchor.x + (to.anchor.x - anchor.x) * p,
                y: anchor.y + (to.anchor.y - anchor.y) * p
            ),
            zIndex: zIndex + (to.zIndex - zIndex) * Double(p)
        )
    }
}

// MARK: - Hero Element

/// A registered hero element for transitions.
public struct HeroElement: Sendable {
    /// The unique identifier.
    public let heroID: HeroID
    /// The source properties.
    public let sourceProperties: HeroProperties
    /// The destination properties (if available).
    public var destinationProperties: HeroProperties?
    /// The current transition state.
    public var state: HeroState
    /// The associated view content (type-erased).
    public let contentType: String
    
    /// Creates a hero element.
    public init(
        heroID: HeroID,
        sourceProperties: HeroProperties,
        destinationProperties: HeroProperties? = nil,
        state: HeroState = .idle,
        contentType: String = "View"
    ) {
        self.heroID = heroID
        self.sourceProperties = sourceProperties
        self.destinationProperties = destinationProperties
        self.state = state
        self.contentType = contentType
    }
}

// MARK: - Hero Timing Function

/// Timing functions for hero transitions.
public enum HeroTimingFunction: Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case spring(response: Double, dampingFraction: Double)
    case custom(controlPoint1: CGPoint, controlPoint2: CGPoint)
    
    /// The corresponding SwiftUI animation.
    public var animation: Animation {
        switch self {
        case .linear:
            return .linear
        case .easeIn:
            return .easeIn
        case .easeOut:
            return .easeOut
        case .easeInOut:
            return .easeInOut
        case .spring(let response, let dampingFraction):
            return .spring(response: response, dampingFraction: dampingFraction)
        case .custom(let cp1, let cp2):
            return .timingCurve(Double(cp1.x), Double(cp1.y), Double(cp2.x), Double(cp2.y))
        }
    }
    
    /// Applies the timing function to a progress value.
    ///
    /// - Parameter t: The linear progress (0.0 to 1.0).
    /// - Returns: The eased progress.
    public func apply(_ t: CGFloat) -> CGFloat {
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return t * (2 - t)
        case .easeInOut:
            return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
        case .spring:
            return t // Simplified, actual spring is handled by animation
        case .custom(let cp1, let cp2):
            return bezierValue(t: t, p1: cp1, p2: cp2)
        }
    }
    
    private func bezierValue(t: CGFloat, p1: CGPoint, p2: CGPoint) -> CGFloat {
        let oneMinusT = 1 - t
        let oneMinusTSquared = oneMinusT * oneMinusT
        let oneMinusTCubed = oneMinusTSquared * oneMinusT
        let tSquared = t * t
        let tCubed = tSquared * t
        
        return oneMinusTCubed * 0 +
               3 * oneMinusTSquared * t * p1.y +
               3 * oneMinusT * tSquared * p2.y +
               tCubed * 1
    }
}

// MARK: - Hero Configuration

/// Configuration for a hero transition.
public struct HeroConfiguration: Sendable {
    /// The duration of the transition.
    public let duration: TimeInterval
    /// The timing function.
    public let timingFunction: HeroTimingFunction
    /// Whether to fade during transition.
    public let fadeOnTransition: Bool
    /// Whether to scale during transition.
    public let scaleOnTransition: Bool
    /// The delay before starting.
    public let delay: TimeInterval
    /// Whether the transition is interactive.
    public let isInteractive: Bool
    /// The minimum progress to complete (for interactive).
    public let completionThreshold: CGFloat
    
    /// Creates a hero configuration.
    public init(
        duration: TimeInterval = 0.35,
        timingFunction: HeroTimingFunction = .easeInOut,
        fadeOnTransition: Bool = false,
        scaleOnTransition: Bool = false,
        delay: TimeInterval = 0,
        isInteractive: Bool = false,
        completionThreshold: CGFloat = 0.5
    ) {
        self.duration = duration
        self.timingFunction = timingFunction
        self.fadeOnTransition = fadeOnTransition
        self.scaleOnTransition = scaleOnTransition
        self.delay = delay
        self.isInteractive = isInteractive
        self.completionThreshold = completionThreshold
    }
    
    /// The default configuration.
    public static let `default` = HeroConfiguration()
    
    /// A spring-based configuration.
    public static let spring = HeroConfiguration(
        timingFunction: .spring(response: 0.5, dampingFraction: 0.75)
    )
    
    /// A slow configuration for emphasis.
    public static let slow = HeroConfiguration(duration: 0.6)
    
    /// A fast configuration.
    public static let fast = HeroConfiguration(duration: 0.2)
}

// MARK: - Hero Coordinator

/// Coordinates hero transitions between views.
///
/// Use `HeroCoordinator` to manage shared element transitions
/// across different screens in your app.
///
/// ```swift
/// @StateObject private var hero = HeroCoordinator()
///
/// var body: some View {
///     HeroContainer(coordinator: hero) {
///         NavigationStack {
///             // Your views here
///         }
///     }
/// }
/// ```
@MainActor
public final class HeroCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The registered hero elements.
    @Published public private(set) var elements: [HeroID: HeroElement] = [:]
    
    /// The current transition progress (0.0 to 1.0).
    @Published public private(set) var progress: CGFloat = 0
    
    /// Whether a transition is in progress.
    @Published public private(set) var isTransitioning: Bool = false
    
    /// The currently transitioning elements.
    @Published public private(set) var activeTransitions: Set<HeroID> = []
    
    // MARK: - Properties
    
    /// The configuration for transitions.
    public var configuration: HeroConfiguration = .default
    
    /// The namespace for matched geometry effect.
    @Namespace public var namespace
    
    /// Completion handlers for transitions.
    private var completionHandlers: [HeroID: () -> Void] = [:]
    
    /// Cancellables for animations.
    private var animationCancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Creates a hero coordinator.
    public init(configuration: HeroConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Registration
    
    /// Registers a hero element at its source position.
    ///
    /// - Parameters:
    ///   - heroID: The hero identifier.
    ///   - properties: The source properties.
    public func registerSource(_ heroID: HeroID, properties: HeroProperties) {
        if var element = elements[heroID] {
            element.state = .idle
            elements[heroID] = HeroElement(
                heroID: heroID,
                sourceProperties: properties,
                destinationProperties: element.destinationProperties,
                state: .idle
            )
        } else {
            elements[heroID] = HeroElement(heroID: heroID, sourceProperties: properties)
        }
    }
    
    /// Registers a hero element at its destination position.
    ///
    /// - Parameters:
    ///   - heroID: The hero identifier.
    ///   - properties: The destination properties.
    public func registerDestination(_ heroID: HeroID, properties: HeroProperties) {
        if var element = elements[heroID] {
            element.destinationProperties = properties
            elements[heroID] = element
        } else {
            elements[heroID] = HeroElement(
                heroID: heroID,
                sourceProperties: HeroProperties(),
                destinationProperties: properties
            )
        }
    }
    
    /// Unregisters a hero element.
    ///
    /// - Parameter heroID: The hero identifier.
    public func unregister(_ heroID: HeroID) {
        elements.removeValue(forKey: heroID)
        activeTransitions.remove(heroID)
        completionHandlers.removeValue(forKey: heroID)
    }
    
    /// Unregisters all hero elements.
    public func unregisterAll() {
        elements.removeAll()
        activeTransitions.removeAll()
        completionHandlers.removeAll()
    }
    
    // MARK: - Transitions
    
    /// Starts a hero transition for the specified element.
    ///
    /// - Parameters:
    ///   - heroID: The hero identifier.
    ///   - reversed: Whether to reverse the transition.
    ///   - completion: Completion handler.
    public func startTransition(
        for heroID: HeroID,
        reversed: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        guard var element = elements[heroID],
              element.destinationProperties != nil else { return }
        
        element.state = .transitioning(progress: 0)
        elements[heroID] = element
        activeTransitions.insert(heroID)
        isTransitioning = true
        
        if let completion = completion {
            completionHandlers[heroID] = completion
        }
        
        animateTransition(for: heroID, reversed: reversed)
    }
    
    /// Starts transitions for all registered elements.
    ///
    /// - Parameters:
    ///   - reversed: Whether to reverse the transitions.
    ///   - completion: Completion handler.
    public func startAllTransitions(reversed: Bool = false, completion: (() -> Void)? = nil) {
        let eligibleIDs = elements.keys.filter { elements[$0]?.destinationProperties != nil }
        
        for heroID in eligibleIDs {
            startTransition(for: heroID, reversed: reversed)
        }
        
        // Call completion after the longest transition
        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.duration) {
            completion?()
        }
    }
    
    /// Updates the transition progress (for interactive transitions).
    ///
    /// - Parameters:
    ///   - heroID: The hero identifier.
    ///   - progress: The progress (0.0 to 1.0).
    public func updateProgress(for heroID: HeroID, progress: CGFloat) {
        guard configuration.isInteractive else { return }
        guard var element = elements[heroID] else { return }
        
        let clampedProgress = min(max(progress, 0), 1)
        element.state = .transitioning(progress: clampedProgress)
        elements[heroID] = element
        self.progress = clampedProgress
    }
    
    /// Completes or cancels an interactive transition.
    ///
    /// - Parameters:
    ///   - heroID: The hero identifier.
    ///   - complete: Whether to complete (true) or cancel (false).
    public func finishInteractiveTransition(for heroID: HeroID, complete: Bool) {
        guard configuration.isInteractive else { return }
        
        let targetProgress: CGFloat = complete ? 1.0 : 0.0
        animateToProgress(for: heroID, progress: targetProgress)
    }
    
    /// Cancels a transition.
    ///
    /// - Parameter heroID: The hero identifier.
    public func cancelTransition(for heroID: HeroID) {
        guard var element = elements[heroID] else { return }
        
        element.state = .idle
        elements[heroID] = element
        activeTransitions.remove(heroID)
        completionHandlers.removeValue(forKey: heroID)
        
        if activeTransitions.isEmpty {
            isTransitioning = false
            progress = 0
        }
    }
    
    /// Cancels all active transitions.
    public func cancelAllTransitions() {
        for heroID in activeTransitions {
            cancelTransition(for: heroID)
        }
    }
    
    // MARK: - Queries
    
    /// Gets the current properties for a hero element.
    ///
    /// - Parameter heroID: The hero identifier.
    /// - Returns: The current interpolated properties, if available.
    public func currentProperties(for heroID: HeroID) -> HeroProperties? {
        guard let element = elements[heroID] else { return nil }
        
        switch element.state {
        case .idle:
            return element.sourceProperties
        case .transitioning(let progress):
            guard let dest = element.destinationProperties else { return element.sourceProperties }
            let easedProgress = configuration.timingFunction.apply(progress)
            return element.sourceProperties.interpolate(to: dest, progress: easedProgress)
        case .completed:
            return element.destinationProperties ?? element.sourceProperties
        }
    }
    
    /// Checks if a hero element is registered.
    ///
    /// - Parameter heroID: The hero identifier.
    /// - Returns: Whether the element is registered.
    public func isRegistered(_ heroID: HeroID) -> Bool {
        elements[heroID] != nil
    }
    
    /// Checks if a hero element is transitioning.
    ///
    /// - Parameter heroID: The hero identifier.
    /// - Returns: Whether the element is transitioning.
    public func isTransitioning(_ heroID: HeroID) -> Bool {
        activeTransitions.contains(heroID)
    }
    
    // MARK: - Private Methods
    
    private func animateTransition(for heroID: HeroID, reversed: Bool) {
        let startProgress: CGFloat = reversed ? 1.0 : 0.0
        let endProgress: CGFloat = reversed ? 0.0 : 1.0
        
        progress = startProgress
        
        withAnimation(configuration.timingFunction.animation.delay(configuration.delay)) {
            progress = endProgress
        }
        
        // Update element state during animation
        let duration = configuration.duration + configuration.delay
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.completeTransition(for: heroID)
        }
    }
    
    private func animateToProgress(for heroID: HeroID, progress targetProgress: CGFloat) {
        withAnimation(configuration.timingFunction.animation) {
            progress = targetProgress
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.duration) { [weak self] in
            if targetProgress == 1.0 {
                self?.completeTransition(for: heroID)
            } else {
                self?.cancelTransition(for: heroID)
            }
        }
    }
    
    private func completeTransition(for heroID: HeroID) {
        guard var element = elements[heroID] else { return }
        
        element.state = .completed
        elements[heroID] = element
        activeTransitions.remove(heroID)
        
        completionHandlers[heroID]?()
        completionHandlers.removeValue(forKey: heroID)
        
        if activeTransitions.isEmpty {
            isTransitioning = false
        }
    }
}

// MARK: - Hero Container

/// A container view that enables hero transitions.
public struct HeroContainer<Content: View>: View {
    @ObservedObject private var coordinator: HeroCoordinator
    private let content: Content
    
    /// Creates a hero container.
    ///
    /// - Parameters:
    ///   - coordinator: The hero coordinator.
    ///   - content: The content to display.
    public init(
        coordinator: HeroCoordinator,
        @ViewBuilder content: () -> Content
    ) {
        self.coordinator = coordinator
        self.content = content()
    }
    
    public var body: some View {
        content
            .environment(\.heroCoordinator, coordinator)
    }
}

// MARK: - Hero Source View

/// A view that marks the source position of a hero element.
public struct HeroSource<Content: View>: View {
    @Environment(\.heroCoordinator) private var coordinator
    
    private let heroID: HeroID
    private let content: Content
    private let cornerRadius: CGFloat
    
    /// Creates a hero source view.
    ///
    /// - Parameters:
    ///   - id: The hero identifier.
    ///   - cornerRadius: The corner radius for the element.
    ///   - content: The content to display.
    public init(
        id: HeroID,
        cornerRadius: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.heroID = id
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    public var body: some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            let frame = geometry.frame(in: .global)
                            coordinator?.registerSource(heroID, properties: HeroProperties(
                                frame: frame,
                                cornerRadius: cornerRadius
                            ))
                        }
                        .onChange(of: geometry.frame(in: .global)) { newFrame in
                            coordinator?.registerSource(heroID, properties: HeroProperties(
                                frame: newFrame,
                                cornerRadius: cornerRadius
                            ))
                        }
                }
            )
            .opacity(coordinator?.isTransitioning(heroID) == true ? 0 : 1)
    }
}

// MARK: - Hero Destination View

/// A view that marks the destination position of a hero element.
public struct HeroDestination<Content: View>: View {
    @Environment(\.heroCoordinator) private var coordinator
    
    private let heroID: HeroID
    private let content: Content
    private let cornerRadius: CGFloat
    
    /// Creates a hero destination view.
    ///
    /// - Parameters:
    ///   - id: The hero identifier.
    ///   - cornerRadius: The corner radius for the element.
    ///   - content: The content to display.
    public init(
        id: HeroID,
        cornerRadius: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.heroID = id
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    public var body: some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            let frame = geometry.frame(in: .global)
                            coordinator?.registerDestination(heroID, properties: HeroProperties(
                                frame: frame,
                                cornerRadius: cornerRadius
                            ))
                        }
                        .onChange(of: geometry.frame(in: .global)) { newFrame in
                            coordinator?.registerDestination(heroID, properties: HeroProperties(
                                frame: newFrame,
                                cornerRadius: cornerRadius
                            ))
                        }
                }
            )
            .opacity(coordinator?.isTransitioning(heroID) == true ? 0 : 1)
    }
}

// MARK: - Hero Modifier

/// A view modifier that enables hero transitions.
public struct HeroModifier: ViewModifier {
    @Environment(\.heroCoordinator) private var coordinator
    
    let heroID: HeroID
    let isSource: Bool
    let cornerRadius: CGFloat
    
    public func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            let frame = geometry.frame(in: .global)
                            let props = HeroProperties(frame: frame, cornerRadius: cornerRadius)
                            if isSource {
                                coordinator?.registerSource(heroID, properties: props)
                            } else {
                                coordinator?.registerDestination(heroID, properties: props)
                            }
                        }
                }
            )
            .opacity(coordinator?.isTransitioning(heroID) == true ? 0 : 1)
    }
}

// MARK: - Environment Key

private struct HeroCoordinatorKey: EnvironmentKey {
    static let defaultValue: HeroCoordinator? = nil
}

public extension EnvironmentValues {
    /// The hero coordinator in the environment.
    var heroCoordinator: HeroCoordinator? {
        get { self[HeroCoordinatorKey.self] }
        set { self[HeroCoordinatorKey.self] = newValue }
    }
}

// MARK: - View Extensions

public extension View {
    /// Marks this view as a hero source.
    ///
    /// - Parameters:
    ///   - id: The hero identifier.
    ///   - cornerRadius: The corner radius.
    /// - Returns: A view marked as a hero source.
    func heroSource(id: HeroID, cornerRadius: CGFloat = 0) -> some View {
        modifier(HeroModifier(heroID: id, isSource: true, cornerRadius: cornerRadius))
    }
    
    /// Marks this view as a hero destination.
    ///
    /// - Parameters:
    ///   - id: The hero identifier.
    ///   - cornerRadius: The corner radius.
    /// - Returns: A view marked as a hero destination.
    func heroDestination(id: HeroID, cornerRadius: CGFloat = 0) -> some View {
        modifier(HeroModifier(heroID: id, isSource: false, cornerRadius: cornerRadius))
    }
    
    /// Injects a hero coordinator into the environment.
    ///
    /// - Parameter coordinator: The hero coordinator.
    /// - Returns: A view with the coordinator in its environment.
    func heroCoordinator(_ coordinator: HeroCoordinator) -> some View {
        environment(\.heroCoordinator, coordinator)
    }
}
