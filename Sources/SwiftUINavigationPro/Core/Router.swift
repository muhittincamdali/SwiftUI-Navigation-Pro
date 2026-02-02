import SwiftUI
import Combine

/// The main navigation router that manages a stack of routes and presentations.
///
/// `Router` is a generic class that works with any type conforming to ``Route``.
/// It wraps SwiftUI's `NavigationPath` and provides a programmatic API for
/// pushing, popping, and presenting routes.
///
/// ```swift
/// @StateObject var router = Router<AppRoute>()
/// ```
@MainActor
public final class Router<R: Route>: ObservableObject {

    // MARK: - Published Properties

    /// The current navigation path backing the `NavigationStack`.
    @Published public var navigationPath = NavigationPath()

    /// The route currently presented as a sheet, if any.
    @Published public var presentedSheet: R?

    /// The route currently presented as a full-screen cover, if any.
    @Published public var presentedFullScreenCover: R?

    /// Whether a sheet is currently being presented.
    @Published public var isSheetPresented: Bool = false

    /// Whether a full-screen cover is currently being presented.
    @Published public var isFullScreenCoverPresented: Bool = false

    // MARK: - Internal State

    /// The ordered stack of routes for path-based iteration.
    private(set) var routeStack: [R] = []

    /// History of all navigated routes for analytics or debugging.
    private var navigationHistory: [NavigationEntry<R>] = []

    /// Subscriptions for Combine pipelines.
    private var cancellables = Set<AnyCancellable>()

    /// Optional delegate to receive navigation lifecycle events.
    public weak var delegate: (any RouterDelegate<R>)?

    // MARK: - Initialization

    /// Creates a new router with an empty navigation stack.
    public init() {
        setupBindings()
    }

    // MARK: - Push

    /// Pushes a route onto the navigation stack.
    ///
    /// - Parameters:
    ///   - route: The route to navigate to.
    ///   - animation: An optional animation applied to the transition.
    public func push(_ route: R, animation: Animation? = .default) {
        withAnimation(animation) {
            routeStack.append(route)
            navigationPath.append(route)
        }
        recordEntry(route, action: .push)
        delegate?.router(self, didNavigateTo: route)
    }

    /// Pushes multiple routes onto the stack at once.
    ///
    /// - Parameter routes: An array of routes to push sequentially.
    public func push(contentsOf routes: [R]) {
        for route in routes {
            routeStack.append(route)
            navigationPath.append(route)
        }
        if let last = routes.last {
            recordEntry(last, action: .push)
        }
    }

    // MARK: - Pop

    /// Pops the top route from the navigation stack.
    ///
    /// - Parameter animation: An optional animation applied to the transition.
    public func pop(animation: Animation? = .default) {
        guard !routeStack.isEmpty else { return }
        withAnimation(animation) {
            let removed = routeStack.removeLast()
            navigationPath.removeLast()
            recordEntry(removed, action: .pop)
            delegate?.router(self, didPopRoute: removed)
        }
    }

    /// Pops all routes and returns to the root view.
    ///
    /// - Parameter animation: An optional animation applied to the transition.
    public func popToRoot(animation: Animation? = .default) {
        guard !routeStack.isEmpty else { return }
        withAnimation(animation) {
            routeStack.removeAll()
            navigationPath = NavigationPath()
        }
        recordEntry(nil, action: .popToRoot)
        delegate?.routerDidPopToRoot(self)
    }

    /// Pops routes until the given route is at the top of the stack.
    ///
    /// - Parameter route: The target route to pop to.
    public func popTo(_ route: R) {
        guard let index = routeStack.lastIndex(where: { $0.path == route.path }) else { return }
        let count = routeStack.count - index - 1
        guard count > 0 else { return }
        routeStack.removeLast(count)
        navigationPath.removeLast(count)
    }

    // MARK: - Presentation

