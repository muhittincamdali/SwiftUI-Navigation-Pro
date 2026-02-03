import SwiftUI
import Combine

/// A router that coordinates navigation across multiple tabs.
///
/// `TabRouter` manages a separate ``Router`` for each tab, allowing
/// independent navigation stacks per tab while providing a unified API.
///
/// ```swift
/// @StateObject var tabRouter = TabRouter<AppTab, AppRoute>()
/// ```
@MainActor
public final class TabRouter<Tab: TabItem, R: Route>: ObservableObject {

    // MARK: - Published Properties

    /// The currently selected tab.
    @Published public var selectedTab: Tab

    /// Badge values for each tab, keyed by tab identity.
    @Published public var badges: [Tab: String] = [:]

    // MARK: - Properties

    /// A router for each tab, created lazily.
    private var routers: [Tab: Router<R>] = [:]

    /// History of tab switches for analytics.
    private var tabHistory: [(tab: Tab, timestamp: Date)] = []

    /// Combine cancellables.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates a tab router with the first tab selected.
    public init() {
        guard let firstTab = Tab.allCases.first else {
            fatalError("TabItem must have at least one case")
        }
        self.selectedTab = firstTab
    }

    /// Creates a tab router with a specific initial tab.
    ///
    /// - Parameter initialTab: The tab to select on creation.
    public init(initialTab: Tab) {
        self.selectedTab = initialTab
    }

    // MARK: - Tab Selection

    /// Switches to the specified tab.
    ///
    /// If the tab is already selected, this pops its router to root.
    ///
    /// - Parameter tab: The tab to switch to.
    public func select(_ tab: Tab) {
        if selectedTab == tab {
            router(for: tab).popToRoot()
        } else {
            selectedTab = tab
        }
        tabHistory.append((tab: tab, timestamp: Date()))
    }

    // MARK: - Router Access

    /// Returns the router for the specified tab.
    ///
    /// Creates a new router if one does not exist for the tab.
    ///
    /// - Parameter tab: The tab to get a router for.
    /// - Returns: The ``Router`` associated with the tab.
    public func router(for tab: Tab) -> Router<R> {
        if let existing = routers[tab] {
            return existing
        }
        let newRouter = Router<R>()
        routers[tab] = newRouter
        return newRouter
    }

    /// The router for the currently selected tab.
    public var currentRouter: Router<R> {
        router(for: selectedTab)
    }

    // MARK: - Navigation Convenience

    /// Pushes a route on the currently selected tab's router.
    ///
    /// - Parameter route: The route to push.
    public func push(_ route: R) {
        currentRouter.push(route)
    }

    /// Pops the top route from the currently selected tab's router.
    public func pop() {
        currentRouter.pop()
    }

    /// Pops to root on the currently selected tab's router.
    public func popToRoot() {
        currentRouter.popToRoot()
    }

    /// Pops all tabs to their root views.
    public func popAllToRoot() {
        for tab in Tab.allCases {
            router(for: tab).popToRoot()
        }
    }

    // MARK: - Badge Management

    /// Sets a badge value for a tab.
    ///
    /// - Parameters:
    ///   - badge: The badge string (e.g., "3"). Pass `nil` to clear.
    ///   - tab: The tab to badge.
    public func setBadge(_ badge: String?, for tab: Tab) {
        if let badge {
            badges[tab] = badge
        } else {
            badges.removeValue(forKey: tab)
        }
    }

    /// Clears all badges.
    public func clearAllBadges() {
        badges.removeAll()
    }

    // MARK: - Deep Linking

    /// Handles a deep link by switching to the appropriate tab and pushing the route.
    ///
    /// - Parameters:
    ///   - route: The route from deep link parsing.
    ///   - tab: The tab that should handle this route.
    public func handleDeepLink(route: R, on tab: Tab) {
        select(tab)
        currentRouter.popToRoot(animation: nil)
        currentRouter.push(route)
    }
}

/// A SwiftUI view that renders a tab-based interface using ``TabRouter``.
public struct TabRouterView<Tab: TabItem, R: Route, Content: View>: View {

    @ObservedObject var router: TabRouter<Tab, R>
    let tabContent: (Tab) -> Content

    /// Creates a tab router view.
    ///
    /// - Parameters:
    ///   - router: The tab router to drive the interface.
    ///   - tabContent: A view builder that creates content for each tab.
    public init(
        router: TabRouter<Tab, R>,
        @ViewBuilder tabContent: @escaping (Tab) -> Content
    ) {
        self.router = router
        self.tabContent = tabContent
    }

    public var body: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(Array(Tab.allCases), id: \.self) { tab in
                NavigationStack(path: router.router(for: tab).$navigationPath.projectedValue) {
                    tabContent(tab)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
                .tag(tab)
                .badge(router.badges[tab] ?? tab.badge)
            }
        }
    }
}
