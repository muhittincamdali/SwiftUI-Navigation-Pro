import Foundation
import Combine

// MARK: - Navigation Record

/// A recorded navigation event.
public struct NavigationRecord: Codable, Identifiable, Sendable {
    /// Unique identifier for this record.
    public let id: UUID
    /// The timestamp when this event occurred.
    public let timestamp: Date
    /// The type of navigation event.
    public let eventType: NavigationEventType
    /// The route path involved.
    public let routePath: String
    /// Optional parameters associated with the event.
    public let parameters: [String: String]
    /// The session ID this record belongs to.
    public let sessionId: UUID
    /// Screen time spent before this navigation.
    public let previousScreenDuration: TimeInterval?
    /// Device and app context.
    public let context: RecordContext
    
    /// Creates a navigation record.
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: NavigationEventType,
        routePath: String,
        parameters: [String: String] = [:],
        sessionId: UUID,
        previousScreenDuration: TimeInterval? = nil,
        context: RecordContext = RecordContext()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.routePath = routePath
        self.parameters = parameters
        self.sessionId = sessionId
        self.previousScreenDuration = previousScreenDuration
        self.context = context
    }
}

// MARK: - Navigation Event Type

/// Types of navigation events that can be recorded.
public enum NavigationEventType: String, Codable, Sendable {
    case push
    case pop
    case popToRoot
    case present
    case dismiss
    case tabSwitch
    case deepLink
    case backGesture
    case appLaunch
    case appBackground
    case appForeground
    case sessionStart
    case sessionEnd
}

// MARK: - Record Context

/// Context information for a navigation record.
public struct RecordContext: Codable, Sendable {
    /// The app version.
    public let appVersion: String
    /// The OS version.
    public let osVersion: String
    /// The device model.
    public let deviceModel: String
    /// The current locale.
    public let locale: String
    /// The timestamp.
    public let recordedAt: Date
    /// Custom metadata.
    public let metadata: [String: String]
    
    /// Creates a record context with current device info.
    public init(metadata: [String: String] = [:]) {
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        self.deviceModel = Self.deviceModel()
        self.locale = Locale.current.identifier
        self.recordedAt = Date()
        self.metadata = metadata
    }
    
    private static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
}

// MARK: - Recording Session

/// A navigation recording session.
public struct RecordingSession: Codable, Identifiable, Sendable {
    /// Unique session identifier.
    public let id: UUID
    /// Session start time.
    public let startTime: Date
    /// Session end time, if ended.
    public var endTime: Date?
    /// All records in this session.
    public var records: [NavigationRecord]
    /// Session metadata.
    public let metadata: [String: String]
    /// User identifier, if available.
    public let userId: String?
    
    /// The total duration of this session.
    public var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    /// The number of navigation events.
    public var eventCount: Int {
        records.count
    }
    
    /// Creates a new recording session.
    public init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        metadata: [String: String] = [:],
        userId: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.records = []
        self.metadata = metadata
        self.userId = userId
    }
}

// MARK: - Navigation Recorder

