import SwiftUI
import Combine

// MARK: - Navigator Protocol

/// A protocol defining the core navigation capabilities.
///
/// Implement this protocol to create custom navigation controllers
/// that can be used throughout your application.
@MainActor
public protocol NavigatorProtocol: ObservableObject {
    associatedtype RouteType: Route
    
    /// Pushes a route onto the navigation stack.
    func push(_ route: RouteType)
    
    /// Pops the top route from the stack.
    func pop()
    
    /// Pops to the root of the navigation stack.
    func popToRoot()
    
    /// Presents a route modally.
    func present(_ route: RouteType, style: PresentationStyle)
    
    /// Dismisses the current modal presentation.
    func dismiss()
}

// MARK: - Navigator

/// A powerful, type-safe navigation controller for SwiftUI applications.
///
/// `Navigator` provides a comprehensive API for managing navigation state,
/// including push/pop operations, modal presentations, deep linking,
/// state persistence, and navigation analytics.
///
/// ## Overview
///
/// Navigator is designed to work seamlessly with SwiftUI's `NavigationStack`
/// while providing additional functionality like:
///
/// - Type-safe routing with compile-time checks
/// - Multiple presentation styles (sheet, fullScreenCover, popover)
/// - Deep link handling with pattern matching
/// - State persistence for app restoration
/// - Navigation analytics and debugging
/// - Animated transitions with customization
///
/// ## Usage
///
/// ```swift
/// @StateObject private var navigator = Navigator<AppRoute>()
///
/// var body: some View {
///     NavigationStack(path: $navigator.path) {
///         HomeView()
///             .navigationDestination(for: AppRoute.self) { route in
///                 destinationView(for: route)
///             }
///     }
///     .environmentObject(navigator)
/// }
/// ```
@MainActor
public final class Navigator<R: Route>: NavigatorProtocol, ObservableObject, Identifiable {
    
    // MARK: - Type Aliases
    
    public typealias RouteType = R
    public typealias NavigationCallback = (R) -> Void
    public typealias DismissCallback = () -> Void
    
    // MARK: - Published Properties
    
    /// The navigation path backing the NavigationStack.
    @Published public var path = NavigationPath()
    
    /// The current sheet presentation, if any.
    @Published public var sheet: R?
    
    /// The current full-screen cover presentation, if any.
    @Published public var fullScreenCover: R?
    
    /// The current popover presentation, if any.
    @Published public var popover: R?
    
    /// Whether a sheet is currently presented.
    @Published public var isSheetPresented = false
    
    /// Whether a full-screen cover is currently presented.
    @Published public var isFullScreenCoverPresented = false
    
    /// Whether a popover is currently presented.
    @Published public var isPopoverPresented = false
    
    /// The current navigation animation.
    @Published public var currentAnimation: NavigationAnimation = .default
    
    /// Whether navigation transitions are enabled.
    @Published public var transitionsEnabled = true
    
    // MARK: - Properties
    
    /// Unique identifier for this navigator instance.
    public let id = UUID()
    
    /// The internal route stack for tracking navigation state.
    private(set) var routeStack: [R] = []
    
    /// Navigation history for debugging and analytics.
    private(set) var history: [NavigationHistoryEntry<R>] = []
    
    /// The maximum history size before pruning.
    public var maxHistorySize: Int = 100
    
    /// Delegate for navigation lifecycle events.
    public weak var delegate: (any NavigatorDelegate<R>)?
    
    /// Configuration for the navigator behavior.
    public var configuration: NavigatorConfiguration
    
    /// Analytics handler for tracking navigation events.
    public var analyticsHandler: NavigationAnalyticsHandler<R>?
    
    /// Queue of pending presentations.
    private var presentationQueue: [PendingPresentation<R>] = []
    
    /// Combine cancellables.
    private var cancellables = Set<AnyCancellable>()
    
    /// The dismiss callback for the current modal.
    private var dismissCallback: DismissCallback?
    
    /// Custom transition animations registry.
    private var customTransitions: [String: AnyTransition] = [:]
    
    // MARK: - Initialization
    
