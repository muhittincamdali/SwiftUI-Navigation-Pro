import SwiftUI
import Combine

// MARK: - NavigationPathManager

/// A comprehensive manager for navigation paths with advanced features.
///
/// `NavigationPathManager` extends basic path management with features like:
/// - Path validation and constraints
/// - Navigation guards
/// - Path transformations
/// - Route lifecycle hooks
/// - Breadcrumb tracking
///
/// ## Usage
///
/// ```swift
/// let pathManager = NavigationPathManager<AppRoute>()
///
/// // Add guards
/// pathManager.addGuard { route in
///     switch route {
///     case .adminPanel:
///         return currentUser.isAdmin
///     default:
///         return true
///     }
/// }
///
/// // Use with navigation
/// pathManager.push(.home)
/// ```
@MainActor
public final class NavigationPathManager<R: Route>: ObservableObject {
    
    // MARK: - Type Aliases
    
    public typealias RouteGuard = (R) -> Bool
    public typealias AsyncRouteGuard = (R) async -> Bool
    public typealias RouteTransformer = (R) -> R?
    public typealias PathTransformer = ([R]) -> [R]
    public typealias LifecycleHook = (R) -> Void
    public typealias AsyncLifecycleHook = (R) async -> Void
    
    // MARK: - Published Properties
    
    /// The current navigation path.
    @Published public var path = NavigationPath()
    
    /// The current route stack.
    @Published public private(set) var routes: [R] = []
    
    /// The current breadcrumb trail.
    @Published public private(set) var breadcrumbs: [Breadcrumb<R>] = []
    
    /// Whether navigation is currently locked.
    @Published public var isLocked = false
    
    /// The maximum stack depth (0 = unlimited).
    @Published public var maxStackDepth: Int = 0
    
    // MARK: - Properties
    
    /// Route guards that must pass before navigation.
    private var guards: [RouteGuard] = []
    
    /// Async route guards.
    private var asyncGuards: [AsyncRouteGuard] = []
    
    /// Route transformers applied before pushing.
    private var transformers: [RouteTransformer] = []
    
    /// Path transformers applied to the entire path.
    private var pathTransformers: [PathTransformer] = []
    
    /// Lifecycle hooks for route will appear.
    private var willAppearHooks: [LifecycleHook] = []
    
    /// Lifecycle hooks for route did appear.
    private var didAppearHooks: [LifecycleHook] = []
    
    /// Lifecycle hooks for route will disappear.
    private var willDisappearHooks: [LifecycleHook] = []
    
    /// Lifecycle hooks for route did disappear.
    private var didDisappearHooks: [LifecycleHook] = []
    
    /// Async lifecycle hooks.
    private var asyncWillAppearHooks: [AsyncLifecycleHook] = []
    
    /// Routes that are allowed (whitelist mode).
    private var allowedRoutes: Set<String>?
    
    /// Routes that are blocked (blacklist mode).
    private var blockedRoutes: Set<String> = []
    
    /// Custom validation rules.
    private var validationRules: [(R) -> ValidationResult] = []
    
    /// Combine cancellables.
    private var cancellables = Set<AnyCancellable>()
    
    /// Delegate for path manager events.
    public weak var delegate: (any NavigationPathManagerDelegate<R>)?
    
    // MARK: - Initialization
    
    /// Creates a new navigation path manager.
    public init() {}
    
    /// Creates a path manager with initial routes.
    ///
    /// - Parameter initialRoutes: Routes to initialize the stack with.
    public init(initialRoutes: [R]) {
        for route in initialRoutes {
            routes.append(route)
            path.append(route)
            breadcrumbs.append(Breadcrumb(route: route))
        }
    }
    
    // MARK: - Guard Management
    
    /// Adds a route guard that must pass for navigation to proceed.
    ///
    /// - Parameter guard: A closure that returns `true` to allow navigation.
    public func addGuard(_ guard: @escaping RouteGuard) {
        guards.append(`guard`)
    }
    
