import SwiftUI
import SwiftUINavigationPro

// MARK: - App Routes

/// Defines all navigable routes in the example app.
enum AppRoute: Route {
    case home
    case profile(userId: String)
    case settings
    case detail(itemId: Int)
    case search(query: String)
    case notifications
    case about
    
    var id: String {
        switch self {
        case .home: return "home"
        case .profile(let userId): return "profile-\(userId)"
        case .settings: return "settings"
        case .detail(let itemId): return "detail-\(itemId)"
        case .search(let query): return "search-\(query)"
        case .notifications: return "notifications"
        case .about: return "about"
        }
    }
}

// MARK: - App Tabs

/// Defines the main tabs in the example app.
enum AppTab: String, TabItem, CaseIterable {
    case home
    case search
    case notifications
    case profile
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .notifications: return "Notifications"
        case .profile: return "Profile"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .notifications: return "bell"
        case .profile: return "person"
        }
    }
}

// MARK: - Basic Navigation App

/// A complete example app demonstrating basic navigation.
struct BasicNavigationApp: View {
    @StateObject private var router = Router<AppRoute>()
    @StateObject private var tabCoordinator = TabCoordinator<AppTab>(
        configuration: .init(initialTab: .home)
    )
    
    var body: some View {
        TabCoordinatorView(coordinator: tabCoordinator) { tab in
            NavigationStack(path: $router.path) {
                tabContent(for: tab)
                    .navigationDestination(for: AppRoute.self) { route in
                        destinationView(for: route)
                    }
            }
        }
        .environmentObject(router)
    }
    
    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .search:
            SearchView()
        case .notifications:
            NotificationsView()
        case .profile:
            ProfileView(userId: "current-user")
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeView()
        case .profile(let userId):
            ProfileView(userId: userId)
        case .settings:
            SettingsView()
        case .detail(let itemId):
            DetailView(itemId: itemId)
        case .search(let query):
            SearchResultsView(query: query)
        case .notifications:
            NotificationsView()
        case .about:
            AboutView()
        }
    }
}

// MARK: - Home View

/// The main home view with navigation examples.
struct HomeView: View {
    @EnvironmentObject private var router: Router<AppRoute>
    
    var body: some View {
        List {
            Section("Navigation Examples") {
                Button("View Profile") {
                    router.push(.profile(userId: "user-123"))
                }
                
                Button("View Item Details") {
                    router.push(.detail(itemId: 42))
                }
                
                Button("Open Settings") {
                    router.push(.settings)
                }
                
                Button("Search for 'SwiftUI'") {
                    router.push(.search(query: "SwiftUI"))
                }
            }
            
            Section("Programmatic Navigation") {
                Button("Push Multiple") {
                    router.push(.settings)
                    router.push(.about)
                }
                
                Button("Replace Stack") {
                    router.replaceAll(with: [.home, .profile(userId: "new-user")])
                }
            }
        }
        .navigationTitle("Home")
    }
}

// MARK: - Profile View

/// A user profile view.
struct ProfileView: View {
    let userId: String
    @EnvironmentObject private var router: Router<AppRoute>
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("User: \(userId)")
                .font(.title2)
            
            Button("View Settings") {
                router.push(.settings)
            }
            .buttonStyle(.borderedProminent)
            
            Button("Go Back") {
                router.pop()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Profile")
    }
}

// MARK: - Settings View

/// The settings view.
struct SettingsView: View {
    @EnvironmentObject private var router: Router<AppRoute>
    
    var body: some View {
        List {
            Section("Account") {
                NavigationLink("Profile", value: AppRoute.profile(userId: "current"))
                NavigationLink("Notifications", value: AppRoute.notifications)
            }
            
            Section("App") {
                NavigationLink("About", value: AppRoute.about)
            }
            
            Section("Navigation") {
                Button("Pop to Root") {
                    router.popToRoot()
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Detail View

/// A detail view for an item.
struct DetailView: View {
    let itemId: Int
    @EnvironmentObject private var router: Router<AppRoute>
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Item #\(itemId)")
                .font(.title)
            
            Text("This is the detail view for item \(itemId).")
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button("Previous") {
                    router.pop()
                    router.push(.detail(itemId: itemId - 1))
                }
                .disabled(itemId <= 1)
                
                Button("Next") {
                    router.pop()
                    router.push(.detail(itemId: itemId + 1))
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Item \(itemId)")
    }
}

// MARK: - Search View

/// The search view.
struct SearchView: View {
    @State private var query = ""
    @EnvironmentObject private var router: Router<AppRoute>
    
    var body: some View {
        VStack {
            TextField("Search...", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding()
                .onSubmit {
                    if !query.isEmpty {
                        router.push(.search(query: query))
                    }
                }
            
            List {
                ForEach(["SwiftUI", "UIKit", "Combine", "Swift"], id: \.self) { suggestion in
                    Button(suggestion) {
                        router.push(.search(query: suggestion))
                    }
                }
            }
        }
        .navigationTitle("Search")
    }
}

// MARK: - Search Results View

/// Displays search results.
struct SearchResultsView: View {
    let query: String
    
    var body: some View {
        List {
            ForEach(1...10, id: \.self) { index in
                Text("Result \(index) for '\(query)'")
            }
        }
        .navigationTitle("Results: \(query)")
    }
}

// MARK: - Notifications View

/// The notifications view.
struct NotificationsView: View {
    var body: some View {
        List {
            ForEach(1...5, id: \.self) { index in
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("Notification \(index)")
                            .font(.headline)
                        Text("This is a sample notification message.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
    }
}

// MARK: - About View

/// The about view.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("SwiftUI Navigation Pro")
                .font(.title)
            
            Text("Version 1.0.0")
                .foregroundColor(.secondary)
            
            Text("A comprehensive navigation framework for SwiftUI applications.")
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
        .navigationTitle("About")
    }
}

// MARK: - Preview

#Preview {
    BasicNavigationApp()
}