    /// Creates a navigator with default configuration.
    public init() {
        self.configuration = NavigatorConfiguration()
        setupBindings()
    }
    
    /// Creates a navigator with custom configuration.
    ///
    /// - Parameter configuration: The configuration for navigator behavior.
    public init(configuration: NavigatorConfiguration) {
        self.configuration = configuration
        setupBindings()
    }
    
    /// Creates a navigator with an initial route.
    ///
    /// - Parameters:
    ///   - initialRoute: The route to push immediately.
    ///   - configuration: The configuration for navigator behavior.
    public convenience init(initialRoute: R, configuration: NavigatorConfiguration = NavigatorConfiguration()) {
        self.init(configuration: configuration)
        push(initialRoute, animated: false)
    }
    
    /// Creates a navigator with multiple initial routes.
    ///
    /// - Parameters:
    ///   - initialRoutes: The routes to push in order.
    ///   - configuration: The configuration for navigator behavior.
    public convenience init(initialRoutes: [R], configuration: NavigatorConfiguration = NavigatorConfiguration()) {
        self.init(configuration: configuration)
        for route in initialRoutes {
            push(route, animated: false)
        }
    }
    
    // MARK: - Push Operations
    
    /// Pushes a route onto the navigation stack.
    ///
    /// - Parameter route: The route to push.
    public func push(_ route: R) {
        push(route, animated: transitionsEnabled)
    }
    
    /// Pushes a route with animation control.
    ///
    /// - Parameters:
    ///   - route: The route to push.
    ///   - animated: Whether to animate the transition.
    public func push(_ route: R, animated: Bool) {
        let animation = animated ? currentAnimation.animation : nil
        
        delegate?.navigator(self, willNavigateTo: route)
        
        withAnimation(animation) {
            routeStack.append(route)
            path.append(route)
        }
        
        recordHistory(.push(route))
        delegate?.navigator(self, didNavigateTo: route)
        analyticsHandler?.trackNavigation(event: .push(route))
    }
    
    /// Pushes multiple routes onto the stack.
    ///
    /// - Parameter routes: The routes to push in order.
    public func push(contentsOf routes: [R]) {
        push(contentsOf: routes, animated: transitionsEnabled)
    }
    
    /// Pushes multiple routes with animation control.
    ///
    /// - Parameters:
    ///   - routes: The routes to push.
    ///   - animated: Whether to animate the transition.
    public func push(contentsOf routes: [R], animated: Bool) {
        guard !routes.isEmpty else { return }
        
        let animation = animated ? currentAnimation.animation : nil
        
        withAnimation(animation) {
            for route in routes {
                routeStack.append(route)
                path.append(route)
            }
        }
        
        if let last = routes.last {
            recordHistory(.push(last))
            delegate?.navigator(self, didNavigateTo: last)
        }
    }
    
    /// Pushes a route and replaces the current top route.
    ///
    /// - Parameter route: The route to push as replacement.
    public func replace(with route: R) {
        replace(with: route, animated: transitionsEnabled)
    }
    
    /// Replaces the current top route with animation control.
    ///
    /// - Parameters:
    ///   - route: The route to push as replacement.
    ///   - animated: Whether to animate the transition.
    public func replace(with route: R, animated: Bool) {
        let animation = animated ? currentAnimation.animation : nil
        
        withAnimation(animation) {
            if !routeStack.isEmpty {
                let removed = routeStack.removeLast()
                path.removeLast()
                recordHistory(.pop(removed))
            }
            
            routeStack.append(route)
            path.append(route)
        }
        
        recordHistory(.push(route))
        delegate?.navigator(self, didNavigateTo: route)
    }
    
    /// Pushes a route only if it's not already at the top.
    ///
    /// - Parameter route: The route to push.
    /// - Returns: `true` if the route was pushed.
    @discardableResult
    public func pushIfNotTop(_ route: R) -> Bool {
        guard topRoute != route else { return false }
        push(route)
        return true
    }
    
