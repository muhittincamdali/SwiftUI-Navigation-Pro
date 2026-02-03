import SwiftUI
import Combine

// MARK: - History Entry

/// A single entry in the navigation history.
public struct HistoryEntry<Route: Hashable>: Identifiable, Sendable {
    /// The unique identifier for this entry.
    public let id: UUID
    /// The route for this entry.
    public let route: Route
    /// The timestamp when this entry was created.
    public let timestamp: Date
    /// The source of navigation (push, pop, replace, etc.).
    public let source: NavigationSource
    /// Metadata associated with this entry.
    public let metadata: [String: String]
    /// The duration spent on this route (if known).
    public var duration: TimeInterval?
    
    /// Creates a history entry.
    public init(
        id: UUID = UUID(),
        route: Route,
        timestamp: Date = Date(),
        source: NavigationSource = .unknown,
        metadata: [String: String] = [:],
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.route = route
        self.timestamp = timestamp
        self.source = source
        self.metadata = metadata
        self.duration = duration
    }
}

// MARK: - Navigation Source

/// The source or trigger of a navigation action.
public enum NavigationSource: String, Sendable {
    /// A programmatic push.
    case push
    /// A programmatic pop.
    case pop
    /// A back button press.
    case backButton
    /// A swipe gesture.
    case swipeGesture
    /// A deep link.
    case deepLink
    /// A tab switch.
    case tabSwitch
    /// A modal presentation.
    case modal
    /// A modal dismissal.
    case modalDismiss
    /// A replacement navigation.
    case replace
    /// An unknown source.
    case unknown
}

// MARK: - History Event

/// Events that occur in the navigation history.
public enum HistoryEvent<Route: Hashable>: Sendable {
    /// A new entry was added.
    case entryAdded(HistoryEntry<Route>)
    /// An entry was removed.
    case entryRemoved(HistoryEntry<Route>)
    /// The history was cleared.
    case historyCleared
    /// The history was restored from persistence.
    case historyRestored(count: Int)
    /// The history limit was reached.
    case limitReached(current: Int, max: Int)
}

// MARK: - History Configuration

/// Configuration for navigation history tracking.
public struct HistoryConfiguration: Sendable {
    /// The maximum number of entries to keep.
    public let maxEntries: Int
    /// Whether to persist history.
    public let persistHistory: Bool
    /// The key for persisted history.
    public let persistenceKey: String?
    /// Whether to track timestamps.
    public let trackTimestamps: Bool
    /// Whether to track durations.
    public let trackDurations: Bool
    /// Whether to allow duplicates in sequence.
    public let allowDuplicates: Bool
    /// Whether to track metadata.
    public let trackMetadata: Bool
    
    /// Creates a history configuration.
    public init(
        maxEntries: Int = 100,
        persistHistory: Bool = false,
        persistenceKey: String? = nil,
        trackTimestamps: Bool = true,
        trackDurations: Bool = true,
        allowDuplicates: Bool = true,
        trackMetadata: Bool = true
    ) {
        self.maxEntries = maxEntries
        self.persistHistory = persistHistory
        self.persistenceKey = persistenceKey
        self.trackTimestamps = trackTimestamps
        self.trackDurations = trackDurations
        self.allowDuplicates = allowDuplicates
        self.trackMetadata = trackMetadata
    }
    
    /// The default configuration.
    public static let `default` = HistoryConfiguration()
    
    /// A minimal configuration (no persistence, no metadata).
    public static let minimal = HistoryConfiguration(
        maxEntries: 50,
        persistHistory: false,
        trackMetadata: false
    )
    
    /// A full configuration with persistence.
    public static let full = HistoryConfiguration(
        maxEntries: 200,
        persistHistory: true,
        persistenceKey: "navigation_history",
        trackMetadata: true
    )
}

// MARK: - Navigation History