    /// Adds an async route guard.
    ///
    /// - Parameter guard: An async closure that returns `true` to allow navigation.
    public func addAsyncGuard(_ guard: @escaping AsyncRouteGuard) {
        asyncGuards.append(`guard`)
    }
    
    /// Removes all route guards.
    public func removeAllGuards() {
        guards.removeAll()
        asyncGuards.removeAll()
    }
    
    /// Checks if all guards pass for a route.
    ///
    /// - Parameter route: The route to check.
    /// - Returns: `true` if all guards pass.
    public func checkGuards(for route: R) -> Bool {
        for guard_ in guards {
            if !guard_(route) {
                return false
            }
        }
        return true
    }
    
    /// Checks async guards for a route.
    ///
    /// - Parameter route: The route to check.
    /// - Returns: `true` if all async guards pass.
    public func checkAsyncGuards(for route: R) async -> Bool {
        for guard_ in asyncGuards {
            let result = await guard_(route)
            if !result {
                return false
            }
        }
        return true
    }
    
    // MARK: - Transformer Management
    
    /// Adds a route transformer.
    ///
    /// Transformers can modify or redirect routes before they're pushed.
    ///
    /// - Parameter transformer: A closure that returns a transformed route or `nil` to cancel.
    public func addTransformer(_ transformer: @escaping RouteTransformer) {
        transformers.append(transformer)
    }
    
    /// Adds a path transformer.
    ///
    /// Path transformers operate on the entire route stack.
    ///
    /// - Parameter transformer: A closure that transforms the path.
    public func addPathTransformer(_ transformer: @escaping PathTransformer) {
        pathTransformers.append(transformer)
    }
    
    /// Removes all transformers.
    public func removeAllTransformers() {
        transformers.removeAll()
        pathTransformers.removeAll()
    }
    
    /// Applies transformers to a route.
    ///
    /// - Parameter route: The route to transform.
    /// - Returns: The transformed route, or `nil` if cancelled.
    private func applyTransformers(to route: R) -> R? {
        var result: R? = route
        for transformer in transformers {
            guard let current = result else { return nil }
            result = transformer(current)
        }
        return result
    }
    
    // MARK: - Lifecycle Hooks
    
    /// Adds a hook called before a route appears.
    ///
    /// - Parameter hook: The lifecycle hook.
    public func onWillAppear(_ hook: @escaping LifecycleHook) {
        willAppearHooks.append(hook)
    }
    
    /// Adds a hook called after a route appears.
    ///
    /// - Parameter hook: The lifecycle hook.
    public func onDidAppear(_ hook: @escaping LifecycleHook) {
        didAppearHooks.append(hook)
    }
    
    /// Adds a hook called before a route disappears.
    ///
    /// - Parameter hook: The lifecycle hook.
    public func onWillDisappear(_ hook: @escaping LifecycleHook) {
        willDisappearHooks.append(hook)
    }
    
    /// Adds a hook called after a route disappears.
    ///
    /// - Parameter hook: The lifecycle hook.
    public func onDidDisappear(_ hook: @escaping LifecycleHook) {
        didDisappearHooks.append(hook)
    }
    
    /// Adds an async hook for route appearance.
    ///
    /// - Parameter hook: The async lifecycle hook.
    public func onWillAppearAsync(_ hook: @escaping AsyncLifecycleHook) {
        asyncWillAppearHooks.append(hook)
    }
    
    /// Removes all lifecycle hooks.
    public func removeAllHooks() {
        willAppearHooks.removeAll()
        didAppearHooks.removeAll()
        willDisappearHooks.removeAll()
        didDisappearHooks.removeAll()
        asyncWillAppearHooks.removeAll()
    }
    
    private func triggerWillAppear(_ route: R) {
        for hook in willAppearHooks {
            hook(route)
        }
    }
    
    private func triggerDidAppear(_ route: R) {
        for hook in didAppearHooks {
            hook(route)
        }
    }
    
    private func triggerWillDisappear(_ route: R) {
        for hook in willDisappearHooks {
            hook(route)
        }
    }
    
    private func triggerDidDisappear(_ route: R) {
        for hook in didDisappearHooks {
            hook(route)
        }
    }
    