    /// Pushes a route after a delay.
    ///
    /// - Parameters:
    ///   - route: The route to push.
    ///   - delay: The delay in seconds.
    public func push(_ route: R, after delay: TimeInterval) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self.push(route)
        }
    }
    
    // MARK: - Pop Operations
    
    /// Pops the top route from the stack.
    public func pop() {
        pop(animated: transitionsEnabled)
    }
    
    /// Pops the top route with animation control.
    ///
    /// - Parameter animated: Whether to animate the transition.
    public func pop(animated: Bool) {
        guard !routeStack.isEmpty else { return }
        
        let animation = animated ? currentAnimation.animation : nil
        let removed = routeStack.last!
        
        delegate?.navigator(self, willPop: removed)
        
        withAnimation(animation) {
            routeStack.removeLast()
            path.removeLast()
        }
        
        recordHistory(.pop(removed))
        delegate?.navigator(self, didPop: removed)
        analyticsHandler?.trackNavigation(event: .pop(removed))
    }
    
    /// Pops a specific number of routes from the stack.
    ///
    /// - Parameter count: The number of routes to pop.
    public func pop(_ count: Int) {
        pop(count, animated: transitionsEnabled)
    }
    
    /// Pops a specific number of routes with animation control.
    ///
    /// - Parameters:
    ///   - count: The number of routes to pop.
    ///   - animated: Whether to animate the transition.
    public func pop(_ count: Int, animated: Bool) {
        guard count > 0, count <= routeStack.count else { return }
        
        let animation = animated ? currentAnimation.animation : nil
        
        withAnimation(animation) {
            for _ in 0..<count {
                let removed = routeStack.removeLast()
                path.removeLast()
                recordHistory(.pop(removed))
            }
        }
    }
    
    /// Pops all routes and returns to root.
    public func popToRoot() {
        popToRoot(animated: transitionsEnabled)
    }
    
    /// Pops to root with animation control.
    ///
    /// - Parameter animated: Whether to animate the transition.
    public func popToRoot(animated: Bool) {
        guard !routeStack.isEmpty else { return }
        
        let animation = animated ? currentAnimation.animation : nil
        
        delegate?.navigatorWillPopToRoot(self)
        
        withAnimation(animation) {
            routeStack.removeAll()
            path = NavigationPath()
        }
        
        recordHistory(.popToRoot)
        delegate?.navigatorDidPopToRoot(self)
        analyticsHandler?.trackNavigation(event: .popToRoot)
    }
    
    /// Pops to a specific route in the stack.
    ///
    /// - Parameter route: The route to pop to.
    /// - Returns: `true` if the route was found and popped to.
    @discardableResult
    public func popTo(_ route: R) -> Bool {
        popTo(route, animated: transitionsEnabled)
    }
    
    /// Pops to a specific route with animation control.
    ///
    /// - Parameters:
    ///   - route: The route to pop to.
    ///   - animated: Whether to animate the transition.
    /// - Returns: `true` if the route was found and popped to.
    @discardableResult
    public func popTo(_ route: R, animated: Bool) -> Bool {
        guard let index = routeStack.lastIndex(where: { $0.path == route.path }) else {
            return false
        }
        
        let count = routeStack.count - index - 1
        guard count > 0 else { return false }
        
        pop(count, animated: animated)
        return true
    }
    
    /// Pops to the first route matching a predicate.
    ///
    /// - Parameter predicate: A closure that returns `true` for the target route.
    /// - Returns: `true` if a matching route was found and popped to.
    @discardableResult
    public func popTo(where predicate: (R) -> Bool) -> Bool {
        guard let index = routeStack.lastIndex(where: predicate) else {
            return false
        }
        
        let count = routeStack.count - index - 1
        guard count > 0 else { return false }
        
        pop(count)
        return true
    }
    
    /// Pops to a route matching a specific path.
    ///
    /// - Parameter path: The route path to match.
    /// - Returns: `true` if the route was found and popped to.
    @discardableResult
    public func popTo(path: String) -> Bool {
        popTo { $0.path == path }
    }
    
    // MARK: - Presentation Operations
    
    /// Presents a route modally.
    ///
    /// - Parameters:
    ///   - route: The route to present.
    ///   - style: The presentation style.
    public func present(_ route: R, style: PresentationStyle) {
        present(route, style: style, onDismiss: nil)
    }
    
    /// Presents a route modally with a dismiss callback.
    ///
    /// - Parameters:
    ///   - route: The route to present.
    ///   - style: The presentation style.
    ///   - onDismiss: A callback invoked when the presentation is dismissed.
    public func present(_ route: R, style: PresentationStyle, onDismiss: DismissCallback?) {
        // Queue if already presenting
        if isPresenting {
            if configuration.queuePresentations {
                presentationQueue.append(PendingPresentation(route: route, style: style, onDismiss: onDismiss))
            }
            return
        }
        
        dismissCallback = onDismiss
        
        delegate?.navigator(self, willPresent: route, style: style)
        
        switch style {
        case .sheet:
            sheet = route
            isSheetPresented = true
        case .fullScreenCover:
            fullScreenCover = route
            isFullScreenCoverPresented = true
        }
        
        recordHistory(.present(route, style))
        delegate?.navigator(self, didPresent: route, style: style)
        analyticsHandler?.trackNavigation(event: .present(route, style))
    }
    
    /// Presents a route as a sheet.
    ///
    /// - Parameter route: The route to present.
    public func presentSheet(_ route: R) {
        present(route, style: .sheet)
    }
    
    /// Presents a route as a full-screen cover.
    ///
    /// - Parameter route: The route to present.
    public func presentFullScreenCover(_ route: R) {
        present(route, style: .fullScreenCover)
    }
    
    /// Presents a route as a popover.
    ///
    /// - Parameter route: The route to present.
    public func presentPopover(_ route: R) {
        popover = route
        isPopoverPresented = true
        recordHistory(.presentPopover(route))
    }
    
    /// Dismisses the current modal presentation.
    public func dismiss() {
        dismiss(animated: true)
    }
    
    /// Dismisses the current modal with animation control.
    ///
    /// - Parameter animated: Whether to animate the dismissal.
    public func dismiss(animated: Bool) {
        let callback = dismissCallback
        dismissCallback = nil
        
        if isSheetPresented {
            delegate?.navigator(self, willDismiss: sheet)
            isSheetPresented = false
            sheet = nil
            delegate?.navigator(self, didDismiss: nil)
        }
        
        if isFullScreenCoverPresented {
            delegate?.navigator(self, willDismiss: fullScreenCover)
            isFullScreenCoverPresented = false
            fullScreenCover = nil
            delegate?.navigator(self, didDismiss: nil)
        }
        
        if isPopoverPresented {
            isPopoverPresented = false
            popover = nil
        }
        
        recordHistory(.dismiss)
        callback?()
        analyticsHandler?.trackNavigation(event: .dismiss)
        
        // Process next queued presentation
        processNextPresentation()
    }
    
    /// Dismisses all modal presentations.
    public func dismissAll() {
        dismissCallback = nil
        isSheetPresented = false
        isFullScreenCoverPresented = false
        isPopoverPresented = false
        sheet = nil
        fullScreenCover = nil
        popover = nil
        presentationQueue.removeAll()
        recordHistory(.dismissAll)
    }
    
    // MARK: - Query Properties
    
    /// The number of routes on the stack.
    public var stackDepth: Int {
        routeStack.count
    }
    
    /// The top route on the stack, if any.
    public var topRoute: R? {
        routeStack.last
    }
    
    /// The root route on the stack, if any.
    public var rootRoute: R? {
        routeStack.first
    }
    
    /// Whether the stack is at root (empty).
    public var isAtRoot: Bool {
        routeStack.isEmpty
    }
    
    /// Whether any modal is currently presented.
    public var isPresenting: Bool {
        isSheetPresented || isFullScreenCoverPresented || isPopoverPresented
    }
    
    /// The currently presented route, if any.
    public var presentedRoute: R? {
        sheet ?? fullScreenCover ?? popover
    }
    
    /// Whether the navigator can pop (has routes on stack).
    public var canPop: Bool {
        !routeStack.isEmpty
    }
    
    /// Whether the navigator can dismiss (has a modal presented).
    public var canDismiss: Bool {
        isPresenting
    }
    
    // MARK: - Route Queries
    
    /// Returns the route at a specific index.
    ///
    /// - Parameter index: The index in the route stack.
    /// - Returns: The route at the index, or `nil` if out of bounds.
    public func route(at index: Int) -> R? {
        guard routeStack.indices.contains(index) else { return nil }
        return routeStack[index]
    }
    
    /// Checks if a route is in the stack.
    ///
    /// - Parameter route: The route to check.
    /// - Returns: `true` if the route is in the stack.
    public func contains(_ route: R) -> Bool {
        routeStack.contains { $0.path == route.path }
    }
    
    /// Checks if a route matching a predicate is in the stack.
    ///
    /// - Parameter predicate: A closure that returns `true` for matching routes.
    /// - Returns: `true` if a matching route is found.
    public func contains(where predicate: (R) -> Bool) -> Bool {
        routeStack.contains(where: predicate)
    }
    
    /// Returns the index of a route in the stack.
    ///
    /// - Parameter route: The route to find.
    /// - Returns: The index of the route, or `nil` if not found.
    public func index(of route: R) -> Int? {
        routeStack.firstIndex { $0.path == route.path }
    }
    
    // MARK: - State Persistence
    
    /// Encodes the current navigation state.
    ///
    /// - Returns: The encoded state data.
    public func encodeState() throws -> Data {
        let state = NavigatorState(
            routes: routeStack,
            presentedRoute: presentedRoute,
            presentationStyle: isSheetPresented ? .sheet : isFullScreenCoverPresented ? .fullScreenCover : nil
        )
        return try JSONEncoder().encode(state)
    }
    
    /// Restores navigation state from encoded data.
    ///
    /// - Parameter data: The encoded state data.
    public func restoreState(from data: Data) throws {
        let state = try JSONDecoder().decode(NavigatorState<R>.self, from: data)
        
        routeStack = state.routes
        path = NavigationPath()
        for route in state.routes {
            path.append(route)
        }
        
        if let presentedRoute = state.presentedRoute,
           let style = state.presentationStyle {
            present(presentedRoute, style: style)
        }
    }
    
    /// Creates a snapshot of the current state.
    ///
    /// - Returns: A navigation state snapshot.
    public func snapshot() -> NavigationState<R> {
        NavigationState(routes: routeStack)
    }
    
    /// Restores from a navigation state snapshot.
    ///
    /// - Parameter state: The state to restore.
    public func restore(from state: NavigationState<R>) {
        routeStack = state.routes
        path = NavigationPath()
        for route in state.routes {
            path.append(route)
        }
    }
    
    // MARK: - Animation
    
    /// Sets the navigation animation.
    ///
    /// - Parameter animation: The animation to use.
    public func setAnimation(_ animation: NavigationAnimation) {
        currentAnimation = animation
    }
    
    /// Performs a navigation action with a custom animation.
    ///
    /// - Parameters:
    ///   - animation: The animation to use.
    ///   - action: The navigation action to perform.
    public func with(animation: NavigationAnimation, perform action: () -> Void) {
        let previous = currentAnimation
        currentAnimation = animation
        action()
        currentAnimation = previous
    }
    
    /// Registers a custom transition for a route path.
    ///
    /// - Parameters:
    ///   - transition: The transition to register.
    ///   - path: The route path to associate with the transition.
    public func registerTransition(_ transition: AnyTransition, for path: String) {
        customTransitions[path] = transition
    }
    
    /// Returns the custom transition for a route, if any.
    ///
    /// - Parameter route: The route to get the transition for.
    /// - Returns: The registered transition, or `nil`.
    public func transition(for route: R) -> AnyTransition? {
        customTransitions[route.path]
    }
    
    // MARK: - History
    
    /// Clears the navigation history.
    public func clearHistory() {
        history.removeAll()
    }
    
    /// Returns the most recent history entries.
    ///
    /// - Parameter count: The number of entries to return.
    /// - Returns: The most recent history entries.
    public func recentHistory(_ count: Int) -> [NavigationHistoryEntry<R>] {
        Array(history.suffix(count))
    }
    
    /// Returns the navigation path as a string for debugging.
    ///
    /// - Returns: A string representation of the current path.
    public func debugPath() -> String {
        let paths = routeStack.map(\.path)
        return paths.isEmpty ? "/" : paths.joined(separator: " → ")
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        $isSheetPresented
            .dropFirst()
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.handleSheetDismiss()
            }
            .store(in: &cancellables)
        
        $isFullScreenCoverPresented
            .dropFirst()
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.handleFullScreenCoverDismiss()
            }
            .store(in: &cancellables)
    }
    
    private func handleSheetDismiss() {
        let callback = dismissCallback
        dismissCallback = nil
        sheet = nil
        callback?()
        processNextPresentation()
    }
    
    private func handleFullScreenCoverDismiss() {
        let callback = dismissCallback
        dismissCallback = nil
        fullScreenCover = nil
        callback?()
        processNextPresentation()
    }
    
    private func processNextPresentation() {
        guard !presentationQueue.isEmpty else { return }
        let next = presentationQueue.removeFirst()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.presentationDelay) { [weak self] in
            self?.present(next.route, style: next.style, onDismiss: next.onDismiss)
        }
    }
    
    private func recordHistory(_ action: NavigationAction<R>) {
        let entry = NavigationHistoryEntry(action: action, timestamp: Date())
        history.append(entry)
        
        // Prune history if needed
        if history.count > maxHistorySize {
            history.removeFirst(history.count - maxHistorySize)
        }
    }
}

