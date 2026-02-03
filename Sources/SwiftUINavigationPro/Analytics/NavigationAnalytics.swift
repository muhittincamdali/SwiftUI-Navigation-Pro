import SwiftUI
import Combine

// MARK: - Analytics Event

/// An event tracked by navigation analytics.
public struct AnalyticsEvent<Route: Hashable>: Identifiable, Sendable {
    /// The unique identifier for this event.
    public let id: UUID
    /// The type of event.
    public let type: EventType
    /// The route associated with the event.
    public let route: Route?
    /// The timestamp of the event.
    public let timestamp: Date
    /// The duration (for time-based events).
    public let duration: TimeInterval?
    /// Additional properties.
    public let properties: [String: String]
    /// The session ID.
    public let sessionId: String
    
    /// Creates an analytics event.
    public init(
        id: UUID = UUID(),
        type: EventType,
        route: Route? = nil,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        properties: [String: String] = [:],
        sessionId: String
    ) {
        self.id = id
        self.type = type
        self.route = route
        self.timestamp = timestamp
        self.duration = duration
        self.properties = properties
        self.sessionId = sessionId
    }
    
    /// The type of analytics event.
    public enum EventType: String, Sendable {
        /// A screen was viewed.
        case screenView
        /// Navigation occurred.
        case navigation
        /// A deep link was opened.
        case deepLink
        /// A tab was selected.
        case tabSelection
        /// A flow step was completed.
        case flowStep
        /// A flow was completed.
        case flowComplete
        /// A flow was abandoned.
        case flowAbandoned
        /// A modal was presented.
        case modalPresented
        /// A modal was dismissed.
        case modalDismissed
        /// Time was spent on a screen.
        case screenTime
        /// An error occurred.
        case error
        /// A custom event.
        case custom
    }
}

// MARK: - Screen Metrics

/// Metrics for a single screen.
public struct ScreenMetrics<Route: Hashable>: Sendable {
    /// The route for this screen.
    public let route: Route
    /// Total number of views.
    public var viewCount: Int
    /// Total time spent on the screen.
    public var totalTime: TimeInterval
    /// Average time per view.
    public var averageTime: TimeInterval {
        viewCount > 0 ? totalTime / Double(viewCount) : 0
    }
    /// Number of times navigated away.
    public var exitCount: Int
    /// Most common next screen.
    public var topNextScreens: [(Route, Int)]
    /// Most common previous screen.
    public var topPreviousScreens: [(Route, Int)]
    /// First view timestamp.
    public var firstViewedAt: Date?
    /// Last view timestamp.
    public var lastViewedAt: Date?
    /// Number of deep link entries.
    public var deepLinkEntries: Int
    
    /// Creates screen metrics.
    public init(
        route: Route,
        viewCount: Int = 0,
        totalTime: TimeInterval = 0,
        exitCount: Int = 0,
        topNextScreens: [(Route, Int)] = [],
        topPreviousScreens: [(Route, Int)] = [],
        firstViewedAt: Date? = nil,
        lastViewedAt: Date? = nil,
        deepLinkEntries: Int = 0
    ) {
        self.route = route
        self.viewCount = viewCount
        self.totalTime = totalTime
        self.exitCount = exitCount
        self.topNextScreens = topNextScreens
        self.topPreviousScreens = topPreviousScreens
        self.firstViewedAt = firstViewedAt
        self.lastViewedAt = lastViewedAt
        self.deepLinkEntries = deepLinkEntries
    }
}

// MARK: - Session Metrics

/// Metrics for a user session.
public struct SessionMetrics: Sendable {
    /// The session identifier.
    public let sessionId: String
    /// When the session started.
    public let startTime: Date
    /// When the session ended.
    public var endTime: Date?
    /// Total session duration.
    public var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    /// Number of screen views.
    public var screenViewCount: Int
    /// Number of navigation actions.
    public var navigationCount: Int
    /// Number of deep links.
    public var deepLinkCount: Int
    /// Number of flows started.
    public var flowsStarted: Int
    /// Number of flows completed.
    public var flowsCompleted: Int
    /// Average screen time.
    public var averageScreenTime: TimeInterval
    /// Unique screens viewed.
    public var uniqueScreensViewed: Int
    