    // MARK: - Route Filtering
    
    /// Sets a whitelist of allowed routes.
    ///
    /// When set, only routes with paths in this set can be navigated to.
    ///
    /// - Parameter paths: The allowed route paths.
    public func setAllowedRoutes(_ paths: Set<String>) {
        allowedRoutes = paths
    }
    
    /// Clears the allowed routes whitelist.
    public func clearAllowedRoutes() {
        allowedRoutes = nil
    }
    
    /// Blocks specific routes from navigation.
    ///
    /// - Parameter paths: The route paths to block.
    public func blockRoutes(_ paths: Set<String>) {
        blockedRoutes.formUnion(paths)
    }
    
    /// Unblocks routes.
    ///
    /// - Parameter paths: The route paths to unblock.
    public func unblockRoutes(_ paths: Set<String>) {
        blockedRoutes.subtract(paths)
    }
    
    /// Checks if a route is allowed.
    ///
    /// - Parameter route: The route to check.
    /// - Returns: `true` if the route is allowed.
    public func isAllowed(_ route: R) -> Bool {
        // Check blocklist
        if blockedRoutes.contains(route.path) {
            return false
        }
        
        // Check whitelist if set
        if let allowed = allowedRoutes {
            return allowed.contains(route.path)
        }
        
        return true
    }
    
    // MARK: - Validation
    
    /// Adds a custom validation rule.
    ///
    /// - Parameter rule: A closure that validates a route.
    public func addValidationRule(_ rule: @escaping (R) -> ValidationResult) {
        validationRules.append(rule)
    }
    
    /// Removes all validation rules.
    public func removeAllValidationRules() {
        validationRules.removeAll()
    }
    
    /// Validates a route against all rules.
    ///
    /// - Parameter route: The route to validate.
    /// - Returns: The combined validation result.
    public func validate(_ route: R) -> ValidationResult {
        for rule in validationRules {
            let result = rule(route)
            if !result.isValid {
                return result
            }
        }
        return .valid
    }
    
    // MARK: - Navigation Operations
    
    /// Pushes a route onto the path.
    ///
    /// - Parameter route: The route to push.
    /// - Returns: `true` if the route was pushed successfully.
    @discardableResult
    public func push(_ route: R) -> Bool {
        guard !isLocked else {
            delegate?.pathManager(self, didRejectNavigation: route, reason: .locked)
            return false
        }
        
        // Check depth limit
        if maxStackDepth > 0 && routes.count >= maxStackDepth {
            delegate?.pathManager(self, didRejectNavigation: route, reason: .maxDepthReached)
            return false
        }
        
        // Check if allowed
        guard isAllowed(route) else {
            delegate?.pathManager(self, didRejectNavigation: route, reason: .blocked)
            return false
        }
        
        // Check guards
        guard checkGuards(for: route) else {
            delegate?.pathManager(self, didRejectNavigation: route, reason: .guardFailed)
            return false
        }
        
        // Validate
        let validation = validate(route)
        guard validation.isValid else {
            delegate?.pathManager(self, didRejectNavigation: route, reason: .validationFailed(validation.message))
            return false
        }
        
        // Apply transformers
        guard let transformedRoute = applyTransformers(to: route) else {
            delegate?.pathManager(self, didRejectNavigation: route, reason: .transformerCancelled)
            return false
        }
        
        // Trigger lifecycle
        if let current = routes.last {
            triggerWillDisappear(current)
        }
        triggerWillAppear(transformedRoute)
        
        // Push
        routes.append(transformedRoute)
        path.append(transformedRoute)
        breadcrumbs.append(Breadcrumb(route: transformedRoute))
        
        // Apply path transformers
        applyPathTransformers()
        
        // Trigger did appear
        if let previous = routes.dropLast().last {
            triggerDidDisappear(previous)
        }
        triggerDidAppear(transformedRoute)
        
        delegate?.pathManager(self, didPush: transformedRoute)
        
        return true
    }
    