// MARK: - NavigatorConfiguration

/// Configuration options for a Navigator instance.
public struct NavigatorConfiguration: Sendable {
    /// Whether to queue presentations when one is already active.
    public var queuePresentations: Bool
    
    /// The delay between queued presentations.
    public var presentationDelay: TimeInterval
    
    /// Whether to enable state persistence.
    public var enablePersistence: Bool
    
    /// The key used for state persistence.
    public var persistenceKey: String?
    
    /// Creates a navigator configuration.
    public init(
        queuePresentations: Bool = true,
        presentationDelay: TimeInterval = 0.35,
        enablePersistence: Bool = false,
        persistenceKey: String? = nil
    ) {
        self.queuePresentations = queuePresentations
        self.presentationDelay = presentationDelay
        self.enablePersistence = enablePersistence
        self.persistenceKey = persistenceKey
    }
    
    /// A default configuration.
    public static let `default` = NavigatorConfiguration()
}

// MARK: - NavigationAnimation

/// Predefined navigation animations.
public enum NavigationAnimation: Sendable {
    case `default`
    case none
    case linear(duration: Double)
    case easeIn(duration: Double)
    case easeOut(duration: Double)
    case easeInOut(duration: Double)
    case spring(response: Double, dampingFraction: Double, blendDuration: Double)
    case interactiveSpring(response: Double, dampingFraction: Double, blendDuration: Double)
    case custom(Animation)
    
