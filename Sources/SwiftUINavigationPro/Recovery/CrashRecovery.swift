import Foundation
import Combine

// MARK: - Recovery State

/// The persisted state for crash recovery.
public struct RecoveryState: Codable, Sendable {
    /// The route stack paths.
    public let routePaths: [String]
    /// The active tab identifier, if using tabs.
    public let activeTabId: String?
    /// The presented route path, if any.
    public let presentedRoutePath: String?
    /// The presentation style of the presented route.
    public let presentationStyle: String?
    /// Custom state data.
    public let customState: [String: String]
    /// The timestamp when state was saved.
    public let timestamp: Date
    /// The app version when state was saved.
    public let appVersion: String
    /// A hash of the route enum for compatibility checking.
    public let routeTypeHash: String?
    
    /// Creates a recovery state.
    public init(
        routePaths: [String],
        activeTabId: String? = nil,
        presentedRoutePath: String? = nil,
        presentationStyle: String? = nil,
        customState: [String: String] = [:],
        timestamp: Date = Date(),
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
        routeTypeHash: String? = nil
    ) {
        self.routePaths = routePaths
        self.activeTabId = activeTabId
        self.presentedRoutePath = presentedRoutePath
        self.presentationStyle = presentationStyle
        self.customState = customState
        self.timestamp = timestamp
        self.appVersion = appVersion
        self.routeTypeHash = routeTypeHash
    }
    
    /// Whether this state is stale (older than max age).
    public func isStale(maxAge: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) > maxAge
    }
}

// MARK: - Recovery Policy

/// Policy for handling navigation state recovery.
public struct RecoveryPolicy: Sendable {
    /// Whether recovery is enabled.
    public let isEnabled: Bool
    /// Maximum age of state before it's considered stale.
    public let maxStateAge: TimeInterval
    /// Whether to recover modal presentations.
    public let recoverModals: Bool
    /// Whether to validate route compatibility.
    public let validateRoutes: Bool
    /// Whether to save state on every navigation.
    public let saveOnEveryNavigation: Bool
    /// Delay before auto-saving state.
    public let saveDebounceInterval: TimeInterval
    /// Routes that should not be recovered to.
    public let excludedRoutes: Set<String>
    /// Whether to clear state after successful recovery.
    public let clearAfterRecovery: Bool
    /// Whether to show confirmation before recovering.
    public let requireConfirmation: Bool
    
    /// Creates a recovery policy.
    public init(
        isEnabled: Bool = true,
        maxStateAge: TimeInterval = 86400, // 24 hours
        recoverModals: Bool = false,
        validateRoutes: Bool = true,
        saveOnEveryNavigation: Bool = true,
        saveDebounceInterval: TimeInterval = 0.5,
        excludedRoutes: Set<String> = [],
        clearAfterRecovery: Bool = true,
        requireConfirmation: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.maxStateAge = maxStateAge
        self.recoverModals = recoverModals
        self.validateRoutes = validateRoutes
        self.saveOnEveryNavigation = saveOnEveryNavigation
        self.saveDebounceInterval = saveDebounceInterval
        self.excludedRoutes = excludedRoutes
        self.clearAfterRecovery = clearAfterRecovery
        self.requireConfirmation = requireConfirmation
    }
    
    /// A permissive policy that recovers everything.
    public static let permissive = RecoveryPolicy(
        recoverModals: true,
        validateRoutes: false,
        clearAfterRecovery: false
    )
    
    /// A conservative policy that only recovers the main stack.
    public static let conservative = RecoveryPolicy(
        recoverModals: false,
        validateRoutes: true,
        maxStateAge: 3600, // 1 hour
        requireConfirmation: true
    )
    
    /// Recovery disabled.
    public static let disabled = RecoveryPolicy(isEnabled: false)
}

// MARK: - Recovery Result

/// The result of attempting state recovery.
public enum RecoveryResult<R: Route>: Sendable {
    /// Recovery was successful.
    case success(routes: [R], presentedRoute: R?)
    /// No state was available to recover.
    case noState
    /// State was stale and not recovered.
    case stale(age: TimeInterval)
    /// State was invalid or incompatible.
    case invalid(reason: String)
    /// Recovery was cancelled by the user.
    case cancelled
    /// Recovery is disabled.
    case disabled
}

// MARK: - Crash Recovery Manager