    /// Pushes a route asynchronously with async guard checks.
    ///
    /// - Parameter route: The route to push.
    /// - Returns: `true` if the route was pushed successfully.
    @discardableResult
    public func pushAsync(_ route: R) async -> Bool {
        guard !isLocked else { return false }
        
        // Check async guards
        let asyncResult = await checkAsyncGuards(for: route)
        guard asyncResult else { return false }
        
        // Continue with sync push
        return push(route)
    }
    
    /// Pops the top route from the path.
    ///
    /// - Returns: The popped route, or `nil` if the path was empty.
    @discardableResult
    public func pop() -> R? {
        guard !isLocked else { return nil }
        guard !routes.isEmpty else { return nil }
        
        let route = routes.last!
        
        triggerWillDisappear(route)
        
        routes.removeLast()
        path.removeLast()
        breadcrumbs.removeLast()
        
        triggerDidDisappear(route)
        
        if let newTop = routes.last {
            triggerWillAppear(newTop)
            triggerDidAppear(newTop)
        }
        
        delegate?.pathManager(self, didPop: route)
        
        return route
    }
    
    /// Pops multiple routes from the path.
    ///
    /// - Parameter count: The number of routes to pop.
    /// - Returns: The popped routes.
    @discardableResult
    public func pop(_ count: Int) -> [R] {
        guard !isLocked else { return [] }
        guard count > 0 && count <= routes.count else { return [] }
        
        var popped: [R] = []
        for _ in 0..<count {
            if let route = pop() {
                popped.append(route)
            }
        }
        return popped
    }
    
    /// Pops to the root of the path.
    public func popToRoot() {
        guard !isLocked else { return }
        guard !routes.isEmpty else { return }
        
        for route in routes.reversed() {
            triggerWillDisappear(route)
        }
        
        routes.removeAll()
        path = NavigationPath()
        breadcrumbs.removeAll()
        
        delegate?.pathManagerDidPopToRoot(self)
    }
    
    /// Pops to a specific route.
    ///
    /// - Parameter route: The route to pop to.
    /// - Returns: `true` if the route was found and popped to.
    @discardableResult
    public func popTo(_ route: R) -> Bool {
        guard let index = routes.lastIndex(where: { $0.path == route.path }) else {
            return false
        }
        
        let count = routes.count - index - 1
        guard count > 0 else { return false }
        
        _ = pop(count)
        return true
    }
    
    /// Replaces the entire path with new routes.
    ///
    /// - Parameter newRoutes: The routes to replace with.
    public func replacePath(with newRoutes: [R]) {
        guard !isLocked else { return }
        
        for route in routes.reversed() {
            triggerWillDisappear(route)
            triggerDidDisappear(route)
        }
        
        routes = newRoutes
        path = NavigationPath()
        breadcrumbs = []
        
        for route in newRoutes {
            path.append(route)
            breadcrumbs.append(Breadcrumb(route: route))
            triggerWillAppear(route)
        }
        
        if let top = newRoutes.last {
            triggerDidAppear(top)
        }
    }
    
    /// Replaces the top route with a new route.
    ///
    /// - Parameter route: The new route.
    public func replaceTop(with route: R) {
        guard !isLocked else { return }
        guard !routes.isEmpty else {
            _ = push(route)
            return
        }
        
        let old = routes.last!
        triggerWillDisappear(old)
        
        routes.removeLast()
        path.removeLast()
        breadcrumbs.removeLast()
        
        triggerDidDisappear(old)
        
        _ = push(route)
    }
    
    // MARK: - Locking
    
    /// Locks navigation, preventing any changes.
    public func lock() {
        isLocked = true
    }
    
    /// Unlocks navigation.
    public func unlock() {
        isLocked = false
    }
    
    /// Performs an action with navigation locked.
    ///
    /// - Parameter action: The action to perform.
    public func withLock(_ action: () -> Void) {
        let wasLocked = isLocked
        isLocked = true
        action()
        isLocked = wasLocked
    }
    
    // MARK: - Path Queries
    
    /// The depth of the current path.
    public var depth: Int {
        routes.count
    }
    
    /// Whether the path is empty.
    public var isEmpty: Bool {
        routes.isEmpty
    }
    
