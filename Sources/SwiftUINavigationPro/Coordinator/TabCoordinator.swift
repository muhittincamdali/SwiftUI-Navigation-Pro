import SwiftUI
import Combine

// MARK: - Tab Item Protocol

/// A protocol representing a tab item in a tab-based navigation.
///
/// Conform to this protocol to define your app's tabs.
///
/// ```swift
/// enum AppTab: TabItem {
///     case home
///     case search
///     case profile
///
///     var title: String {
///         switch self {
///         case .home: return "Home"
///         case .search: return "Search"
///         case .profile: return "Profile"
///         }
///     }
///
///     var icon: String {
///         switch self {
///         case .home: return "house"
///         case .search: return "magnifyingglass"
///         case .profile: return "person"
///         }
///     }
/// }
/// ```
public protocol TabItem: Hashable, Identifiable, CaseIterable, Sendable {
    /// The display title for this tab.
    var title: String { get }
    /// The SF Symbol name for this tab's icon.
    var icon: String { get }
    /// The SF Symbol name for the selected state (optional).
    var selectedIcon: String { get }
    /// The badge value for this tab (optional).
    var badge: String? { get }
    /// Whether this tab is enabled.
    var isEnabled: Bool { get }
}

public extension TabItem {
    var id: Self { self }
    var selectedIcon: String { "\(icon).fill" }
    var badge: String? { nil }
    var isEnabled: Bool { true }
}

// MARK: - Tab Event

/// Events that occur during tab navigation.
public enum TabEvent<Tab: TabItem>: Sendable {
    /// A tab was selected.
    case tabSelected(tab: Tab, previousTab: Tab?)
    /// A tab was double-tapped.
    case tabDoubleTapped(tab: Tab)
    /// A tab's badge was updated.
    case badgeUpdated(tab: Tab, badge: String?)
    /// The tab bar visibility changed.
    case visibilityChanged(isVisible: Bool)
    /// A tab was locked/unlocked.
    case tabLockChanged(tab: Tab, isLocked: Bool)
}

// MARK: - Tab State

/// The navigation state for a single tab.
public struct TabNavigationState<Tab: TabItem>: Sendable {
    /// The tab this state belongs to.
    public let tab: Tab
    /// The navigation path for this tab.
    public var path: [AnyHashable]
    /// Whether this tab has a modal presented.
    public var hasModal: Bool
    /// The scroll position for this tab.
    public var scrollPosition: CGFloat?
    
    /// Creates a tab navigation state.
    public init(tab: Tab, path: [AnyHashable] = [], hasModal: Bool = false, scrollPosition: CGFloat? = nil) {
        self.tab = tab
        self.path = path
        self.hasModal = hasModal
        self.scrollPosition = scrollPosition
    }
    
    /// Whether this tab is at the root.
    public var isAtRoot: Bool { path.isEmpty }
}

// MARK: - Tab Configuration

/// Configuration options for a tab coordinator.
public struct TabConfiguration<Tab: TabItem>: Sendable {
    /// The initial tab to display.
    public let initialTab: Tab
    /// Whether to preserve navigation state when switching tabs.
    public let preserveState: Bool
    /// Whether to allow double-tap to pop to root.
    public let doubleTapPopsToRoot: Bool
    /// Whether to animate tab changes.
    public let animateTabChanges: Bool
    /// Tabs that should be hidden from the tab bar.
    public let hiddenTabs: Set<Tab>
    /// The tab bar position.
    public let tabBarPosition: TabBarPosition
    /// Whether to hide the tab bar when keyboard is shown.
    public let hideOnKeyboard: Bool
    