/// A manager that handles navigation state persistence and recovery.
///
/// `CrashRecoveryManager` automatically saves navigation state and
/// restores it after crashes or unexpected terminations.
///
/// ```swift
/// let recovery = CrashRecoveryManager<AppRoute>(policy: .conservative)
///
/// // On app launch
/// if let result = recovery.attemptRecovery() {
///     switch result {
///     case .success(let routes, let presented):
///         navigator.restore(routes: routes)
///     default:
///         break
///     }
/// }
///
/// // Connect to navigator
/// recovery.attach(to: navigator)
/// ```
@MainActor
public final class CrashRecoveryManager<R: Route>: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether there is recoverable state available.
    @Published public private(set) var hasRecoverableState: Bool = false
    
    /// The last saved state timestamp.
    @Published public private(set) var lastSaveTime: Date?
    
    /// Whether a recovery is pending confirmation.
    @Published public private(set) var isPendingConfirmation: Bool = false
    
    // MARK: - Properties
    
    /// The recovery policy.
    public let policy: RecoveryPolicy
    
    /// The storage key for persisted state.
    public let storageKey: String
    
    /// Route factory for creating routes from paths.
    private let routeFactory: (String) -> R?
    
    /// Route validator.
    private let routeValidator: ((R) -> Bool)?
    
    /// Pending recovery state.
    private var pendingState: RecoveryState?
    
    /// Save debounce work item.
    private var saveWorkItem: DispatchWorkItem?
    
    /// Hash of the route type for compatibility.
    private let routeTypeHash: String
    
    // MARK: - Initialization
    
    /// Creates a crash recovery manager.
    ///
    /// - Parameters:
    ///   - policy: The recovery policy.
    ///   - storageKey: The key for persistent storage.
    ///   - routeFactory: A closure that creates routes from path strings.
    ///   - routeValidator: An optional validator for routes.
    public init(
        policy: RecoveryPolicy = RecoveryPolicy(),
        storageKey: String = "navigation_recovery_state",
        routeFactory: @escaping (String) -> R?,
        routeValidator: ((R) -> Bool)? = nil
    ) {
        self.policy = policy
        self.storageKey = storageKey
        self.routeFactory = routeFactory
        self.routeValidator = routeValidator
        self.routeTypeHash = String(describing: R.self)
        
        checkForRecoverableState()
    }
    
    // MARK: - State Saving
    
    /// Saves the current navigation state.
    ///
    /// - Parameters:
    ///   - routes: The current route stack.
    ///   - activeTabId: The active tab identifier, if using tabs.
    ///   - presentedRoute: The currently presented route, if any.
    ///   - presentationStyle: The presentation style.
    ///   - customState: Custom state data to persist.
    public func saveState(
        routes: [R],
        activeTabId: String? = nil,
        presentedRoute: R? = nil,
        presentationStyle: PresentationStyle? = nil,
        customState: [String: String] = [:]
    ) {
        guard policy.isEnabled else { return }
        
        // Filter excluded routes
        let filteredPaths = routes
            .map(\.path)
            .filter { !policy.excludedRoutes.contains($0) }
        
        let state = RecoveryState(
            routePaths: filteredPaths,
            activeTabId: activeTabId,
            presentedRoutePath: presentedRoute?.path,
            presentationStyle: presentationStyle?.rawValue,
            customState: customState,
            routeTypeHash: routeTypeHash
        )
        
        if policy.saveDebounceInterval > 0 {
            debounceSave(state)
        } else {
            persistState(state)
        }
    }
    
    /// Forces an immediate state save.
    ///
    /// - Parameter state: The state to save.
    public func forceSave(_ state: RecoveryState) {
        saveWorkItem?.cancel()
        persistState(state)
    }
    
    // MARK: - State Recovery
    
    /// Attempts to recover navigation state.
    ///
    /// - Returns: The recovery result.
    public func attemptRecovery() -> RecoveryResult<R> {
        guard policy.isEnabled else {
            return .disabled
        }
        
        guard let state = loadState() else {
            return .noState
        }
        
        // Check for staleness
        if state.isStale(maxAge: policy.maxStateAge) {
            clearState()
            return .stale(age: Date().timeIntervalSince(state.timestamp))
        }
        
        // Validate route type compatibility
        if policy.validateRoutes, let hash = state.routeTypeHash, hash != routeTypeHash {
            clearState()
            return .invalid(reason: "Route type mismatch")
        }
        
        // Check confirmation requirement
        if policy.requireConfirmation {
            pendingState = state
            isPendingConfirmation = true
            return .cancelled
        }
        
        return executeRecovery(state)
    }
    
    /// Confirms pending recovery.
    ///
    /// - Returns: The recovery result.
    public func confirmRecovery() -> RecoveryResult<R> {
        guard let state = pendingState else {
            return .noState
        }
        
        isPendingConfirmation = false
        pendingState = nil
        
        return executeRecovery(state)
    }
    
    /// Cancels pending recovery.
    public func cancelRecovery() {
        isPendingConfirmation = false
        pendingState = nil
        
        if policy.clearAfterRecovery {
            clearState()
        }
    }
    
    /// Clears saved recovery state.
    public func clearState() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        hasRecoverableState = false
        lastSaveTime = nil
    }
    
    // MARK: - Convenience Methods
    
    /// Returns the saved state without recovering.
    ///
    /// - Returns: The saved recovery state, if available.
    public func peekState() -> RecoveryState? {
        loadState()
    }
    
    /// Returns the age of the saved state.
    ///
    /// - Returns: The age in seconds, or nil if no state is saved.
    public func stateAge() -> TimeInterval? {
        guard let state = loadState() else { return nil }
        return Date().timeIntervalSince(state.timestamp)
    }
    
    // MARK: - Private Methods
    
    private func checkForRecoverableState() {
        guard policy.isEnabled else {
            hasRecoverableState = false
            return
        }
        
        if let state = loadState() {
            hasRecoverableState = !state.isStale(maxAge: policy.maxStateAge)
            lastSaveTime = state.timestamp
        } else {
            hasRecoverableState = false
        }
    }
    
    private func loadState() -> RecoveryState? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RecoveryState.self, from: data)
    }
    
    private func persistState(_ state: RecoveryState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(state) else { return }
        
        UserDefaults.standard.set(data, forKey: storageKey)
        hasRecoverableState = true
        lastSaveTime = state.timestamp
    }
    
    private func debounceSave(_ state: RecoveryState) {
        saveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.persistState(state)
            }
        }
        
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + policy.saveDebounceInterval,
            execute: workItem
        )
    }
    
    private func executeRecovery(_ state: RecoveryState) -> RecoveryResult<R> {
        // Convert paths to routes
        var routes: [R] = []
        for path in state.routePaths {
            guard let route = routeFactory(path) else {
                if policy.validateRoutes {
                    return .invalid(reason: "Unknown route: \(path)")
                }
                continue
            }
            
            if let validator = routeValidator, !validator(route) {
                if policy.validateRoutes {
                    return .invalid(reason: "Invalid route: \(path)")
                }
                continue
            }
            
            routes.append(route)
        }
        
        // Convert presented route
        var presentedRoute: R?
        if policy.recoverModals,
           let presentedPath = state.presentedRoutePath,
           let route = routeFactory(presentedPath) {
            presentedRoute = route
        }
        
        // Clear state after successful recovery
        if policy.clearAfterRecovery {
            clearState()
        }
        
        return .success(routes: routes, presentedRoute: presentedRoute)
    }
}