    /// The SwiftUI Animation value.
    public var animation: Animation? {
        switch self {
        case .default:
            return .default
        case .none:
            return nil
        case .linear(let duration):
            return .linear(duration: duration)
        case .easeIn(let duration):
            return .easeIn(duration: duration)
        case .easeOut(let duration):
            return .easeOut(duration: duration)
        case .easeInOut(let duration):
            return .easeInOut(duration: duration)
        case .spring(let response, let dampingFraction, let blendDuration):
            return .spring(response: response, dampingFraction: dampingFraction, blendDuration: blendDuration)
        case .interactiveSpring(let response, let dampingFraction, let blendDuration):
            return .interactiveSpring(response: response, dampingFraction: dampingFraction, blendDuration: blendDuration)
        case .custom(let animation):
            return animation
        }
    }
}

// MARK: - NavigationAction

/// An action recorded in navigation history.
public enum NavigationAction<R: Route>: Sendable where R: Sendable {
    case push(R)
    case pop(R)
    case popToRoot
    case present(R, PresentationStyle)
    case presentPopover(R)
    case dismiss
    case dismissAll
}

// MARK: - NavigationHistoryEntry

/// An entry in the navigation history.
public struct NavigationHistoryEntry<R: Route>: Sendable where R: Sendable {
    /// The navigation action.
    public let action: NavigationAction<R>
    
