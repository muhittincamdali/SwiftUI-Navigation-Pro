import Foundation

/// A codable snapshot of the current navigation state.
///
/// Use `NavigationState` to persist and restore the navigation stack across
/// app launches. The router can encode its state into this structure and
/// decode it later to rebuild the stack.
///
/// ```swift
/// let state = NavigationState(routes: router.routeStack)
/// let data = try JSONEncoder().encode(state)
/// ```
public struct NavigationState<R: Route>: Codable {

    // MARK: - Properties

    /// The ordered list of routes in the navigation stack.
    public let routes: [R]

    /// The timestamp when this state was captured.
    public let capturedAt: Date

    /// An optional identifier for the state snapshot.
    public let snapshotId: String

    /// The version of the state schema, used for migration.
    public let schemaVersion: Int

    // MARK: - Constants

    /// The current schema version for encoding.
    private static var currentSchemaVersion: Int { 1 }

    // MARK: - Initialization

    /// Creates a navigation state with the given routes.
    ///
    /// - Parameter routes: The routes currently on the navigation stack.
    public init(routes: [R]) {
        self.routes = routes
        self.capturedAt = Date()
        self.snapshotId = UUID().uuidString
        self.schemaVersion = Self.currentSchemaVersion
    }

    /// Creates a navigation state with full control over all properties.
    ///
    /// - Parameters:
    ///   - routes: The routes on the stack.
    ///   - capturedAt: The capture timestamp.
    ///   - snapshotId: A unique identifier for this snapshot.
    ///   - schemaVersion: The schema version number.
    public init(routes: [R], capturedAt: Date, snapshotId: String, schemaVersion: Int) {
        self.routes = routes
        self.capturedAt = capturedAt
        self.snapshotId = snapshotId
        self.schemaVersion = schemaVersion
    }

    // MARK: - Queries

    /// Whether the state represents an empty (root) navigation stack.
    public var isEmpty: Bool {
        routes.isEmpty
    }

    /// The number of routes in the state.
    public var depth: Int {
        routes.count
    }

    /// The topmost route in the state, if any.
    public var topRoute: R? {
        routes.last
    }

    /// The root route in the state, if any.
    public var rootRoute: R? {
        routes.first
    }

    /// Returns the route at the specified depth, if it exists.
    ///
    /// - Parameter index: The zero-based index into the route stack.
    /// - Returns: The route at the given index, or `nil` if out of bounds.
    public func route(at index: Int) -> R? {
        guard routes.indices.contains(index) else { return nil }
        return routes[index]
    }

    // MARK: - Validation

    /// Validates the state by checking schema version compatibility.
    ///
    /// - Returns: `true` if the state can be restored with the current schema.
    public func isValid() -> Bool {
        schemaVersion <= Self.currentSchemaVersion
    }

    /// Returns a new state with routes matching the given predicate removed.
    ///
    /// - Parameter predicate: A closure that returns `true` for routes to keep.
    /// - Returns: A filtered `NavigationState`.
    public func filtered(_ predicate: (R) -> Bool) -> NavigationState<R> {
        NavigationState(
            routes: routes.filter(predicate),
            capturedAt: capturedAt,
            snapshotId: snapshotId,
            schemaVersion: schemaVersion
        )
    }
}

// MARK: - Equatable

extension NavigationState: Equatable where R: Equatable {
    public static func == (lhs: NavigationState<R>, rhs: NavigationState<R>) -> Bool {
        lhs.routes == rhs.routes && lhs.snapshotId == rhs.snapshotId
    }
}

// MARK: - CustomStringConvertible

extension NavigationState: CustomStringConvertible {
    public var description: String {
        let routePaths = routes.map(\.path).joined(separator: " → ")
        return "NavigationState(\(depth) routes: \(routePaths.isEmpty ? "root" : routePaths))"
    }
}