// MARK: - Presentation Style Extension

extension PresentationStyle {
    var rawValue: String {
        switch self {
        case .sheet: return "sheet"
        case .fullScreenCover: return "fullScreenCover"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "sheet": self = .sheet
        case "fullScreenCover": self = .fullScreenCover
        default: return nil
        }
    }
}

// MARK: - Safe Navigation Wrapper

/// A wrapper that provides crash-safe navigation with automatic state saving.
///
/// Use this wrapper around your navigator to automatically persist
/// navigation state after every change.
///
/// ```swift
/// let safeNavigator = SafeNavigator(
///     navigator: navigator,
///     recovery: recoveryManager
/// )
///
/// // All navigation is automatically saved
/// safeNavigator.push(.profile)
/// ```
@MainActor
public final class SafeNavigator<R: Route>: ObservableObject {
    
    // MARK: - Properties
    
    /// The underlying navigator.
    public let navigator: Navigator<R>
    
    /// The crash recovery manager.
    public let recovery: CrashRecoveryManager<R>
    
    /// Combine cancellables.
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Creates a safe navigator.
    ///
    /// - Parameters:
    ///   - navigator: The underlying navigator.
    ///   - recovery: The crash recovery manager.
    public init(navigator: Navigator<R>, recovery: CrashRecoveryManager<R>) {
        self.navigator = navigator
        self.recovery = recovery
        
        setupAutoSave()
    }
    
    // MARK: - Navigation Forwarding
    
    /// Pushes a route onto the navigation stack.
    public func push(_ route: R) {
        navigator.push(route)
        saveState()
    }
    
    /// Pops the top route from the stack.
    public func pop() {
        navigator.pop()
        saveState()
    }
    
    /// Pops to the root of the navigation stack.
    public func popToRoot() {
        navigator.popToRoot()
        saveState()
    }
    
    /// Presents a route modally.
    public func present(_ route: R, style: PresentationStyle) {
        navigator.present(route, style: style)
        saveState()
    }
    
    /// Dismisses the current modal presentation.
    public func dismiss() {
        navigator.dismiss()
        saveState()
    }
    
    // MARK: - Private Methods
    
    private func setupAutoSave() {
        // Observe path changes
        navigator.$path
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveState()
            }
            .store(in: &cancellables)
    }
    
    private func saveState() {
        recovery.saveState(
            routes: navigator.routeStack,
            presentedRoute: navigator.presentedRoute,
            presentationStyle: navigator.isSheetPresented ? .sheet : navigator.isFullScreenCoverPresented ? .fullScreenCover : nil
        )
    }
}