    /// Creates a tab configuration.
    public init(
        initialTab: Tab,
        preserveState: Bool = true,
        doubleTapPopsToRoot: Bool = true,
        animateTabChanges: Bool = true,
        hiddenTabs: Set<Tab> = [],
        tabBarPosition: TabBarPosition = .bottom,
        hideOnKeyboard: Bool = true
    ) {
        self.initialTab = initialTab
        self.preserveState = preserveState
        self.doubleTapPopsToRoot = doubleTapPopsToRoot
        self.animateTabChanges = animateTabChanges
        self.hiddenTabs = hiddenTabs
        self.tabBarPosition = tabBarPosition
        self.hideOnKeyboard = hideOnKeyboard
    }
}

/// The position of the tab bar.
public enum TabBarPosition: Sendable {
    case top
    case bottom
}

// MARK: - Tab Coordinator

/// A coordinator that manages tab-based navigation.
///
/// `TabCoordinator` provides centralized control over tab navigation,
/// including state preservation, badge management, and deep linking.
///
/// ```swift
/// @StateObject private var tabs = TabCoordinator<AppTab>(
///     configuration: .init(initialTab: .home)
/// )
///
/// var body: some View {
///     TabCoordinatorView(coordinator: tabs) { tab in
///         switch tab {
///         case .home: HomeView()
///         case .search: SearchView()
///         case .profile: ProfileView()
///         }
///     }
/// }
/// ```
@MainActor
public final class TabCoordinator<Tab: TabItem>: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The currently selected tab.
    @Published public private(set) var selectedTab: Tab {
        didSet {
            if oldValue != selectedTab {
                eventSubject.send(.tabSelected(tab: selectedTab, previousTab: oldValue))
            }
        }
    }
    
    /// The navigation state for each tab.
    @Published public private(set) var tabStates: [Tab: TabNavigationState<Tab>] = [:]
    
    /// Whether the tab bar is visible.
    @Published public var isTabBarVisible: Bool = true {
        didSet {
            if oldValue != isTabBarVisible {
                eventSubject.send(.visibilityChanged(isVisible: isTabBarVisible))
            }
        }
    }
    
    /// Badge values for each tab.
    @Published public private(set) var badges: [Tab: String] = [:]
    
    /// Locked tabs that cannot be selected.
    @Published public private(set) var lockedTabs: Set<Tab> = []
    
    /// The previously selected tab.
    @Published public private(set) var previousTab: Tab?
    
    // MARK: - Properties
    
    /// The tab configuration.
    public let configuration: TabConfiguration<Tab>
    
    /// All available tabs.
    public var allTabs: [Tab] {
        Tab.allCases.filter { !configuration.hiddenTabs.contains($0) }
    }
    
    /// The event publisher.
    private let eventSubject = PassthroughSubject<TabEvent<Tab>, Never>()
    
    /// Publisher for tab events.
    public var events: AnyPublisher<TabEvent<Tab>, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Cancellables for subscriptions.
    private var cancellables = Set<AnyCancellable>()
    
    /// Last tap times for double-tap detection.
    private var lastTapTimes: [Tab: Date] = [:]
    
    /// The double-tap threshold in seconds.
    private let doubleTapThreshold: TimeInterval = 0.3
    
    // MARK: - Initialization
    
    /// Creates a tab coordinator with the given configuration.
    ///
    /// - Parameter configuration: The tab configuration.
    public init(configuration: TabConfiguration<Tab>) {
        self.configuration = configuration
        self.selectedTab = configuration.initialTab
        
        // Initialize state for all tabs
        for tab in Tab.allCases {
            tabStates[tab] = TabNavigationState(tab: tab)
        }
        
        setupKeyboardObserver()
    }
    
    /// Creates a tab coordinator with the default first tab.
    public convenience init() where Tab: CaseIterable {
        let firstTab = Tab.allCases.first!
        self.init(configuration: TabConfiguration(initialTab: firstTab))
    }
    
    // MARK: - Tab Selection
    
    /// Selects a tab.
    ///
    /// - Parameters:
    ///   - tab: The tab to select.
    ///   - animated: Whether to animate the selection.
    public func select(_ tab: Tab, animated: Bool = true) {
        guard tab.isEnabled && !lockedTabs.contains(tab) else { return }
        guard !configuration.hiddenTabs.contains(tab) else { return }
        
        let now = Date()
        
        // Check for double-tap
        if configuration.doubleTapPopsToRoot,
           tab == selectedTab,
           let lastTap = lastTapTimes[tab],
           now.timeIntervalSince(lastTap) < doubleTapThreshold {
            popToRoot(animated: animated)
            eventSubject.send(.tabDoubleTapped(tab: tab))
            lastTapTimes[tab] = nil
            return
        }
        
        lastTapTimes[tab] = now
        
        if tab != selectedTab {
            previousTab = selectedTab
            
            if configuration.animateTabChanges && animated {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = tab
                }
            } else {
                selectedTab = tab
            }
        }
    }
    
    /// Selects the next tab.
    public func selectNext() {
        let tabs = allTabs
        guard let currentIndex = tabs.firstIndex(of: selectedTab),
              currentIndex < tabs.count - 1 else { return }
        select(tabs[currentIndex + 1])
    }
    
    /// Selects the previous tab.
    public func selectPrevious() {
        let tabs = allTabs
        guard let currentIndex = tabs.firstIndex(of: selectedTab),
              currentIndex > 0 else { return }
        select(tabs[currentIndex - 1])
    }
    
    /// Returns to the previously selected tab.
    public func selectPreviousTab() {
        guard let previous = previousTab else { return }
        select(previous)
    }
    
    // MARK: - Navigation State
    
    /// Pushes a route onto the current tab's navigation stack.
    ///
    /// - Parameter route: The route to push.
    public func push<R: Hashable>(_ route: R) {
        var state = tabStates[selectedTab] ?? TabNavigationState(tab: selectedTab)
        state.path.append(AnyHashable(route))
        tabStates[selectedTab] = state
    }
    
    /// Pops the top route from the current tab's navigation stack.
    ///
    /// - Parameter animated: Whether to animate the pop.
    public func pop(animated: Bool = true) {
        var state = tabStates[selectedTab] ?? TabNavigationState(tab: selectedTab)
        guard !state.path.isEmpty else { return }
        state.path.removeLast()
        tabStates[selectedTab] = state
    }
    
    /// Pops to the root of the current tab.
    ///
    /// - Parameter animated: Whether to animate the pop.
    public func popToRoot(animated: Bool = true) {
        var state = tabStates[selectedTab] ?? TabNavigationState(tab: selectedTab)
        state.path.removeAll()
        tabStates[selectedTab] = state
    }
    
    /// Pops to the root of a specific tab.
    ///
    /// - Parameters:
    ///   - tab: The tab to pop to root.
    ///   - animated: Whether to animate the pop.
    public func popToRoot(for tab: Tab, animated: Bool = true) {
        var state = tabStates[tab] ?? TabNavigationState(tab: tab)
        state.path.removeAll()
        tabStates[tab] = state
    }
    
    /// Pops all tabs to their roots.
    public func popAllToRoot() {
        for tab in Tab.allCases {
            var state = tabStates[tab] ?? TabNavigationState(tab: tab)
            state.path.removeAll()
            tabStates[tab] = state
        }
    }
    
    /// Gets the navigation depth for a tab.
    ///
    /// - Parameter tab: The tab to check.
    /// - Returns: The number of routes on the navigation stack.
    public func navigationDepth(for tab: Tab) -> Int {
        tabStates[tab]?.path.count ?? 0
    }
    
    /// Checks if a tab is at its root.
    ///
    /// - Parameter tab: The tab to check.
    /// - Returns: Whether the tab is at root.
    public func isAtRoot(for tab: Tab) -> Bool {
        tabStates[tab]?.isAtRoot ?? true
    }
    
    // MARK: - Badge Management
    
    /// Sets the badge for a tab.
    ///
    /// - Parameters:
    ///   - badge: The badge value (nil to remove).
    ///   - tab: The tab to update.
    public func setBadge(_ badge: String?, for tab: Tab) {
        if badge != badges[tab] {
            badges[tab] = badge
            eventSubject.send(.badgeUpdated(tab: tab, badge: badge))
        }
    }
    
    /// Sets a numeric badge for a tab.
    ///
    /// - Parameters:
    ///   - count: The badge count (0 to remove).
    ///   - tab: The tab to update.
    public func setBadgeCount(_ count: Int, for tab: Tab) {
        let badge = count > 0 ? "\(count)" : nil
        setBadge(badge, for: tab)
    }
    
    /// Increments the badge count for a tab.
    ///
    /// - Parameter tab: The tab to increment.
    public func incrementBadge(for tab: Tab) {
        let currentCount = Int(badges[tab] ?? "0") ?? 0
        setBadgeCount(currentCount + 1, for: tab)
    }
    
    /// Clears the badge for a tab.
    ///
    /// - Parameter tab: The tab to clear.
    public func clearBadge(for tab: Tab) {
        setBadge(nil, for: tab)
    }
    
    /// Clears all badges.
    public func clearAllBadges() {
        for tab in Tab.allCases {
            clearBadge(for: tab)
        }
    }
    
    // MARK: - Tab Locking
    
    /// Locks a tab, preventing selection.
    ///
    /// - Parameter tab: The tab to lock.
    public func lock(_ tab: Tab) {
        if !lockedTabs.contains(tab) {
            lockedTabs.insert(tab)
            eventSubject.send(.tabLockChanged(tab: tab, isLocked: true))
        }
    }
    
    /// Unlocks a tab.
    ///
    /// - Parameter tab: The tab to unlock.
    public func unlock(_ tab: Tab) {
        if lockedTabs.contains(tab) {
            lockedTabs.remove(tab)
            eventSubject.send(.tabLockChanged(tab: tab, isLocked: false))
        }
    }
    
    /// Checks if a tab is locked.
    ///
    /// - Parameter tab: The tab to check.
    /// - Returns: Whether the tab is locked.
    public func isLocked(_ tab: Tab) -> Bool {
        lockedTabs.contains(tab)
    }
    
    // MARK: - Tab Bar Visibility
    
    /// Shows the tab bar.
    ///
    /// - Parameter animated: Whether to animate the show.
    public func showTabBar(animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                isTabBarVisible = true
            }
        } else {
            isTabBarVisible = true
        }
    }
    
    /// Hides the tab bar.
    ///
    /// - Parameter animated: Whether to animate the hide.
    public func hideTabBar(animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                isTabBarVisible = false
            }
        } else {
            isTabBarVisible = false
        }
    }
    
    /// Toggles the tab bar visibility.
    ///
    /// - Parameter animated: Whether to animate the toggle.
    public func toggleTabBar(animated: Bool = true) {
        if isTabBarVisible {
            hideTabBar(animated: animated)
        } else {
            showTabBar(animated: animated)
        }
    }
    
    // MARK: - State Preservation
    
    /// Saves the current tab state.
    ///
    /// - Parameter key: The key to save under.
    public func saveState(key: String) {
        let state: [String: Any] = [
            "selectedTab": String(describing: selectedTab),
            "isTabBarVisible": isTabBarVisible
        ]
        UserDefaults.standard.set(state, forKey: key)
    }
    
    /// Clears saved tab state.
    ///
    /// - Parameter key: The key to clear.
    public func clearSavedState(key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // MARK: - Private Methods
    
    private func setupKeyboardObserver() {
        guard configuration.hideOnKeyboard else { return }
        
        #if os(iOS)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] _ in
                self?.hideTabBar(animated: true)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                self?.showTabBar(animated: true)
            }
            .store(in: &cancellables)
        #endif
    }
}