    /// The timestamp when the action occurred.
    public let timestamp: Date
}

// MARK: - PendingPresentation

/// A queued presentation request.
struct PendingPresentation<R: Route> {
    let route: R
    let style: PresentationStyle
    let onDismiss: (() -> Void)?
}

// MARK: - NavigatorState

/// Encodable state for persistence.
public struct NavigatorState<R: Route>: Codable {
    /// The routes on the stack.
    public let routes: [R]
    
    /// The currently presented route, if any.
    public let presentedRoute: R?
    
    /// The presentation style of the presented route.
    public let presentationStyle: PresentationStyle?
}

// MARK: - NavigatorDelegate

/// Delegate protocol for receiving navigator lifecycle events.
@MainActor
public protocol NavigatorDelegate<R>: AnyObject {
    associatedtype R: Route
    
    func navigator(_ navigator: Navigator<R>, willNavigateTo route: R)
    func navigator(_ navigator: Navigator<R>, didNavigateTo route: R)
    func navigator(_ navigator: Navigator<R>, willPop route: R)
    func navigator(_ navigator: Navigator<R>, didPop route: R)
    func navigatorWillPopToRoot(_ navigator: Navigator<R>)
    func navigatorDidPopToRoot(_ navigator: Navigator<R>)
    func navigator(_ navigator: Navigator<R>, willPresent route: R?, style: PresentationStyle)
    func navigator(_ navigator: Navigator<R>, didPresent route: R?, style: PresentationStyle)
    func navigator(_ navigator: Navigator<R>, willDismiss route: R?)
    func navigator(_ navigator: Navigator<R>, didDismiss route: R?)
}

