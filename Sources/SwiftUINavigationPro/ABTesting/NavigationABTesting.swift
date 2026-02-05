import Foundation
import Combine

// MARK: - Experiment Variant

/// A variant in an A/B test experiment.
public struct ExperimentVariant<R: Route>: Identifiable, Sendable {
    /// Unique identifier for this variant.
    public let id: String
    /// Display name for the variant.
    public let name: String
    /// The navigation flow for this variant.
    public let flow: [R]
    /// Weight for random assignment (higher = more likely).
    public let weight: Double
    /// Custom parameters for this variant.
    public let parameters: [String: String]
    
    /// Creates an experiment variant.
    public init(
        id: String,
        name: String,
        flow: [R],
        weight: Double = 1.0,
        parameters: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.flow = flow
        self.weight = weight
        self.parameters = parameters
    }
}

// MARK: - Experiment

/// An A/B test experiment definition.
public struct Experiment<R: Route>: Identifiable, Sendable {
    /// Unique identifier for this experiment.
    public let id: String
    /// Display name for the experiment.
    public let name: String
    /// Description of what's being tested.
    public let description: String
    /// The variants in this experiment.
    public let variants: [ExperimentVariant<R>]
    /// The control variant ID.
    public let controlVariantId: String
    /// Whether the experiment is currently active.
    public let isActive: Bool
    /// The start date of the experiment.
    public let startDate: Date?
    /// The end date of the experiment.
    public let endDate: Date?
    /// User eligibility criteria.
    public let eligibilityCriteria: ExperimentEligibility?
    /// Metrics to track for this experiment.
    public let metrics: [String]
    
    /// Creates an experiment.
    public init(
        id: String,
        name: String,
        description: String = "",
        variants: [ExperimentVariant<R>],
        controlVariantId: String,
        isActive: Bool = true,
        startDate: Date? = nil,
        endDate: Date? = nil,
        eligibilityCriteria: ExperimentEligibility? = nil,
        metrics: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.variants = variants
        self.controlVariantId = controlVariantId
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
        self.eligibilityCriteria = eligibilityCriteria
        self.metrics = metrics
    }
    
    /// The control variant.
    public var controlVariant: ExperimentVariant<R>? {
        variants.first { $0.id == controlVariantId }
    }
    
    /// Whether the experiment is currently running.
    public var isRunning: Bool {
        guard isActive else { return false }
        let now = Date()
        if let start = startDate, now < start { return false }
        if let end = endDate, now > end { return false }
        return true
    }
}

// MARK: - Experiment Eligibility

/// Criteria for determining user eligibility for an experiment.
public struct ExperimentEligibility: Sendable {
    /// Minimum app version.
    public let minAppVersion: String?
    /// Maximum app version.
    public let maxAppVersion: String?
    /// Required user attributes.
    public let requiredAttributes: [String: String]
    /// Excluded user attributes.
    public let excludedAttributes: [String: String]
    /// Percentage of users to include (0.0 to 1.0).
    public let userPercentage: Double
    /// Specific user IDs to include.
    public let includedUserIds: Set<String>
    /// Specific user IDs to exclude.
    public let excludedUserIds: Set<String>
    
    /// Creates eligibility criteria.
    public init(
        minAppVersion: String? = nil,
        maxAppVersion: String? = nil,
        requiredAttributes: [String: String] = [:],
        excludedAttributes: [String: String] = [:],
        userPercentage: Double = 1.0,
        includedUserIds: Set<String> = [],
        excludedUserIds: Set<String> = []
    ) {
        self.minAppVersion = minAppVersion
        self.maxAppVersion = maxAppVersion
        self.requiredAttributes = requiredAttributes
        self.excludedAttributes = excludedAttributes
        self.userPercentage = userPercentage
        self.includedUserIds = includedUserIds
        self.excludedUserIds = excludedUserIds
    }
}

// MARK: - Experiment Assignment

/// A user's assignment to an experiment variant.
public struct ExperimentAssignment: Codable, Sendable {
    /// The experiment ID.
    public let experimentId: String
    /// The assigned variant ID.
    public let variantId: String
    /// When the assignment was made.
    public let assignedAt: Date
    /// The user ID, if available.
    public let userId: String?
    /// Whether this is the control variant.
    public let isControl: Bool
    
    /// Creates an experiment assignment.
    public init(
        experimentId: String,
        variantId: String,
        assignedAt: Date = Date(),
        userId: String? = nil,
        isControl: Bool = false
    ) {
        self.experimentId = experimentId
        self.variantId = variantId
        self.assignedAt = assignedAt
        self.userId = userId
        self.isControl = isControl
    }
}