    /// Creates session metrics.
    public init(
        sessionId: String,
        startTime: Date = Date(),
        endTime: Date? = nil,
        screenViewCount: Int = 0,
        navigationCount: Int = 0,
        deepLinkCount: Int = 0,
        flowsStarted: Int = 0,
        flowsCompleted: Int = 0,
        averageScreenTime: TimeInterval = 0,
        uniqueScreensViewed: Int = 0
    ) {
        self.sessionId = sessionId
        self.startTime = startTime
        self.endTime = endTime
        self.screenViewCount = screenViewCount
        self.navigationCount = navigationCount
        self.deepLinkCount = deepLinkCount
        self.flowsStarted = flowsStarted
        self.flowsCompleted = flowsCompleted
        self.averageScreenTime = averageScreenTime
        self.uniqueScreensViewed = uniqueScreensViewed
    }
}

// MARK: - Flow Metrics

/// Metrics for a navigation flow.
public struct FlowMetrics: Sendable {
    /// The flow identifier.
    public let flowId: String
    /// Number of times started.
    public var startCount: Int
    /// Number of times completed.
    public var completionCount: Int
    /// Completion rate.
    public var completionRate: Double {
        startCount > 0 ? Double(completionCount) / Double(startCount) : 0
    }
    /// Average completion time.
    public var averageCompletionTime: TimeInterval
    /// Drop-off rates per step.
    public var stepDropOffRates: [String: Double]
    /// Most common drop-off step.
    public var mostCommonDropOff: String?
    /// Average steps completed before drop-off.
    public var averageStepsBeforeDropOff: Double
    
    /// Creates flow metrics.
    public init(
        flowId: String,
        startCount: Int = 0,
        completionCount: Int = 0,
        averageCompletionTime: TimeInterval = 0,
        stepDropOffRates: [String: Double] = [:],
        mostCommonDropOff: String? = nil,
        averageStepsBeforeDropOff: Double = 0
    ) {
        self.flowId = flowId
        self.startCount = startCount
        self.completionCount = completionCount
        self.averageCompletionTime = averageCompletionTime
        self.stepDropOffRates = stepDropOffRates
        self.mostCommonDropOff = mostCommonDropOff
        self.averageStepsBeforeDropOff = averageStepsBeforeDropOff
    }
}

// MARK: - Analytics Configuration

/// Configuration for navigation analytics.
public struct AnalyticsConfiguration: Sendable {
    /// Whether analytics is enabled.
    public let isEnabled: Bool
    /// Whether to track screen views.
    public let trackScreenViews: Bool
    /// Whether to track navigation.
    public let trackNavigation: Bool
    /// Whether to track time spent.
    public let trackTimeSpent: Bool
    /// Whether to track flows.
    public let trackFlows: Bool
    /// Whether to track deep links.
    public let trackDeepLinks: Bool
    /// Whether to persist analytics.
    public let persistData: Bool
    /// The persistence key.
    public let persistenceKey: String?
    /// Maximum events to store.
    public let maxEvents: Int
    /// Sampling rate (0.0 to 1.0).
    public let samplingRate: Double
    /// Custom event handler.
    public let eventHandler: (@Sendable (Any) -> Void)?
    
    /// Creates an analytics configuration.
    public init(
        isEnabled: Bool = true,
        trackScreenViews: Bool = true,
        trackNavigation: Bool = true,
        trackTimeSpent: Bool = true,
        trackFlows: Bool = true,
        trackDeepLinks: Bool = true,
        persistData: Bool = false,
        persistenceKey: String? = nil,
        maxEvents: Int = 1000,
        samplingRate: Double = 1.0,
        eventHandler: (@Sendable (Any) -> Void)? = nil
    ) {
        self.isEnabled = isEnabled
        self.trackScreenViews = trackScreenViews
        self.trackNavigation = trackNavigation
        self.trackTimeSpent = trackTimeSpent
        self.trackFlows = trackFlows
        self.trackDeepLinks = trackDeepLinks
        self.persistData = persistData
        self.persistenceKey = persistenceKey
        self.maxEvents = maxEvents
        self.samplingRate = min(max(samplingRate, 0), 1)
        self.eventHandler = eventHandler
    }
    
    /// The default configuration.
    public static let `default` = AnalyticsConfiguration()
    
    /// A disabled configuration.
    public static let disabled = AnalyticsConfiguration(isEnabled: false)
    
    /// A minimal configuration.
    public static let minimal = AnalyticsConfiguration(
        trackTimeSpent: false,
        trackFlows: false,
        maxEvents: 100
    )
}