/// A recorder that captures navigation events for debugging and analytics.
///
/// Use `NavigationRecorder` to:
/// - Debug navigation issues
/// - Analyze user flow patterns
/// - Create reproducible test scenarios
/// - Generate heatmaps and analytics
///
/// ```swift
/// let recorder = NavigationRecorder<AppRoute>()
/// recorder.startSession()
///
/// // Navigation events are automatically recorded
/// navigator.push(.profile)
///
/// // Export for analysis
/// let session = recorder.exportCurrentSession()
/// ```
@MainActor
public final class NavigationRecorder<R: Route>: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether recording is currently active.
    @Published public private(set) var isRecording: Bool = false
    
    /// The current recording session.
    @Published public private(set) var currentSession: RecordingSession?
    
    /// The total number of recorded events in the current session.
    @Published public private(set) var recordCount: Int = 0
    
    /// The last recorded event.
    @Published public private(set) var lastRecord: NavigationRecord?
    
    // MARK: - Properties
    
    /// Maximum records to keep in memory.
    public var maxRecordsInMemory: Int = 1000
    
    /// Whether to auto-save sessions.
    public var autoSave: Bool = true
    
    /// The storage key prefix for saved sessions.
    public var storageKeyPrefix: String = "nav_recording_"
    
    /// Timestamp of the last navigation for duration calculation.
    private var lastNavigationTime: Date?
    
    /// Custom metadata to include with records.
    private var customMetadata: [String: String] = [:]
    
    /// Saved session identifiers.
    private var savedSessionIds: [UUID] = []
    
    // MARK: - Initialization
    
    /// Creates a navigation recorder.
    public init() {
        loadSavedSessionIds()
    }
    
    // MARK: - Session Management
    
    /// Starts a new recording session.
    ///
    /// - Parameters:
    ///   - metadata: Custom metadata for the session.
    ///   - userId: Optional user identifier.
    public func startSession(metadata: [String: String] = [:], userId: String? = nil) {
        guard !isRecording else { return }
        
        currentSession = RecordingSession(metadata: metadata, userId: userId)
        isRecording = true
        lastNavigationTime = Date()
        recordCount = 0
        
        record(eventType: .sessionStart, routePath: "/")
    }
    
    /// Ends the current recording session.
    ///
    /// - Returns: The completed session, if any.
    @discardableResult
    public func endSession() -> RecordingSession? {
        guard isRecording, var session = currentSession else { return nil }
        
        record(eventType: .sessionEnd, routePath: lastRecord?.routePath ?? "/")
        
        session.endTime = Date()
        session.records = currentSession?.records ?? []
        
        if autoSave {
            saveSession(session)
        }
        
        let completedSession = session
        currentSession = nil
        isRecording = false
        lastNavigationTime = nil
        
        return completedSession
    }
    
    /// Pauses recording without ending the session.
    public func pauseRecording() {
        isRecording = false
    }
    
    /// Resumes recording for the current session.
    public func resumeRecording() {
        guard currentSession != nil else { return }
        isRecording = true
    }
    
    // MARK: - Recording
    
    /// Records a navigation event.
    ///
    /// - Parameters:
    ///   - eventType: The type of event.
    ///   - route: The route involved.
    ///   - parameters: Additional parameters.
    public func record(eventType: NavigationEventType, route: R, parameters: [String: String] = [:]) {
        record(eventType: eventType, routePath: route.path, parameters: parameters)
    }
    
    /// Records a navigation event with a path string.
    ///
    /// - Parameters:
    ///   - eventType: The type of event.
    ///   - routePath: The route path.
    ///   - parameters: Additional parameters.
    public func record(eventType: NavigationEventType, routePath: String, parameters: [String: String] = [:]) {
        guard isRecording, currentSession != nil else { return }
        
        let now = Date()
        let screenDuration = lastNavigationTime.map { now.timeIntervalSince($0) }
        
        let record = NavigationRecord(
            eventType: eventType,
            routePath: routePath,
            parameters: parameters.merging(customMetadata) { $1 },
            sessionId: currentSession!.id,
            previousScreenDuration: screenDuration,
            context: RecordContext(metadata: customMetadata)
        )
        
        currentSession?.records.append(record)
        lastRecord = record
        recordCount += 1
        lastNavigationTime = now
        
        // Trim if exceeding max records
        if let records = currentSession?.records, records.count > maxRecordsInMemory {
            currentSession?.records = Array(records.suffix(maxRecordsInMemory))
        }
    }
    
    /// Sets custom metadata to include with all records.
    ///
    /// - Parameter metadata: The metadata dictionary.
    public func setCustomMetadata(_ metadata: [String: String]) {
        customMetadata = metadata
    }
    
    /// Adds a single metadata value.
    ///
    /// - Parameters:
    ///   - value: The value to add.
    ///   - key: The metadata key.
    public func addMetadata(_ value: String, forKey key: String) {
        customMetadata[key] = value
    }
    
    // MARK: - Export
    
    /// Exports the current session.
    ///
    /// - Returns: The current session, if any.
    public func exportCurrentSession() -> RecordingSession? {
        currentSession
    }
    
    /// Exports the current session as JSON data.
    ///
    /// - Returns: The JSON data, if encoding succeeds.
    public func exportAsJSON() -> Data? {
        guard let session = currentSession else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(session)
    }
    
    /// Exports the current session as a JSON string.
    ///
    /// - Returns: The JSON string, if encoding succeeds.
    public func exportAsJSONString() -> String? {
        guard let data = exportAsJSON() else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Persistence
    
    /// Saves a session to persistent storage.
    ///
    /// - Parameter session: The session to save.
    public func saveSession(_ session: RecordingSession) {
        let key = storageKeyPrefix + session.id.uuidString
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(session) {
            UserDefaults.standard.set(data, forKey: key)
            
            if !savedSessionIds.contains(session.id) {
                savedSessionIds.append(session.id)
                saveSavedSessionIds()
            }
        }
    }
    
    /// Loads a session from persistent storage.
    ///
    /// - Parameter sessionId: The session ID to load.
    /// - Returns: The loaded session, if available.
    public func loadSession(id sessionId: UUID) -> RecordingSession? {
        let key = storageKeyPrefix + sessionId.uuidString
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RecordingSession.self, from: data)
    }
    
    /// Returns all saved session IDs.
    ///
    /// - Returns: An array of saved session identifiers.
    public func savedSessions() -> [UUID] {
        savedSessionIds
    }
    
    /// Deletes a saved session.
    ///
    /// - Parameter sessionId: The session ID to delete.
    public func deleteSession(id sessionId: UUID) {
        let key = storageKeyPrefix + sessionId.uuidString
        UserDefaults.standard.removeObject(forKey: key)
        savedSessionIds.removeAll { $0 == sessionId }
        saveSavedSessionIds()
    }
    
    /// Clears all saved sessions.
    public func clearAllSessions() {
        for id in savedSessionIds {
            let key = storageKeyPrefix + id.uuidString
            UserDefaults.standard.removeObject(forKey: key)
        }
        savedSessionIds.removeAll()
        saveSavedSessionIds()
    }
    
    // MARK: - Private Methods
    
    private func loadSavedSessionIds() {
        let key = storageKeyPrefix + "session_ids"
        if let data = UserDefaults.standard.data(forKey: key),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            savedSessionIds = ids
        }
    }
    
    private func saveSavedSessionIds() {
        let key = storageKeyPrefix + "session_ids"
        if let data = try? JSONEncoder().encode(savedSessionIds) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Navigation Playback

/// A player that replays recorded navigation sessions.
///
/// Use `NavigationPlayer` to replay user journeys for:
/// - Testing and debugging
/// - Demo presentations
/// - User journey visualization
///
/// ```swift
/// let player = NavigationPlayer(navigator: navigator)
/// player.load(session: recordedSession)
/// player.play()
/// ```
@MainActor
public final class NavigationPlayer<R: Route>: ObservableObject {
    
    // MARK: - Playback State
    
    /// The current playback state.
    public enum PlaybackState: Sendable {
        case idle
        case playing
        case paused
        case finished
    }
    
    // MARK: - Published Properties
    
    /// The current playback state.
    @Published public private(set) var state: PlaybackState = .idle
    
    /// The current playback index.
    @Published public private(set) var currentIndex: Int = 0
    
    /// The current record being played.
    @Published public private(set) var currentRecord: NavigationRecord?
    
    /// The playback progress (0.0 to 1.0).
    @Published public private(set) var progress: Double = 0
    
    /// The playback speed multiplier.
    @Published public var playbackSpeed: Double = 1.0
    
    // MARK: - Properties
    
    /// The loaded session.
    public private(set) var session: RecordingSession?
    
    /// Route factory for creating routes from paths.
    private let routeFactory: (String) -> R?
    
    /// Navigation handler.
    private let navigationHandler: (NavigationRecord, R) -> Void
    
    /// Playback task.
    private var playbackTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// Creates a navigation player.
    ///
    /// - Parameters:
    ///   - routeFactory: A closure that creates routes from path strings.
    ///   - navigationHandler: A closure that performs navigation for each record.
    public init(
        routeFactory: @escaping (String) -> R?,
        navigationHandler: @escaping (NavigationRecord, R) -> Void
    ) {
        self.routeFactory = routeFactory
        self.navigationHandler = navigationHandler
    }
    
    // MARK: - Session Loading
    
    /// Loads a recording session for playback.
    ///
    /// - Parameter session: The session to load.
    public func load(session: RecordingSession) {
        stop()
        self.session = session
        currentIndex = 0
        progress = 0
        currentRecord = session.records.first
        state = .idle
    }
    
    // MARK: - Playback Control
    
    /// Starts or resumes playback.
    public func play() {
        guard let session = session, !session.records.isEmpty else { return }
        
        if state == .finished {
            currentIndex = 0
        }
        
        state = .playing
        startPlayback()
    }
    
    /// Pauses playback.
    public func pause() {
        playbackTask?.cancel()
        playbackTask = nil
        state = .paused
    }
    
    /// Stops playback and resets to beginning.
    public func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        currentIndex = 0
        progress = 0
        currentRecord = session?.records.first
        state = .idle
    }
    
    /// Steps forward by one record.
    public func stepForward() {
        guard let session = session, currentIndex < session.records.count - 1 else { return }
        currentIndex += 1
        executeCurrentRecord()
    }
    
    /// Steps backward by one record.
    public func stepBackward() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        executeCurrentRecord()
    }
    
    /// Seeks to a specific index.
    ///
    /// - Parameter index: The index to seek to.
    public func seek(to index: Int) {
        guard let session = session, index >= 0, index < session.records.count else { return }
        currentIndex = index
        executeCurrentRecord()
    }
    
    /// Seeks to a specific progress point.
    ///
    /// - Parameter progress: The progress (0.0 to 1.0).
    public func seek(toProgress progress: Double) {
        guard let session = session, !session.records.isEmpty else { return }
        let index = Int(Double(session.records.count - 1) * progress)
        seek(to: index)
    }
    
    // MARK: - Private Methods
    
    private func startPlayback() {
        playbackTask = Task { [weak self] in
            await self?.runPlayback()
        }
    }
    
    private func runPlayback() async {
        guard let session = session else { return }
        
        while currentIndex < session.records.count && state == .playing {
            await executeCurrentRecord()
            
            // Calculate delay based on next record's timestamp
            let delay = calculateDelay()
            
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                break
            }
            
            currentIndex += 1
            updateProgress()
        }
        
        if currentIndex >= session.records.count {
            state = .finished
        }
    }
    
    @MainActor
    private func executeCurrentRecord() {
        guard let session = session, currentIndex < session.records.count else { return }
        
        let record = session.records[currentIndex]
        currentRecord = record
        
        if let route = routeFactory(record.routePath) {
            navigationHandler(record, route)
        }
        
        updateProgress()
    }
    
    private func calculateDelay() -> TimeInterval {
        guard let session = session,
              currentIndex + 1 < session.records.count else { return 0 }
        
        let current = session.records[currentIndex]
        let next = session.records[currentIndex + 1]
        
        let actualDelay = next.timestamp.timeIntervalSince(current.timestamp)
        return max(0.1, actualDelay / playbackSpeed)
    }
    
    private func updateProgress() {
        guard let session = session, !session.records.isEmpty else {
            progress = 0
            return
        }
        progress = Double(currentIndex) / Double(session.records.count - 1)
    }
}