// MARK: - Experiment Event

/// An event tracked for an experiment.
public struct ExperimentEvent: Codable, Sendable {
    /// The experiment ID.
    public let experimentId: String
    /// The variant ID.
    public let variantId: String
    /// The event name.
    public let eventName: String
    /// The event timestamp.
    public let timestamp: Date
    /// Event properties.
    public let properties: [String: String]
    /// The user ID, if available.
    public let userId: String?
    
    /// Creates an experiment event.
    public init(
        experimentId: String,
        variantId: String,
        eventName: String,
        timestamp: Date = Date(),
        properties: [String: String] = [:],
        userId: String? = nil
    ) {
        self.experimentId = experimentId
        self.variantId = variantId
        self.eventName = eventName
        self.timestamp = timestamp
        self.properties = properties
        self.userId = userId
    }
}

// MARK: - A/B Testing Manager

/// A manager for navigation A/B testing experiments.
///
/// `NavigationABTestingManager` enables testing different navigation flows
/// to optimize user experience and conversion rates.
///
/// ```swift
/// let abManager = NavigationABTestingManager<AppRoute>()
///
/// // Define an experiment
/// let experiment = Experiment(
///     id: "onboarding_v2",
///     name: "New Onboarding Flow",
///     variants: [
///         ExperimentVariant(id: "control", name: "Original", flow: [.welcome, .signup, .home]),
///         ExperimentVariant(id: "treatment", name: "Simplified", flow: [.welcome, .home])
///     ],
///     controlVariantId: "control"
/// )
///
/// abManager.registerExperiment(experiment)
///
/// // Get the flow for a user
/// let flow = abManager.getFlow(for: "onboarding_v2")
/// ```
@MainActor
public final class NavigationABTestingManager<R: Route>: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All registered experiments.
    @Published public private(set) var experiments: [String: Experiment<R>] = [:]
    
    /// Current user's assignments.
    @Published public private(set) var assignments: [String: ExperimentAssignment] = [:]
    
    /// Tracked events.
    @Published public private(set) var events: [ExperimentEvent] = []
    
    // MARK: - Properties
    
    /// The current user ID.
    public var userId: String?
    
    /// User attributes for eligibility checking.
    public var userAttributes: [String: String] = [:]
    
    /// Storage key for persisted assignments.
    public let storageKey: String
    
    /// Event handler for analytics integration.
    public var eventHandler: ((ExperimentEvent) -> Void)?
    
    /// Maximum events to keep in memory.
    public var maxEventsInMemory: Int = 1000
    
    /// Random number generator for variant assignment.
    private var rng = SystemRandomNumberGenerator()
    
    // MARK: - Initialization
    
    /// Creates an A/B testing manager.
    ///
    /// - Parameter storageKey: The key for persistent storage.
    public init(storageKey: String = "navigation_ab_assignments") {
        self.storageKey = storageKey
        loadAssignments()
    }
    
    // MARK: - Experiment Management
    
    /// Registers an experiment.
    ///
    /// - Parameter experiment: The experiment to register.
    public func registerExperiment(_ experiment: Experiment<R>) {
        experiments[experiment.id] = experiment
    }
    
    /// Registers multiple experiments.
    ///
    /// - Parameter experiments: The experiments to register.
    public func registerExperiments(_ experiments: [Experiment<R>]) {
        for experiment in experiments {
            registerExperiment(experiment)
        }
    }
    
    /// Unregisters an experiment.
    ///
    /// - Parameter experimentId: The experiment ID to unregister.
    public func unregisterExperiment(_ experimentId: String) {
        experiments.removeValue(forKey: experimentId)
    }
    
    /// Clears all experiments.
    public func clearExperiments() {
        experiments.removeAll()
    }
    
    // MARK: - Variant Assignment
    
    /// Gets the assigned variant for an experiment.
    ///
    /// If no assignment exists, one will be created based on variant weights.
    ///
    /// - Parameter experimentId: The experiment ID.
    /// - Returns: The assigned variant, if the experiment exists and user is eligible.
    public func getVariant(for experimentId: String) -> ExperimentVariant<R>? {
        guard let experiment = experiments[experimentId],
              experiment.isRunning,
              isEligible(for: experiment) else {
            return nil
        }
        
        // Check for existing assignment
        if let assignment = assignments[experimentId],
           let variant = experiment.variants.first(where: { $0.id == assignment.variantId }) {
            return variant
        }
        
        // Create new assignment
        let variant = assignVariant(for: experiment)
        return variant
    }
    
    /// Gets the navigation flow for an experiment.
    ///
    /// - Parameter experimentId: The experiment ID.
    /// - Returns: The assigned flow, or nil if not available.
    public func getFlow(for experimentId: String) -> [R]? {
        getVariant(for: experimentId)?.flow
    }
    
    /// Forces assignment to a specific variant.
    ///
    /// - Parameters:
    ///   - variantId: The variant ID to assign.
    ///   - experimentId: The experiment ID.
    public func forceVariant(_ variantId: String, for experimentId: String) {
        guard let experiment = experiments[experimentId],
              experiment.variants.contains(where: { $0.id == variantId }) else {
            return
        }
        
        let assignment = ExperimentAssignment(
            experimentId: experimentId,
            variantId: variantId,
            userId: userId,
            isControl: variantId == experiment.controlVariantId
        )
        
        assignments[experimentId] = assignment
        saveAssignments()
    }
    
    /// Clears the assignment for an experiment.
    ///
    /// - Parameter experimentId: The experiment ID.
    public func clearAssignment(for experimentId: String) {
        assignments.removeValue(forKey: experimentId)
        saveAssignments()
    }
    
    /// Clears all assignments.
    public func clearAllAssignments() {
        assignments.removeAll()
        saveAssignments()
    }
    
    // MARK: - Event Tracking
    
    /// Tracks a conversion event for an experiment.
    ///
    /// - Parameters:
    ///   - eventName: The event name.
    ///   - experimentId: The experiment ID.
    ///   - properties: Additional properties.
    public func trackEvent(
        _ eventName: String,
        for experimentId: String,
        properties: [String: String] = [:]
    ) {
        guard let assignment = assignments[experimentId] else { return }
        
        let event = ExperimentEvent(
            experimentId: experimentId,
            variantId: assignment.variantId,
            eventName: eventName,
            properties: properties,
            userId: userId
        )
        
        events.append(event)
        
        // Trim events if needed
        if events.count > maxEventsInMemory {
            events = Array(events.suffix(maxEventsInMemory))
        }
        
        eventHandler?(event)
    }
    
    /// Tracks a flow completion event.
    ///
    /// - Parameters:
    ///   - experimentId: The experiment ID.
    ///   - success: Whether the flow was completed successfully.
    ///   - properties: Additional properties.
    public func trackFlowCompletion(
        for experimentId: String,
        success: Bool,
        properties: [String: String] = [:]
    ) {
        var props = properties
        props["success"] = String(success)
        trackEvent("flow_completion", for: experimentId, properties: props)
    }
    
    /// Tracks a flow drop-off event.
    ///
    /// - Parameters:
    ///   - experimentId: The experiment ID.
    ///   - atStep: The step where drop-off occurred.
    ///   - properties: Additional properties.
    public func trackDropOff(
        for experimentId: String,
        atStep: String,
        properties: [String: String] = [:]
    ) {
        var props = properties
        props["drop_off_step"] = atStep
        trackEvent("flow_drop_off", for: experimentId, properties: props)
    }
    
    /// Clears all tracked events.
    public func clearEvents() {
        events.removeAll()
    }
    
    // MARK: - Queries
    
    /// Checks if the user is assigned to the control variant.
    ///
    /// - Parameter experimentId: The experiment ID.
    /// - Returns: Whether the user is in the control group.
    public func isControl(for experimentId: String) -> Bool {
        assignments[experimentId]?.isControl ?? false
    }
    
    /// Gets all active experiment IDs.
    ///
    /// - Returns: An array of active experiment IDs.
    public func activeExperimentIds() -> [String] {
        experiments.values.filter(\.isRunning).map(\.id)
    }
    
    /// Gets the assignment for an experiment.
    ///
    /// - Parameter experimentId: The experiment ID.
    /// - Returns: The assignment, if any.
    public func getAssignment(for experimentId: String) -> ExperimentAssignment? {
        assignments[experimentId]
    }
    
    /// Exports all events as JSON.
    ///
    /// - Returns: The JSON data, if encoding succeeds.
    public func exportEventsAsJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(events)
    }
    
    // MARK: - Private Methods
    
    private func isEligible(for experiment: Experiment<R>) -> Bool {
        guard let eligibility = experiment.eligibilityCriteria else {
            return true
        }
        
        // Check user ID inclusion/exclusion
        if let userId = userId {
            if !eligibility.includedUserIds.isEmpty && !eligibility.includedUserIds.contains(userId) {
                return false
            }
            if eligibility.excludedUserIds.contains(userId) {
                return false
            }
        }
        
        // Check required attributes
        for (key, value) in eligibility.requiredAttributes {
            guard userAttributes[key] == value else { return false }
        }
        
        // Check excluded attributes
        for (key, value) in eligibility.excludedAttributes {
            if userAttributes[key] == value { return false }
        }
        
        // Check user percentage
        if eligibility.userPercentage < 1.0 {
            let hash = userIdHash()
            if hash > eligibility.userPercentage {
                return false
            }
        }
        
        return true
    }
    
    private func assignVariant(for experiment: Experiment<R>) -> ExperimentVariant<R>? {
        guard !experiment.variants.isEmpty else { return nil }
        
        // Calculate total weight
        let totalWeight = experiment.variants.reduce(0) { $0 + $1.weight }
        
        // Generate random value
        let random = Double.random(in: 0..<totalWeight, using: &rng)
        
        // Select variant based on weight
        var cumulative: Double = 0
        for variant in experiment.variants {
            cumulative += variant.weight
            if random < cumulative {
                // Create assignment
                let assignment = ExperimentAssignment(
                    experimentId: experiment.id,
                    variantId: variant.id,
                    userId: userId,
                    isControl: variant.id == experiment.controlVariantId
                )
                
                assignments[experiment.id] = assignment
                saveAssignments()
                
                // Track assignment event
                trackEvent("variant_assigned", for: experiment.id, properties: [
                    "variant_id": variant.id,
                    "variant_name": variant.name
                ])
                
                return variant
            }
        }
        
        return experiment.variants.last
    }
    
    private func userIdHash() -> Double {
        let id = userId ?? UUID().uuidString
        var hasher = Hasher()
        hasher.combine(id)
        let hash = abs(hasher.finalize())
        return Double(hash % 1000) / 1000.0
    }
    
    private func loadAssignments() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: ExperimentAssignment].self, from: data) else {
            return
        }
        assignments = decoded
    }
    
    private func saveAssignments() {
        guard let data = try? JSONEncoder().encode(assignments) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - Flow Experiment Builder

/// A builder for creating navigation flow experiments.
public struct FlowExperimentBuilder<R: Route> {
    private var id: String
    private var name: String
    private var description: String = ""
    private var variants: [ExperimentVariant<R>] = []
    private var controlVariantId: String?
    private var isActive: Bool = true
    private var startDate: Date?
    private var endDate: Date?
    private var eligibility: ExperimentEligibility?
    private var metrics: [String] = []
    
    /// Creates a flow experiment builder.
    ///
    /// - Parameters:
    ///   - id: The experiment ID.
    ///   - name: The experiment name.
    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
    
    /// Adds a description.
    public func description(_ description: String) -> FlowExperimentBuilder {
        var builder = self
        builder.description = description
        return builder
    }
    
    /// Adds a control variant.
    public func control(id: String = "control", name: String = "Control", flow: [R]) -> FlowExperimentBuilder {
        var builder = self
        builder.variants.append(ExperimentVariant(id: id, name: name, flow: flow))
        builder.controlVariantId = id
        return builder
    }
    
    /// Adds a treatment variant.
    public func treatment(id: String, name: String, flow: [R], weight: Double = 1.0) -> FlowExperimentBuilder {
        var builder = self
        builder.variants.append(ExperimentVariant(id: id, name: name, flow: flow, weight: weight))
        return builder
    }
    
    /// Sets the experiment schedule.
    public func schedule(start: Date? = nil, end: Date? = nil) -> FlowExperimentBuilder {
        var builder = self
        builder.startDate = start
        builder.endDate = end
        return builder
    }
    
    /// Sets eligibility criteria.
    public func eligibility(_ eligibility: ExperimentEligibility) -> FlowExperimentBuilder {
        var builder = self
        builder.eligibility = eligibility
        return builder
    }
    
    /// Adds metrics to track.
    public func metrics(_ metrics: [String]) -> FlowExperimentBuilder {
        var builder = self
        builder.metrics = metrics
        return builder
    }
    
    /// Sets whether the experiment is active.
    public func active(_ isActive: Bool) -> FlowExperimentBuilder {
        var builder = self
        builder.isActive = isActive
        return builder
    }
    
    /// Builds the experiment.
    public func build() -> Experiment<R> {
        Experiment(
            id: id,
            name: name,
            description: description,
            variants: variants,
            controlVariantId: controlVariantId ?? variants.first?.id ?? "",
            isActive: isActive,
            startDate: startDate,
            endDate: endDate,
            eligibilityCriteria: eligibility,
            metrics: metrics
        )
    }
}