    /// Presents a route using the specified presentation style.
    ///
    /// - Parameters:
    ///   - route: The route to present.
    ///   - style: The presentation style (`.sheet` or `.fullScreenCover`).
    public func present(_ route: R, style: PresentationStyle) {
        switch style {
        case .sheet:
            presentedSheet = route
            isSheetPresented = true
        case .fullScreenCover:
            presentedFullScreenCover = route
            isFullScreenCoverPresented = true
        }
        recordEntry(route, action: .present(style))
    }

    /// Dismisses the currently presented sheet or full-screen cover.
    public func dismiss() {
        if isSheetPresented {
            isSheetPresented = false
            presentedSheet = nil
        }
        if isFullScreenCoverPresented {
            isFullScreenCoverPresented = false
            presentedFullScreenCover = nil
        }
    }

    // MARK: - Deep Linking

    /// Handles a deep link URL by parsing it with the provided parser.
    ///
    /// - Parameters:
    ///   - url: The incoming URL to handle.
    ///   - parser: A ``DeepLinkParser`` that converts URLs to routes.
    /// - Returns: `true` if the URL was successfully parsed and navigated.
    @discardableResult
    public func handleDeepLink(_ url: URL, parser: DeepLinkParser<R>) -> Bool {
        guard let route = parser.parse(url) else { return false }
        popToRoot(animation: nil)
        push(route)
        return true
    }

    // MARK: - State Persistence

    /// Encodes the current navigation state for persistence.
    ///
    /// - Returns: A `Data` representation of the navigation state.
    public func encodeState() throws -> Data {
        let state = NavigationState(routes: routeStack)
        return try JSONEncoder().encode(state)
    }

    /// Restores navigation state from previously encoded data.
    ///
    /// - Parameter data: The encoded navigation state.
    public func restoreState(from data: Data) throws {
        let state = try JSONDecoder().decode(NavigationState<R>.self, from: data)
        routeStack = state.routes
        navigationPath = NavigationPath()
        for route in state.routes {
            navigationPath.append(route)
        }
    }

    // MARK: - Query

    /// The number of routes currently on the stack.
    public var stackDepth: Int {
        routeStack.count
    }

    /// The route at the top of the stack, if any.
    public var topRoute: R? {
        routeStack.last
    }

    /// Whether the navigation stack is empty (at root).
    public var isAtRoot: Bool {
        routeStack.isEmpty
    }

    // MARK: - Private

    private func setupBindings() {
        $isSheetPresented
            .dropFirst()
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.presentedSheet = nil
            }
            .store(in: &cancellables)

        $isFullScreenCoverPresented
            .dropFirst()
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.presentedFullScreenCover = nil
            }
            .store(in: &cancellables)
    }

    private func recordEntry(_ route: R?, action: NavigationAction) {
        let entry = NavigationEntry(route: route, action: action, timestamp: Date())
        navigationHistory.append(entry)
    }
}

// MARK: - Supporting Types

/// The style used when presenting a route modally.
public enum PresentationStyle: Codable, Sendable {
    /// Present as a sheet.
    case sheet
    /// Present as a full-screen cover.
    case fullScreenCover
}

/// Actions recorded in navigation history.
enum NavigationAction {
    case push
    case pop
    case popToRoot
    case present(PresentationStyle)
}

/// A single navigation history entry.
struct NavigationEntry<R: Route> {
    let route: R?
    let action: NavigationAction
    let timestamp: Date
}

/// Delegate protocol for receiving navigation lifecycle events.
@MainActor
public protocol RouterDelegate<R>: AnyObject {
    associatedtype R: Route
    func router(_ router: Router<R>, didNavigateTo route: R)
    func router(_ router: Router<R>, didPopRoute route: R)
    func routerDidPopToRoot(_ router: Router<R>)
}

/// A SwiftUI view that wraps `NavigationStack` with the router.
public struct NavigationStackView<R: Route, Content: View>: View {
    @ObservedObject var router: Router<R>
    let content: () -> Content

    public init(router: Router<R>, @ViewBuilder content: @escaping () -> Content) {
        self.router = router
        self.content = content
    }

    public var body: some View {
        NavigationStack(path: $router.navigationPath) {
            content()
        }
    }
}