// MARK: - Tab Coordinator View

/// A view that displays tab-based navigation.
public struct TabCoordinatorView<Tab: TabItem, Content: View>: View {
    @ObservedObject private var coordinator: TabCoordinator<Tab>
    private let content: (Tab) -> Content
    
    /// Creates a tab coordinator view.
    ///
    /// - Parameters:
    ///   - coordinator: The tab coordinator.
    ///   - content: A view builder for each tab's content.
    public init(
        coordinator: TabCoordinator<Tab>,
        @ViewBuilder content: @escaping (Tab) -> Content
    ) {
        self.coordinator = coordinator
        self.content = content
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if coordinator.configuration.tabBarPosition == .top && coordinator.isTabBarVisible {
                CustomTabBar(coordinator: coordinator)
            }
            
            ZStack {
                ForEach(coordinator.allTabs) { tab in
                    content(tab)
                        .opacity(tab == coordinator.selectedTab ? 1 : 0)
                        .allowsHitTesting(tab == coordinator.selectedTab)
                }
            }
            
            if coordinator.configuration.tabBarPosition == .bottom && coordinator.isTabBarVisible {
                CustomTabBar(coordinator: coordinator)
            }
        }
    }
}

// MARK: - Custom Tab Bar

/// A customizable tab bar view.
public struct CustomTabBar<Tab: TabItem>: View {
    @ObservedObject private var coordinator: TabCoordinator<Tab>
    