    /// The current (top) route.
    public var current: R? {
        routes.last
    }
    
    /// The root route.
    public var root: R? {
        routes.first
    }
    
    /// The previous route (one below top).
    public var previous: R? {
        guard routes.count >= 2 else { return nil }
        return routes[routes.count - 2]
    }
    
    /// Returns the route at a specific depth.
    ///
    /// - Parameter index: The depth index.
    /// - Returns: The route at the index, or `nil`.
    public func route(at index: Int) -> R? {
        guard routes.indices.contains(index) else { return nil }
        return routes[index]
    }
    
    /// Checks if a route is in the path.
    ///
    /// - Parameter route: The route to check.
    /// - Returns: `true` if the route is in the path.
    public func contains(_ route: R) -> Bool {
        routes.contains { $0.path == route.path }
    }
    
    /// Returns the index of a route in the path.
    ///
    /// - Parameter route: The route to find.
    /// - Returns: The index, or `nil` if not found.
    public func indexOf(_ route: R) -> Int? {
        routes.firstIndex { $0.path == route.path }
    }
    
    // MARK: - Breadcrumbs
    
    /// Returns the breadcrumb trail as titles.
    ///
    /// - Returns: An array of breadcrumb titles.
    public func breadcrumbTitles() -> [String] {
        breadcrumbs.compactMap { $0.title }
    }
    
    /// Returns the breadcrumb trail as paths.
    ///
    /// - Returns: An array of route paths.
    public func breadcrumbPaths() -> [String] {
        breadcrumbs.map { $0.path }
    }
    
    /// Navigates to a specific breadcrumb.
    ///
    /// - Parameter index: The breadcrumb index to navigate to.
    /// - Returns: `true` if navigation was successful.
    @discardableResult
    public func navigateToBreadcrumb(at index: Int) -> Bool {
        guard index >= 0 && index < breadcrumbs.count else { return false }
        
        let count = breadcrumbs.count - index - 1
        if count > 0 {
            _ = pop(count)
        }
        return true
    }
    
    // MARK: - Path Transformers
    
    private func applyPathTransformers() {
        guard !pathTransformers.isEmpty else { return }
        
        var currentRoutes = routes
        for transformer in pathTransformers {
            currentRoutes = transformer(currentRoutes)
        }
        
        if currentRoutes != routes {
            routes = currentRoutes
            path = NavigationPath()
            breadcrumbs = []
            for route in currentRoutes {
                path.append(route)
                breadcrumbs.append(Breadcrumb(route: route))
            }
        }
    }
    
    // MARK: - State
    
    /// Creates a snapshot of the current path state.
    ///
    /// - Returns: A path state snapshot.
    public func createSnapshot() -> PathSnapshot<R> {
        PathSnapshot(
            routes: routes,
            breadcrumbs: breadcrumbs,
            timestamp: Date()
        )
    }
    
    /// Restores from a path snapshot.
    ///
    /// - Parameter snapshot: The snapshot to restore.
    public func restore(from snapshot: PathSnapshot<R>) {
        routes = snapshot.routes
        breadcrumbs = snapshot.breadcrumbs
        path = NavigationPath()
        for route in routes {
            path.append(route)
        }
    }
}

// MARK: - Breadcrumb

/// A breadcrumb entry for navigation tracking.
public struct Breadcrumb<R: Route>: Identifiable, Equatable {
    /// Unique identifier.
    public let id = UUID()
    
    /// The route this breadcrumb represents.
    public let route: R
    
    /// The timestamp when this breadcrumb was created.
    public let timestamp: Date
    
    /// The title for display.
    public var title: String? {
        route.title
    }
    
    /// The path of the route.
    public var path: String {
        route.path
    }
    
    /// Creates a breadcrumb for a route.
    ///
    /// - Parameter route: The route.
    public init(route: R) {
        self.route = route
        self.timestamp = Date()
    }
    
    public static func == (lhs: Breadcrumb<R>, rhs: Breadcrumb<R>) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ValidationResult

/// The result of a route validation.
public struct ValidationResult {
    /// Whether the validation passed.
    public let isValid: Bool
    
