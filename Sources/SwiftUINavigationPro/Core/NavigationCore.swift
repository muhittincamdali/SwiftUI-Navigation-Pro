import SwiftUI

/// Main entry point for the SwiftUI Navigation Pro toolkit.
public enum NavigationPro {
    public static let version = "2.0.0"
}

/// A world-class standard for navigation state management.
@MainActor
public final class NavigationState: ObservableObject {
    @Published public var path = NavigationPath()
    
    public init() {}
    
    public func navigate<T: Hashable>(to route: T) {
        path.append(route)
    }
    
    public func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
}