    public init(coordinator: TabCoordinator<Tab>) {
        self.coordinator = coordinator
    }
    
    public var body: some View {
        HStack {
            ForEach(coordinator.allTabs) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: tab == coordinator.selectedTab,
                    badge: coordinator.badges[tab],
                    isLocked: coordinator.isLocked(tab),
                    action: { coordinator.select(tab) }
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Tab Bar Button

/// A single tab bar button.
public struct TabBarButton<Tab: TabItem>: View {
    let tab: Tab
    let isSelected: Bool
    let badge: String?
    let isLocked: Bool
    let action: () -> Void
    
    public init(
        tab: Tab,
        isSelected: Bool,
        badge: String? = nil,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) {
        self.tab = tab
        self.isSelected = isSelected
        self.badge = badge
        self.isLocked = isLocked
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                    
                    if let badge = badge {
                        BadgeView(text: badge)
                            .offset(x: 8, y: -4)
                    }
                    
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .offset(x: 10, y: 10)
                    }
                }
                
                Text(tab.title)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
        }
        .disabled(isLocked || !tab.isEnabled)
        .opacity(isLocked ? 0.5 : 1.0)
    }
}

// MARK: - Badge View

/// A badge view for tab bar buttons.
public struct BadgeView: View {
    let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.red)
            )
            .fixedSize()
    }
}

// MARK: - Environment Key

private struct TabCoordinatorKey: EnvironmentKey {
    static let defaultValue: AnyObject? = nil
}

public extension EnvironmentValues {
    /// The current tab coordinator in the environment.
    var tabCoordinator: AnyObject? {
        get { self[TabCoordinatorKey.self] }
        set { self[TabCoordinatorKey.self] = newValue }
    }
}

// MARK: - View Extensions

public extension View {
    /// Injects a tab coordinator into the environment.
    ///
    /// - Parameter coordinator: The tab coordinator.
    /// - Returns: A view with the coordinator in its environment.
    func tabCoordinator<Tab: TabItem>(_ coordinator: TabCoordinator<Tab>) -> some View {
        environment(\.tabCoordinator, coordinator)
    }
    
    /// Hides the tab bar when this view appears.
    ///
    /// - Parameter coordinator: The tab coordinator to control.
    /// - Returns: A view that hides the tab bar on appear.
    func hidesTabBar<Tab: TabItem>(_ coordinator: TabCoordinator<Tab>) -> some View {
        onAppear { coordinator.hideTabBar() }
            .onDisappear { coordinator.showTabBar() }
    }
}