// MARK: - Analytics Aggregator

/// Aggregates navigation records into analytics data.
public struct NavigationAnalytics {
    
    /// Screen view statistics.
    public struct ScreenStats {
        /// The route path.
        public let path: String
        /// Total view count.
        public let viewCount: Int
        /// Average time spent on screen.
        public let averageDuration: TimeInterval
        /// Total time spent on screen.
        public let totalDuration: TimeInterval
        /// Entry points (screens navigated from).
        public let entryPoints: [String: Int]
        /// Exit points (screens navigated to).
        public let exitPoints: [String: Int]
    }
    
    /// Flow pattern.
    public struct FlowPattern {
        /// The sequence of route paths.
        public let sequence: [String]
        /// Number of occurrences.
        public let count: Int
        /// Average completion time.
        public let averageTime: TimeInterval
    }
    
    /// Analyzes a recording session.
    ///
    /// - Parameter session: The session to analyze.
    /// - Returns: A dictionary of screen statistics.
    public static func analyzeSession(_ session: RecordingSession) -> [String: ScreenStats] {
        var stats: [String: (views: Int, durations: [TimeInterval], entries: [String: Int], exits: [String: Int])] = [:]
        
        var previousPath: String?
        
        for record in session.records {
            let path = record.routePath
            
            if stats[path] == nil {
                stats[path] = (views: 0, durations: [], entries: [:], exits: [:])
            }
            
            stats[path]?.views += 1
            
            if let duration = record.previousScreenDuration {
                stats[path]?.durations.append(duration)
            }
            
            if let prev = previousPath {
                stats[path]?.entries[prev, default: 0] += 1
                stats[prev]?.exits[path, default: 0] += 1
            }
            
            previousPath = path
        }
        
        return stats.mapValues { data in
            let avgDuration = data.durations.isEmpty ? 0 : data.durations.reduce(0, +) / Double(data.durations.count)
            let totalDuration = data.durations.reduce(0, +)
            
            return ScreenStats(
                path: "",
                viewCount: data.views,
                averageDuration: avgDuration,
                totalDuration: totalDuration,
                entryPoints: data.entries,
                exitPoints: data.exits
            )
        }
    }
    