// MARK: - Default Delegate Implementation

public extension NavigatorDelegate {
    func navigator(_ navigator: Navigator<R>, willNavigateTo route: R) {}
    func navigator(_ navigator: Navigator<R>, didNavigateTo route: R) {}
    func navigator(_ navigator: Navigator<R>, willPop route: R) {}
    func navigator(_ navigator: Navigator<R>, didPop route: R) {}
    func navigatorWillPopToRoot(_ navigator: Navigator<R>) {}
    func navigatorDidPopToRoot(_ navigator: Navigator<R>) {}
    func navigator(_ navigator: Navigator<R>, willPresent route: R?, style: PresentationStyle) {}
    func navigator(_ navigator: Navigator<R>, didPresent route: R?, style: PresentationStyle) {}
    func navigator(_ navigator: Navigator<R>, willDismiss route: R?) {}
    func navigator(_ navigator: Navigator<R>, didDismiss route: R?) {}
}

// MARK: - NavigationAnalyticsHandler

/// Handler for tracking navigation analytics.
public struct NavigationAnalyticsHandler<R: Route> {
    
    /// The tracking closure.
    public let track: (NavigationEvent<R>) -> Void
    
    /// Creates an analytics handler.
    ///
    /// - Parameter track: A closure that receives navigation events.
    public init(track: @escaping (NavigationEvent<R>) -> Void) {
        self.track = track
    }
    
    /// Tracks a navigation event.
    ///
    /// - Parameter event: The event to track.
    public func trackNavigation(event: NavigationEvent<R>) {
        track(event)
    }
}

// MARK: - NavigationEvent

/// Events for analytics tracking.
public enum NavigationEvent<R: Route> {
    case push(R)
    case pop(R)
    case popToRoot
    case present(R, PresentationStyle)
    case dismiss
}

// MARK: - Navigator Extensions

extension Navigator: Equatable {
    public static func == (lhs: Navigator<R>, rhs: Navigator<R>) -> Bool {
        lhs.id == rhs.id
    }
}

extension Navigator: Hashable {
    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