    /// An optional message describing the validation result.
    public let message: String?
    
    /// A valid result.
    public static let valid = ValidationResult(isValid: true, message: nil)
    
    /// Creates an invalid result with a message.
    ///
    /// - Parameter message: The validation failure message.
    /// - Returns: An invalid validation result.
    public static func invalid(_ message: String) -> ValidationResult {
        ValidationResult(isValid: false, message: message)
    }
}

// MARK: - PathSnapshot

/// A snapshot of the navigation path state.
public struct PathSnapshot<R: Route>: Codable {
    /// The routes in the path.
    public let routes: [R]
    
    /// The breadcrumbs.
    public let breadcrumbs: [BreadcrumbData<R>]
    
    /// The timestamp of the snapshot.
    public let timestamp: Date
    
    init(routes: [R], breadcrumbs: [Breadcrumb<R>], timestamp: Date) {
        self.routes = routes
        self.breadcrumbs = breadcrumbs.map { BreadcrumbData(route: $0.route, timestamp: $0.timestamp) }
        self.timestamp = timestamp
    }
}

/// Codable breadcrumb data.
public struct BreadcrumbData<R: Route>: Codable {
    public let route: R
    public let timestamp: Date
}

// MARK: - NavigationRejectionReason

/// Reasons why navigation was rejected.
public enum NavigationRejectionReason: Equatable {
    case locked
    case maxDepthReached
    case blocked
    case guardFailed
    case validationFailed(String?)
    case transformerCancelled
}

// MARK: - NavigationPathManagerDelegate

/// Delegate protocol for path manager events.
@MainActor
public protocol NavigationPathManagerDelegate<R>: AnyObject {
    associatedtype R: Route
    
    func pathManager(_ manager: NavigationPathManager<R>, didPush route: R)
    func pathManager(_ manager: NavigationPathManager<R>, didPop route: R)
    func pathManagerDidPopToRoot(_ manager: NavigationPathManager<R>)
    func pathManager(_ manager: NavigationPathManager<R>, didRejectNavigation route: R, reason: NavigationRejectionReason)
}

// MARK: - Default Delegate Implementation

public extension NavigationPathManagerDelegate {
    func pathManager(_ manager: NavigationPathManager<R>, didPush route: R) {}
    func pathManager(_ manager: NavigationPathManager<R>, didPop route: R) {}
    func pathManagerDidPopToRoot(_ manager: NavigationPathManager<R>) {}
    func pathManager(_ manager: NavigationPathManager<R>, didRejectNavigation route: R, reason: NavigationRejectionReason) {}
}

// MARK: - PathBuilder

/// A result builder for constructing navigation paths declaratively.
@resultBuilder
public struct PathBuilder<R: Route> {
    
    public static func buildBlock(_ components: R...) -> [R] {
        components
    }
    
    public static func buildBlock(_ components: [R]...) -> [R] {
        components.flatMap { $0 }
    }
    
    public static func buildOptional(_ component: [R]?) -> [R] {
        component ?? []
    }
    
    public static func buildEither(first component: [R]) -> [R] {
        component
    }
    
    public static func buildEither(second component: [R]) -> [R] {
        component
    }
    
    public static func buildArray(_ components: [[R]]) -> [R] {
        components.flatMap { $0 }
    }
    
    public static func buildExpression(_ expression: R) -> [R] {
        [expression]
    }
    
    public static func buildExpression(_ expression: [R]) -> [R] {
        expression
    }
}

// MARK: - PathManager Extension for PathBuilder

extension NavigationPathManager {
    
    /// Builds a path using the path builder DSL.
    ///
    /// - Parameter builder: A path builder closure.
    public convenience init(@PathBuilder<R> builder: () -> [R]) {
        self.init(initialRoutes: builder())
    }
    
    /// Replaces the path using the path builder DSL.
    ///
    /// - Parameter builder: A path builder closure.
    public func build(@PathBuilder<R> builder: () -> [R]) {
        replacePath(with: builder())
    }
}
