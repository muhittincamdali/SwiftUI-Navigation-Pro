import Foundation

/// A protocol that defines a navigable route within the application.
///
/// Conform your route enums to this protocol to gain type-safe navigation
/// throughout your app. Each route must provide a string path for deep linking
/// and state persistence.
///
/// ```swift
/// enum AppRoute: Route {
///     case home
///     case profile(userId: String)
///
///     var path: String {
///         switch self {
///         case .home: return "/home"
///         case .profile(let id): return "/profile/\(id)"
///         }
///     }
/// }
/// ```
public protocol Route: Hashable, Codable, Identifiable {
    /// A string representation of the route path, used for deep linking.
    var path: String { get }

    /// An optional title for the route, displayed in navigation bars.
    var title: String? { get }

    /// Whether the route should be presented modally rather than pushed.
    var isModal: Bool { get }

    /// The preferred presentation style when the route is modal.
    var preferredPresentationStyle: PresentationStyle { get }
}

// MARK: - Default Implementations

public extension Route {
    /// Default identifier derived from the route path.
    var id: String { path }

    /// Default title is `nil`, letting the destination view set its own.
    var title: String? { nil }

    /// By default routes are not modal.
    var isModal: Bool { false }

    /// Default presentation style is `.sheet`.
    var preferredPresentationStyle: PresentationStyle { .sheet }
}

// MARK: - TabItem Protocol

/// A protocol for defining tab bar items in a tab-based navigation setup.
///
/// Conform your tab enum to this protocol to use it with ``TabRouter``.
///
/// ```swift
/// enum AppTab: String, TabItem {
///     case home, search, profile
///     var title: String { rawValue.capitalized }
///     var icon: String { "house" }
/// }
/// ```
public protocol TabItem: Hashable, CaseIterable, Identifiable {
    /// The display title of the tab.
    var title: String { get }

    /// The SF Symbol name for the tab icon.
    var icon: String { get }

    /// An optional badge value displayed on the tab.
    var badge: String? { get }
}

public extension TabItem where Self: RawRepresentable, RawValue == String {
    /// Default identifier using the raw value.
    var id: String { rawValue }

    /// Default badge is `nil`.
    var badge: String? { nil }
}

public extension TabItem {
    /// Default identifier using the title.
    var id: String { title }

    /// Default badge is `nil`.
    var badge: String? { nil }
}
