import SwiftUI
import Combine

/// A base coordinator that manages a navigation flow.
///
/// Subclass `Coordinator` to create reusable navigation flows such as
/// onboarding, authentication, or checkout. Each coordinator owns its
/// own router and can communicate with a parent router.
///
/// ```swift
/// class OnboardingCoordinator: Coordinator<AppRoute> {
///     override func start() {
///         push(.welcome)
///     }
/// }
/// ```
@MainActor
open class Coordinator<R: Route>: ObservableObject, Identifiable {

    // MARK: - Properties

    /// Unique identifier for this coordinator instance.
    public let id = UUID()

    /// The router owned by this coordinator.
    @Published public var router: Router<R>

    /// The parent router, used to communicate navigation events upstream.
    public weak var parentRouter: Router<R>?

    /// Child coordinators managed by this coordinator.
    private(set) var childCoordinators: [UUID: any Identifiable] = [:]

    /// Combine cancellables for this coordinator's subscriptions.
    var cancellables = Set<AnyCancellable>()

    /// Whether this coordinator has been started.
    private(set) var isStarted: Bool = false

    /// A completion handler called when the coordinator finishes.
    public var onFinish: (() -> Void)?

    // MARK: - Initialization

    /// Creates a coordinator with an optional parent router.
    ///
    /// - Parameter parentRouter: The parent router for upstream navigation.
    public init(parentRouter: Router<R>? = nil) {
        self.router = Router<R>()
        self.parentRouter = parentRouter
    }

    // MARK: - Lifecycle

    /// Starts the coordinator flow.
    ///
    /// Override this method to define the initial route for your flow.
    /// Always call `super.start()` first.
    open func start() {
        isStarted = true
    }

    /// Finishes the coordinator and notifies the parent.
    ///
    /// Call this when the coordinator's flow is complete. It pops back to
    /// the parent's previous state and triggers the `onFinish` callback.
    open func finish() {
        childCoordinators.removeAll()
        onFinish?()
    }

    // MARK: - Child Coordinator Management

    /// Adds a child coordinator.
    ///
    /// - Parameter coordinator: The child coordinator to add.
    public func addChild<C: Coordinator<R>>(_ coordinator: C) {
        childCoordinators[coordinator.id] = coordinator
        coordinator.parentRouter = router
    }

    /// Removes a child coordinator by its identifier.
    ///
    /// - Parameter id: The unique identifier of the child to remove.
    public func removeChild(id: UUID) {
        childCoordinators.removeValue(forKey: id)
    }

    /// Removes a child coordinator.
    ///
    /// - Parameter coordinator: The child coordinator to remove.
    public func removeChild<C: Coordinator<R>>(_ coordinator: C) {
        childCoordinators.removeValue(forKey: coordinator.id)
    }

    // MARK: - Navigation Convenience

    /// Pushes a route onto this coordinator's router.
    ///
    /// - Parameter route: The route to push.
    public func push(_ route: R) {
        router.push(route)
    }

    /// Pops the top route from this coordinator's router.
    public func pop() {
        router.pop()
    }

    /// Pops to the root of this coordinator's router.
    public func popToRoot() {
        router.popToRoot()
    }

    /// Presents a route modally using this coordinator's router.
    ///
    /// - Parameters:
    ///   - route: The route to present.
    ///   - style: The presentation style.
    public func present(_ route: R, style: PresentationStyle = .sheet) {
        router.present(route, style: style)
    }

    /// Dismisses any modal presentation from this coordinator's router.
    public func dismiss() {
        router.dismiss()
    }
}

// MARK: - Hashable

extension Coordinator: Hashable {
    public static func == (lhs: Coordinator<R>, rhs: Coordinator<R>) -> Bool {
        lhs.id == rhs.id
    }

    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