    /// Finds common navigation patterns.
    ///
    /// - Parameters:
    ///   - session: The session to analyze.
    ///   - minLength: Minimum pattern length.
    ///   - maxLength: Maximum pattern length.
    /// - Returns: An array of flow patterns sorted by frequency.
    public static func findPatterns(
        in session: RecordingSession,
        minLength: Int = 2,
        maxLength: Int = 5
    ) -> [FlowPattern] {
        let paths = session.records.map(\.routePath)
        var patterns: [String: (count: Int, times: [TimeInterval])] = [:]
        
        for length in minLength...maxLength {
            guard length <= paths.count else { break }
            
            for i in 0...(paths.count - length) {
                let sequence = Array(paths[i..<(i + length)])
                let key = sequence.joined(separator: "->")
                
                if patterns[key] == nil {
                    patterns[key] = (count: 0, times: [])
                }
                patterns[key]?.count += 1
            }
        }
        
        return patterns.map { key, value in
            let sequence = key.split(separator: "->").map(String.init)
            let avgTime = value.times.isEmpty ? 0 : value.times.reduce(0, +) / Double(value.times.count)
            return FlowPattern(sequence: sequence, count: value.count, averageTime: avgTime)
        }
        .filter { $0.count > 1 }
        .sorted { $0.count > $1.count }
    }
}
