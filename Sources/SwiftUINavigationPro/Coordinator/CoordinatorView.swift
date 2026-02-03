import SwiftUI

/// A SwiftUI view that hosts a coordinator's navigation flow.
///
/// `CoordinatorView` wraps a `NavigationStack` driven by the coordinator's
/// internal router. Provide a `@ViewBuilder` closure that maps each route
/// to its destination view.
///
/// ```swift
/// CoordinatorView(coordinator: onboardingCoordinator) { route in
///     switch route {
///     case .welcome: WelcomeView()
///     case .signup: SignUpView()
///     case .complete: CompleteView()
///     }
/// }
/// ```
public struct CoordinatorView<R: Route, Content: View>: View {

    // MARK: - Properties

    /// The coordinator managing the navigation flow.
    @ObservedObject var coordinator: Coordinator<R>

    /// A closure that builds the destination view for each route.
    let routeView: (R) -> Content

    // MARK: - Initialization

    /// Creates a coordinator view.
    ///
    /// - Parameters:
    ///   - coordinator: The coordinator to observe.
    ///   - routeView: A view builder mapping routes to views.
    public init(
        coordinator: Coordinator<R>,
        @ViewBuilder routeView: @escaping (R) -> Content
    ) {
        self.coordinator = coordinator
        self.routeView = routeView
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack(path: $coordinator.router.navigationPath) {
            rootContent
                .navigationDestination(for: R.self) { route in
                    routeView(route)
                        .environmentObject(coordinator.router)
                        .environmentObject(coordinator)
                }
        }
        .sheet(isPresented: $coordinator.router.isSheetPresented) {
            if let route = coordinator.router.presentedSheet {
                routeView(route)
                    .environmentObject(coordinator.router)
                    .environmentObject(coordinator)
            }
        }
        .onAppear {
            if !coordinator.isStarted {
                coordinator.start()
            }
        }
    }

    // MARK: - Private

    @ViewBuilder
    private var rootContent: some View {
        if let topRoute = coordinator.router.routeStack.first {
            routeView(topRoute)
                .environmentObject(coordinator.router)
                .environmentObject(coordinator)
        } else {
            Color.clear
        }
    }
}