/// Tracks and manages navigation history.
///
/// `NavigationHistory` maintains a stack of navigation entries,
/// supporting operations like undo, redo, and history-based navigation.
///
/// ```swift
/// @StateObject private var history = NavigationHistory<AppRoute>()
///
/// // Add to history
/// history.add(.home)
///
/// // Navigate back in history
/// if let previous = history.goBack() {
///     navigator.navigate(to: previous)
/// }
///
/// // Query history
/// let recentRoutes = history.recentEntries(limit: 5)
/// ```
@MainActor
public final class NavigationHistory<Route: Hashable>: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The complete history stack.
    @Published public private(set) var entries: [HistoryEntry<Route>] = []
    
    /// The current position in the history (for forward/back navigation).
    @Published public private(set) var currentIndex: Int = -1
    
    /// The number of entries in the history.
    @Published public private(set) var count: Int = 0
    
    /// Whether the history can go back.
    @Published public private(set) var canGoBack: Bool = false
    
    /// Whether the history can go forward.
    @Published public private(set) var canGoForward: Bool = false
    
    // MARK: - Properties
    
    /// The history configuration.
    public let configuration: HistoryConfiguration
    
    /// The event publisher.
    private let eventSubject = PassthroughSubject<HistoryEvent<Route>, Never>()
    
    /// Publisher for history events.
    public var events: AnyPublisher<HistoryEvent<Route>, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Cancellables for subscriptions.
    private var cancellables = Set<AnyCancellable>()
    
    /// The timestamp of the last entry (for duration tracking).
    private var lastEntryTimestamp: Date?
    
    // MARK: - Computed Properties
    
    /// The current entry (at the current index).
    public var currentEntry: HistoryEntry<Route>? {
        guard currentIndex >= 0 && currentIndex < entries.count else { return nil }
        return entries[currentIndex]
    }
    
    /// The current route.
    public var currentRoute: Route? {
        currentEntry?.route
    }
    
    /// The previous entry.
    public var previousEntry: HistoryEntry<Route>? {
        guard currentIndex > 0 else { return nil }
        return entries[currentIndex - 1]
    }
    
    /// The next entry (if any).
    public var nextEntry: HistoryEntry<Route>? {
        guard currentIndex < entries.count - 1 else { return nil }
        return entries[currentIndex + 1]
    }
    
    /// The first entry in the history.
    public var firstEntry: HistoryEntry<Route>? {
        entries.first
    }
    
    /// The last entry in the history.
    public var lastEntry: HistoryEntry<Route>? {
        entries.last
    }
    
    /// Whether the history is empty.
    public var isEmpty: Bool {
        entries.isEmpty
    }
    
    /// The entries behind the current position.
    public var backStack: [HistoryEntry<Route>] {
        guard currentIndex > 0 else { return [] }
        return Array(entries[0..<currentIndex])
    }
    
    /// The entries ahead of the current position.
    public var forwardStack: [HistoryEntry<Route>] {
        guard currentIndex < entries.count - 1 else { return [] }
        return Array(entries[(currentIndex + 1)...])
    }
    
    // MARK: - Initialization
    
    /// Creates a navigation history with the given configuration.
    ///
    /// - Parameter configuration: The history configuration.
    public init(configuration: HistoryConfiguration = .default) {
        self.configuration = configuration
        
        if configuration.persistHistory {
            restoreHistory()
        }
    }
    
    // MARK: - Adding Entries
    
    /// Adds a new entry to the history.
    ///
    /// - Parameters:
    ///   - route: The route to add.
    ///   - source: The navigation source.
    ///   - metadata: Additional metadata.
    public func add(
        _ route: Route,
        source: NavigationSource = .push,
        metadata: [String: String] = [:]
    ) {
        // Check for duplicates
        if !configuration.allowDuplicates,
           let last = currentEntry,
           last.route == route {
            return
        }
        
        // Update duration of previous entry
        if configuration.trackDurations,
           currentIndex >= 0,
           currentIndex < entries.count,
           let lastTimestamp = lastEntryTimestamp {
            entries[currentIndex].duration = Date().timeIntervalSince(lastTimestamp)
        }
        
        // Remove forward entries when adding new entry
        if currentIndex < entries.count - 1 {
            entries.removeSubrange((currentIndex + 1)...)
        }
        
        // Create new entry
        let entry = HistoryEntry(
            route: route,
            timestamp: configuration.trackTimestamps ? Date() : Date(timeIntervalSince1970: 0),
            source: source,
            metadata: configuration.trackMetadata ? metadata : [:]
        )
        
        entries.append(entry)
        currentIndex = entries.count - 1
        lastEntryTimestamp = Date()
        
        // Enforce max entries limit
        if entries.count > configuration.maxEntries {
            let removeCount = entries.count - configuration.maxEntries
            entries.removeFirst(removeCount)
            currentIndex -= removeCount
            eventSubject.send(.limitReached(current: entries.count, max: configuration.maxEntries))
        }
        
        updateState()
        eventSubject.send(.entryAdded(entry))
        
        if configuration.persistHistory {
            persistHistory()
        }
    }
    
    /// Adds multiple entries to the history.
    ///
    /// - Parameters:
    ///   - routes: The routes to add.
    ///   - source: The navigation source.
    public func addAll(_ routes: [Route], source: NavigationSource = .push) {
        for route in routes {
            add(route, source: source)
        }
    }
    
    // MARK: - Navigation
    
    /// Goes back one entry in the history.
    ///
    /// - Returns: The previous route, if available.
    @discardableResult
    public func goBack() -> Route? {
        guard canGoBack else { return nil }
        currentIndex -= 1
        updateState()
        
        if configuration.persistHistory {
            persistHistory()
        }
        
        return currentRoute
    }
    
    /// Goes forward one entry in the history.
    ///
    /// - Returns: The next route, if available.
    @discardableResult
    public func goForward() -> Route? {
        guard canGoForward else { return nil }
        currentIndex += 1
        updateState()
        
        if configuration.persistHistory {
            persistHistory()
        }
        
        return currentRoute
    }
    
    /// Goes back a specific number of entries.
    ///
    /// - Parameter count: The number of entries to go back.
    /// - Returns: The route at the new position, if available.
    @discardableResult
    public func goBack(by count: Int) -> Route? {
        let newIndex = max(0, currentIndex - count)
        guard newIndex != currentIndex else { return nil }
        
        currentIndex = newIndex
        updateState()
        
        if configuration.persistHistory {
            persistHistory()
        }
        
        return currentRoute
    }
    
    /// Goes forward a specific number of entries.
    ///
    /// - Parameter count: The number of entries to go forward.
    /// - Returns: The route at the new position, if available.
    @discardableResult
    public func goForward(by count: Int) -> Route? {
        let newIndex = min(entries.count - 1, currentIndex + count)
        guard newIndex != currentIndex else { return nil }
        
        currentIndex = newIndex
        updateState()
        
        if configuration.persistHistory {
            persistHistory()
        }
        
        return currentRoute
    }
    
    /// Goes to a specific entry in the history.
    ///
    /// - Parameter entry: The entry to navigate to.
    /// - Returns: Whether navigation was successful.
    @discardableResult
    public func go(to entry: HistoryEntry<Route>) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        
        currentIndex = index
        updateState()
        
        if configuration.persistHistory {
            persistHistory()
        }
        
        return true
    }
    
    /// Goes to a specific index in the history.
    ///
    /// - Parameter index: The index to navigate to.
    /// - Returns: The route at that index, if valid.
    @discardableResult
    public func go(to index: Int) -> Route? {
        guard index >= 0 && index < entries.count else { return nil }
        
        currentIndex = index
        updateState()
        
        if configuration.persistHistory {
            persistHistory()
        }
        
        return currentRoute
    }
    
    // MARK: - Removing Entries
    
    /// Removes the last entry from the history.
    ///
    /// - Returns: The removed entry, if any.
    @discardableResult
    public func removeLast() -> HistoryEntry<Route>? {
        guard !entries.isEmpty else { return nil }
        
        let removed = entries.removeLast()
        
        if currentIndex >= entries.count {
            currentIndex = entries.count - 1
        }
        
        updateState()
        eventSubject.send(.entryRemoved(removed))
        
        if configuration.persistHistory {
            persistHistory()
        }
        
        return removed
    }
    
    /// Removes entries from the beginning of the history.
    ///
    /// - Parameter count: The number of entries to remove.
    public func removeFirst(_ count: Int) {
        guard count > 0 && count <= entries.count else { return }
        
        let removed = Array(entries.prefix(count))
        entries.removeFirst(count)
        currentIndex = max(0, currentIndex - count)
        
        updateState()
        
        for entry in removed {
            eventSubject.send(.entryRemoved(entry))
        }
        
        if configuration.persistHistory {
            persistHistory()
        }
    }
    
    /// Removes a specific entry from the history.
    ///
    /// - Parameter entry: The entry to remove.
    /// - Returns: Whether the entry was removed.
    @discardableResult
    public func remove(_ entry: HistoryEntry<Route>) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        
        entries.remove(at: index)
        
        if currentIndex >= index && currentIndex > 0 {
            currentIndex -= 1
        }
        
        updateState()
        eventSubject.send(.entryRemoved(entry))
        
        if configuration.persistHistory {
            persistHistory()
        }
        
        return true
    }
    
    /// Clears all history entries.
    public func clear() {
        entries.removeAll()
        currentIndex = -1
        lastEntryTimestamp = nil
        
        updateState()
        eventSubject.send(.historyCleared)
        
        if configuration.persistHistory {
            clearPersistedHistory()
        }
    }
    
    // MARK: - Queries
    
    /// Gets recent entries from the history.
    ///
    /// - Parameter limit: The maximum number of entries to return.
    /// - Returns: Recent entries, most recent first.
    public func recentEntries(limit: Int) -> [HistoryEntry<Route>] {
        Array(entries.suffix(limit).reversed())
    }
    
    /// Gets entries matching a predicate.
    ///
    /// - Parameter predicate: The predicate to match.
    /// - Returns: Matching entries.
    public func entries(matching predicate: (HistoryEntry<Route>) -> Bool) -> [HistoryEntry<Route>] {
        entries.filter(predicate)
    }
    
    /// Gets entries for a specific route.
    ///
    /// - Parameter route: The route to search for.
    /// - Returns: Entries with the matching route.
    public func entries(for route: Route) -> [HistoryEntry<Route>] {
        entries.filter { $0.route == route }
    }
    
    /// Gets entries from a specific navigation source.
    ///
    /// - Parameter source: The navigation source.
    /// - Returns: Entries from that source.
    public func entries(from source: NavigationSource) -> [HistoryEntry<Route>] {
        entries.filter { $0.source == source }
    }
    
    /// Gets entries within a date range.
    ///
    /// - Parameters:
    ///   - start: The start date.
    ///   - end: The end date.
    /// - Returns: Entries within the range.
    public func entries(from start: Date, to end: Date) -> [HistoryEntry<Route>] {
        entries.filter { $0.timestamp >= start && $0.timestamp <= end }
    }
    
    /// Checks if a route exists in the history.
    ///
    /// - Parameter route: The route to check.
    /// - Returns: Whether the route is in the history.
    public func contains(_ route: Route) -> Bool {
        entries.contains { $0.route == route }
    }
    
    /// Finds the most recent entry for a route.
    ///
    /// - Parameter route: The route to search for.
    /// - Returns: The most recent entry, if found.
    public func mostRecent(for route: Route) -> HistoryEntry<Route>? {
        entries.last { $0.route == route }
    }
    
    /// Gets the visit count for a route.
    ///
    /// - Parameter route: The route to count.
    /// - Returns: The number of visits.
    public func visitCount(for route: Route) -> Int {
        entries.filter { $0.route == route }.count
    }
    
    /// Gets the total time spent on a route.
    ///
    /// - Parameter route: The route to check.
    /// - Returns: Total time in seconds.
    public func totalTime(for route: Route) -> TimeInterval {
        entries
            .filter { $0.route == route }
            .compactMap { $0.duration }
            .reduce(0, +)
    }
    
    // MARK: - Private Methods
    
    private func updateState() {
        count = entries.count
        canGoBack = currentIndex > 0
        canGoForward = currentIndex < entries.count - 1
    }
    
    private func persistHistory() {
        guard let key = configuration.persistenceKey else { return }
        
        // Store only the route identifiers and current index
        let data: [String: Any] = [
            "currentIndex": currentIndex,
            "count": entries.count
        ]
        UserDefaults.standard.set(data, forKey: key)
    }
    
    private func restoreHistory() {
        guard let key = configuration.persistenceKey,
              let data = UserDefaults.standard.dictionary(forKey: key) else { return }
        
        if let index = data["currentIndex"] as? Int {
            currentIndex = min(index, entries.count - 1)
        }
        
        updateState()
        
        if !entries.isEmpty {
            eventSubject.send(.historyRestored(count: entries.count))
        }
    }
    
    private func clearPersistedHistory() {
        guard let key = configuration.persistenceKey else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - View Extension

public extension View {
    /// Adds navigation history tracking to this view.
    ///
    /// - Parameters:
    ///   - history: The navigation history.
    ///   - route: The route to track.
    ///   - source: The navigation source.
    /// - Returns: A view that tracks history.
    func trackHistory<Route: Hashable>(
        _ history: NavigationHistory<Route>,
        route: Route,
        source: NavigationSource = .push
    ) -> some View {
        self.onAppear {
            history.add(route, source: source)
        }
    }
}