// MARK: - Navigation Analytics

/// Tracks and analyzes navigation patterns.
///
/// `NavigationAnalytics` provides insights into how users navigate
/// through your app, including screen views, flow completion rates,
/// and navigation patterns.
///
/// ```swift
/// @StateObject private var analytics = NavigationAnalytics<AppRoute>()
///
/// // Track a screen view
/// analytics.trackScreenView(.home)
///
/// // Get screen metrics
/// let metrics = analytics.screenMetrics(for: .home)
/// print("Home viewed \(metrics.viewCount) times")
/// ```
@MainActor
public final class NavigationAnalytics<Route: Hashable>: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All tracked events.
    @Published public private(set) var events: [AnalyticsEvent<Route>] = []
    
    /// Current session metrics.
    @Published public private(set) var currentSession: SessionMetrics?
    
    /// Total events tracked.
    @Published public private(set) var totalEventsTracked: Int = 0
    
    /// Whether analytics is currently tracking.
    @Published public private(set) var isTracking: Bool = false
    
    // MARK: - Properties
    
    /// The analytics configuration.
    public let configuration: AnalyticsConfiguration
    
    /// Screen metrics cache.
    private var screenMetricsCache: [Route: ScreenMetrics<Route>] = [:]
    
    /// Flow metrics cache.
    private var flowMetricsCache: [String: FlowMetrics] = [:]
    
    /// Historical sessions.
    private var sessions: [SessionMetrics] = []
    
    /// Current screen and timestamp for time tracking.
    private var currentScreen: (route: Route, startTime: Date)?
    
    /// Navigation path for tracking sequences.
    private var navigationPath: [Route] = []
    
    /// The event publisher.
    private let eventSubject = PassthroughSubject<AnalyticsEvent<Route>, Never>()
    
    /// Publisher for analytics events.
    public var eventPublisher: AnyPublisher<AnalyticsEvent<Route>, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Cancellables for subscriptions.
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Creates a navigation analytics instance.
    ///
    /// - Parameter configuration: The analytics configuration.
    public init(configuration: AnalyticsConfiguration = .default) {
        self.configuration = configuration
        
        if configuration.isEnabled {
            startSession()
        }
        
        if configuration.persistData {
            restoreData()
        }
    }
    
    // MARK: - Session Management
    
    /// Starts a new analytics session.
    public func startSession() {
        guard configuration.isEnabled else { return }
        
        // End current session if active
        if var session = currentSession {
            session.endTime = Date()
            sessions.append(session)
        }
        
        let sessionId = UUID().uuidString
        currentSession = SessionMetrics(sessionId: sessionId)
        isTracking = true
    }
    
    /// Ends the current analytics session.
    public func endSession() {
        guard var session = currentSession else { return }
        
        // Track time on current screen
        if let current = currentScreen {
            recordScreenTime(for: current.route, since: current.startTime)
        }
        
        session.endTime = Date()
        sessions.append(session)
        currentSession = nil
        isTracking = false
        
        if configuration.persistData {
            persistData()
        }
    }
    
    // MARK: - Tracking Methods
    
    /// Tracks a screen view.
    ///
    /// - Parameters:
    ///   - route: The route being viewed.
    ///   - properties: Additional properties.
    public func trackScreenView(_ route: Route, properties: [String: String] = [:]) {
        guard shouldTrack() && configuration.trackScreenViews else { return }
        
        // Record time on previous screen
        if let current = currentScreen {
            recordScreenTime(for: current.route, since: current.startTime)
        }
        
        // Update current screen
        currentScreen = (route, Date())
        navigationPath.append(route)
        
        // Create event
        let event = AnalyticsEvent(
            type: .screenView,
            route: route,
            properties: properties,
            sessionId: currentSession?.sessionId ?? "unknown"
        )
        
        addEvent(event)
        updateScreenMetrics(for: route, event: event)
        
        // Update session metrics
        currentSession?.screenViewCount += 1
    }
    
    /// Tracks a navigation event.
    ///
    /// - Parameters:
    ///   - from: The source route.
    ///   - to: The destination route.
    ///   - method: The navigation method used.
    public func trackNavigation(from: Route, to: Route, method: String = "push") {
        guard shouldTrack() && configuration.trackNavigation else { return }
        
        let event = AnalyticsEvent(
            type: .navigation,
            route: to,
            properties: [
                "from": String(describing: from),
                "to": String(describing: to),
                "method": method
            ],
            sessionId: currentSession?.sessionId ?? "unknown"
        )
        
        addEvent(event)
        
        // Update navigation sequences
        updateNavigationSequence(from: from, to: to)
        
        // Update session metrics
        currentSession?.navigationCount += 1
    }
    
    /// Tracks a deep link event.
    ///
    /// - Parameters:
    ///   - url: The deep link URL.
    ///   - route: The resolved route.
    public func trackDeepLink(url: String, route: Route) {
        guard shouldTrack() && configuration.trackDeepLinks else { return }
        
        let event = AnalyticsEvent(
            type: .deepLink,
            route: route,
            properties: ["url": url],
            sessionId: currentSession?.sessionId ?? "unknown"
        )
        
        addEvent(event)
        
        // Update screen metrics
        if var metrics = screenMetricsCache[route] {
            metrics.deepLinkEntries += 1
            screenMetricsCache[route] = metrics
        }
        
        // Update session metrics
        currentSession?.deepLinkCount += 1
    }
    
    /// Tracks a tab selection.
    ///
    /// - Parameters:
    ///   - tab: The selected tab identifier.
    ///   - previousTab: The previously selected tab.
    public func trackTabSelection(tab: String, previousTab: String?) {
        guard shouldTrack() else { return }
        
        var properties: [String: String] = ["tab": tab]
        if let previous = previousTab {
            properties["previousTab"] = previous
        }
        
        let event = AnalyticsEvent<Route>(
            type: .tabSelection,
            route: nil,
            properties: properties,
            sessionId: currentSession?.sessionId ?? "unknown"
        )
        
        addEvent(event)
    }
    
    /// Tracks a flow step completion.
    ///
    /// - Parameters:
    ///   - flowId: The flow identifier.
    ///   - step: The step identifier.
    ///   - stepIndex: The index of the step.
    ///   - totalSteps: The total number of steps.
    public func trackFlowStep(flowId: String, step: String, stepIndex: Int, totalSteps: Int) {
        guard shouldTrack() && configuration.trackFlows else { return }
        
        let event = AnalyticsEvent<Route>(
            type: .flowStep,
            route: nil,
            properties: [
                "flowId": flowId,
                "step": step,
                "stepIndex": String(stepIndex),
                "totalSteps": String(totalSteps),
                "progress": String(format: "%.2f", Double(stepIndex + 1) / Double(totalSteps))
            ],
            sessionId: currentSession?.sessionId ?? "unknown"
        )
        
        addEvent(event)
    }
    
    /// Tracks a flow completion.
    ///
    /// - Parameters:
    ///   - flowId: The flow identifier.
    ///   - duration: The time to complete.
    public func trackFlowComplete(flowId: String, duration: TimeInterval) {
        guard shouldTrack() && configuration.trackFlows else { return }
        
        let event = AnalyticsEvent<Route>(
            type: .flowComplete,
            route: nil,
            duration: duration,
            properties: ["flowId": flowId],
            sessionId: currentSession?.sessionId ?? "unknown"
        )
        
        addEvent(event)
        updateFlowMetrics(flowId: flowId, completed: true, duration: duration)
        
        // Update session metrics
        currentSession?.flowsCompleted += 1
    }
    
    /// Tracks a flow abandonment.
    ///
    /// - Parameters:
    ///   - flowId: The flow identifier.
    ///   - atStep: The step where abandonment occurred.
    ///   - stepsCompleted: Number of steps completed.
    public func trackFlowAbandoned(flowId: String, atStep: String, stepsCompleted: Int) {
        guard shouldTrack() && configuration.trackFlows else { return }
        
        let event = AnalyticsEvent<Route>(
            type: .flowAbandoned,
            route: nil,
            properties: [
                "flowId": flowId,
                "abandonedAt": atStep,
                "stepsCompleted": String(stepsCompleted)
            ],
            sessionId: currentSession?.sessionId ?? "unknown"
        )
        
        addEvent(event)
        updateFlowMetrics(flowId: flowId, completed: false, abandonedAt: atStep)
    }
    
    /// Tracks an error.
    ///
    /// - Parameters:
    ///   - error: The error description.
    ///   - route: The route where error occurred.
    public func trackError(_ error: String, route: Route? = nil) {
        guard shouldTrack() else { return }
        
        let event = AnalyticsEvent(
            type: .error,
            route: route,
            properties: ["error": error],
            sessionId: currentSession?.sessionId ?? "unknown"
        )
        
        addEvent(event)
    }
    
    /// Tracks a custom event.
    ///
    /// - Parameters:
    ///   - name: The event name.
    ///   - properties: Event properties.
    ///   - route: Optional associated route.
    public func trackCustomEvent(name: String, properties: [String: String] = [:], route: Route? = nil) {
        guard shouldTrack() else { return }
        
        var props = properties
        props["eventName"] = name
        
        let event = AnalyticsEvent(
            type: .custom,
            route: route,
            properties: props,
            sessionId: currentSession?.sessionId ?? "unknown"
        )
        
        addEvent(event)
    }
    
    // MARK: - Metrics Retrieval
    
    /// Gets metrics for a specific screen.
    ///
    /// - Parameter route: The route to get metrics for.
    /// - Returns: Screen metrics.
    public func screenMetrics(for route: Route) -> ScreenMetrics<Route> {
        screenMetricsCache[route] ?? ScreenMetrics(route: route)
    }
    
    /// Gets metrics for all screens.
    ///
    /// - Returns: Array of screen metrics.
    public func allScreenMetrics() -> [ScreenMetrics<Route>] {
        Array(screenMetricsCache.values)
    }
    
    /// Gets the most viewed screens.
    ///
    /// - Parameter limit: Maximum number of screens to return.
    /// - Returns: Screens sorted by view count.
    public func topScreens(limit: Int = 10) -> [ScreenMetrics<Route>] {
        screenMetricsCache.values
            .sorted { $0.viewCount > $1.viewCount }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Gets screens with the longest average time.
    ///
    /// - Parameter limit: Maximum number of screens to return.
    /// - Returns: Screens sorted by average time.
    public func longestScreens(limit: Int = 10) -> [ScreenMetrics<Route>] {
        screenMetricsCache.values
            .sorted { $0.averageTime > $1.averageTime }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Gets metrics for a flow.
    ///
    /// - Parameter flowId: The flow identifier.
    /// - Returns: Flow metrics.
    public func flowMetrics(for flowId: String) -> FlowMetrics {
        flowMetricsCache[flowId] ?? FlowMetrics(flowId: flowId)
    }
    
    /// Gets all flow metrics.
    ///
    /// - Returns: Array of flow metrics.
    public func allFlowMetrics() -> [FlowMetrics] {
        Array(flowMetricsCache.values)
    }
    
    /// Gets all session metrics.
    ///
    /// - Returns: Array of session metrics including current.
    public func allSessions() -> [SessionMetrics] {
        var all = sessions
        if let current = currentSession {
            all.append(current)
        }
        return all
    }
    
    /// Gets events filtered by type.
    ///
    /// - Parameter type: The event type to filter by.
    /// - Returns: Filtered events.
    public func events(ofType type: AnalyticsEvent<Route>.EventType) -> [AnalyticsEvent<Route>] {
        events.filter { $0.type == type }
    }
    
    /// Gets events for a specific route.
    ///
    /// - Parameter route: The route to filter by.
    /// - Returns: Events for that route.
    public func events(for route: Route) -> [AnalyticsEvent<Route>] {
        events.filter { $0.route == route }
    }
    
    // MARK: - Data Management
    
    /// Clears all analytics data.
    public func clearAllData() {
        events.removeAll()
        screenMetricsCache.removeAll()
        flowMetricsCache.removeAll()
        sessions.removeAll()
        navigationPath.removeAll()
        totalEventsTracked = 0
        currentScreen = nil
        
        if configuration.persistData {
            clearPersistedData()
        }
    }
    
    /// Exports analytics data as a dictionary.
    ///
    /// - Returns: Dictionary with analytics data.
    public func export() -> [String: Any] {
        [
            "totalEvents": totalEventsTracked,
            "sessionsCount": sessions.count + (currentSession != nil ? 1 : 0),
            "uniqueScreens": screenMetricsCache.count,
            "flowsTracked": flowMetricsCache.count
        ]
    }
    
    // MARK: - Private Methods
    
    private func shouldTrack() -> Bool {
        guard configuration.isEnabled && isTracking else { return false }
        guard configuration.samplingRate >= 1.0 || Double.random(in: 0...1) <= configuration.samplingRate else { return false }
        return true
    }
    
    private func addEvent(_ event: AnalyticsEvent<Route>) {
        events.append(event)
        totalEventsTracked += 1
        eventSubject.send(event)
        
        // Enforce max events limit
        if events.count > configuration.maxEvents {
            events.removeFirst(events.count - configuration.maxEvents)
        }
        
        // Call custom event handler
        configuration.eventHandler?(event)
    }
    
    private func recordScreenTime(for route: Route, since startTime: Date) {
        guard configuration.trackTimeSpent else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        
        if var metrics = screenMetricsCache[route] {
            metrics.totalTime += duration
            screenMetricsCache[route] = metrics
        }
        
        let event = AnalyticsEvent(
            type: .screenTime,
            route: route,
            duration: duration,
            sessionId: currentSession?.sessionId ?? "unknown"
        )
        
        addEvent(event)
    }
    
    private func updateScreenMetrics(for route: Route, event: AnalyticsEvent<Route>) {
        var metrics = screenMetricsCache[route] ?? ScreenMetrics(route: route)
        
        metrics.viewCount += 1
        metrics.lastViewedAt = event.timestamp
        if metrics.firstViewedAt == nil {
            metrics.firstViewedAt = event.timestamp
        }
        
        screenMetricsCache[route] = metrics
        currentSession?.uniqueScreensViewed = screenMetricsCache.count
    }
    
    private func updateNavigationSequence(from: Route, to: Route) {
        // Update "next screens" for source
        if var fromMetrics = screenMetricsCache[from] {
            var nextScreens = Dictionary(fromMetrics.topNextScreens, uniquingKeysWith: { first, _ in first })
            nextScreens[to, default: 0] += 1
            fromMetrics.topNextScreens = nextScreens.sorted { $0.value > $1.value }
            fromMetrics.exitCount += 1
            screenMetricsCache[from] = fromMetrics
        }
        
        // Update "previous screens" for destination
        if var toMetrics = screenMetricsCache[to] {
            var prevScreens = Dictionary(toMetrics.topPreviousScreens, uniquingKeysWith: { first, _ in first })
            prevScreens[from, default: 0] += 1
            toMetrics.topPreviousScreens = prevScreens.sorted { $0.value > $1.value }
            screenMetricsCache[to] = toMetrics
        }
    }
    
    private func updateFlowMetrics(flowId: String, completed: Bool, duration: TimeInterval? = nil, abandonedAt: String? = nil) {
        var metrics = flowMetricsCache[flowId] ?? FlowMetrics(flowId: flowId)
        
        if completed {
            metrics.completionCount += 1
            if let duration = duration {
                let totalTime = metrics.averageCompletionTime * Double(metrics.completionCount - 1) + duration
                metrics.averageCompletionTime = totalTime / Double(metrics.completionCount)
            }
        } else {
            metrics.startCount += 1
            if let step = abandonedAt {
                metrics.stepDropOffRates[step, default: 0] += 1
                
                // Update most common drop-off
                if let maxDropOff = metrics.stepDropOffRates.max(by: { $0.value < $1.value }) {
                    metrics.mostCommonDropOff = maxDropOff.key
                }
            }
        }
        
        flowMetricsCache[flowId] = metrics
    }
    
    private func persistData() {
        guard let key = configuration.persistenceKey else { return }
        
        let data: [String: Any] = [
            "totalEvents": totalEventsTracked,
            "sessionsCount": sessions.count
        ]
        UserDefaults.standard.set(data, forKey: key)
    }
    
    private func restoreData() {
        guard let key = configuration.persistenceKey,
              let data = UserDefaults.standard.dictionary(forKey: key) else { return }
        
        if let total = data["totalEvents"] as? Int {
            totalEventsTracked = total
        }
    }
    
    private func clearPersistedData() {
        guard let key = configuration.persistenceKey else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - View Extension

public extension View {
    /// Tracks screen view when this view appears.
    ///
    /// - Parameters:
    ///   - analytics: The analytics instance.
    ///   - route: The route to track.
    /// - Returns: A view that tracks analytics.
    func trackAnalytics<Route: Hashable>(
        _ analytics: NavigationAnalytics<Route>,
        route: Route
    ) -> some View {
        self.onAppear {
            analytics.trackScreenView(route)
        }
    }
}
