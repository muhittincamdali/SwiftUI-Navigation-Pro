import SwiftUI
import SwiftUINavigationPro

// MARK: - Deep Link Routes

/// Routes for the deep link example.
enum DeepLinkRoute: Route {
    case home
    case product(id: String)
    case category(name: String)
    case profile(userId: String)
    case settings
    case search(query: String)
    case promo(code: String)
    case order(orderId: String)
    
    var id: String {
        switch self {
        case .home: return "home"
        case .product(let id): return "product-\(id)"
        case .category(let name): return "category-\(name)"
        case .profile(let userId): return "profile-\(userId)"
        case .settings: return "settings"
        case .search(let query): return "search-\(query)"
        case .promo(let code): return "promo-\(code)"
        case .order(let orderId): return "order-\(orderId)"
        }
    }
}

// MARK: - Deep Link Parser Setup

/// Creates a configured deep link parser.
func createDeepLinkParser() -> DeepLinkParser<DeepLinkRoute> {
    var parser = DeepLinkParser<DeepLinkRoute>(
        schemes: ["myapp", "https"],
        host: "example.com"
    ) { url in
        // Fallback handler for unmatched URLs
        return .home
    }
    
    // Register product URLs: /product/:id
    parser.register("/product/:id") { params in
        guard let id = params["id"] else { return nil }
        return .product(id: id)
    }
    
    // Register category URLs: /category/:name
    parser.register("/category/:name") { params in
        guard let name = params["name"] else { return nil }
        return .category(name: name)
    }
    
    // Register profile URLs: /user/:userId
    parser.register("/user/:userId") { params in
        guard let userId = params["userId"] else { return nil }
        return .profile(userId: userId)
    }
    
    // Register search URLs: /search (with query parameter)
    parser.register("/search") { params in
        // Query parameters will be extracted separately
        return .search(query: "")
    }
    
    // Register promo URLs: /promo/:code
    parser.register("/promo/:code") { params in
        guard let code = params["code"] else { return nil }
        return .promo(code: code)
    }
    
    // Register order URLs: /order/:orderId
    parser.register("/order/:orderId") { params in
        guard let orderId = params["orderId"] else { return nil }
        return .order(orderId: orderId)
    }
    
    return parser
}

// MARK: - Deep Link Example App

/// Example app demonstrating deep link handling.
struct DeepLinkExampleApp: View {
    @StateObject private var router = Router<DeepLinkRoute>()
    @StateObject private var deepLinkHandler: DeepLinkHandler<DeepLinkRoute>
    
    @State private var showDeepLinkAlert = false
    @State private var lastDeepLink: URL?
    
    init() {
        let parser = createDeepLinkParser()
        _deepLinkHandler = StateObject(wrappedValue: DeepLinkHandler(parser: parser))
    }
    
    var body: some View {
        NavigationStack(path: $router.path) {
            DeepLinkHomeView()
                .navigationDestination(for: DeepLinkRoute.self) { route in
                    destinationView(for: route)
                }
        }
        .environmentObject(router)
        .environmentObject(deepLinkHandler)
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .alert("Deep Link Received", isPresented: $showDeepLinkAlert) {
            Button("OK") {}
        } message: {
            if let url = lastDeepLink {
                Text("URL: \(url.absoluteString)")
            }
        }
    }
    
    @ViewBuilder
    private func destinationView(for route: DeepLinkRoute) -> some View {
        switch route {
        case .home:
            DeepLinkHomeView()
        case .product(let id):
            ProductDetailView(productId: id)
        case .category(let name):
            CategoryView(categoryName: name)
        case .profile(let userId):
            UserProfileView(userId: userId)
        case .settings:
            SettingsPageView()
        case .search(let query):
            SearchPageView(initialQuery: query)
        case .promo(let code):
            PromoCodeView(code: code)
        case .order(let orderId):
            OrderDetailView(orderId: orderId)
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        lastDeepLink = url
        showDeepLinkAlert = true
        
        if deepLinkHandler.handle(url) {
            if let route = deepLinkHandler.currentRoute {
                router.push(route)
            }
        }
    }
}

// MARK: - Deep Link Home View

/// Home view with deep link testing options.
struct DeepLinkHomeView: View {
    @EnvironmentObject private var router: Router<DeepLinkRoute>
    @EnvironmentObject private var deepLinkHandler: DeepLinkHandler<DeepLinkRoute>
    
    let testLinks = [
        ("Product Link", "myapp://example.com/product/12345"),
        ("Category Link", "myapp://example.com/category/electronics"),
        ("Profile Link", "myapp://example.com/user/john_doe"),
        ("Search Link", "myapp://example.com/search?q=swift"),
        ("Promo Link", "myapp://example.com/promo/SUMMER20"),
        ("Order Link", "myapp://example.com/order/ORD-789"),
        ("Universal Link", "https://example.com/product/67890")
    ]
    
    var body: some View {
        List {
            Section("Test Deep Links") {
                ForEach(testLinks, id: \.0) { name, url in
                    Button {
                        simulateDeepLink(url)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(name)
                                .font(.headline)
                            Text(url)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section("Direct Navigation") {
                Button("Go to Product") {
                    router.push(.product(id: "test-123"))
                }
                
                Button("Go to Category") {
                    router.push(.category(name: "Books"))
                }
                
                Button("Go to Settings") {
                    router.push(.settings)
                }
            }
            
            Section("Info") {
                if let route = deepLinkHandler.currentRoute {
                    HStack {
                        Text("Last Route:")
                        Spacer()
                        Text(route.id)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Pending Links:")
                    Spacer()
                    Text("\(deepLinkHandler.pendingLinks.count)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Deep Link Demo")
    }
    
    private func simulateDeepLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        if deepLinkHandler.handle(url) {
            if let route = deepLinkHandler.currentRoute {
                router.push(route)
            }
        }
    }
}

// MARK: - Product Detail View

/// Product detail view.
struct ProductDetailView: View {
    let productId: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bag.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Product Details")
                .font(.title)
            
            Text("Product ID: \(productId)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Simulated product info
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Name:")
                    Spacer()
                    Text("Sample Product")
                }
                HStack {
                    Text("Price:")
                    Spacer()
                    Text("$99.99")
                }
                HStack {
                    Text("In Stock:")
                    Spacer()
                    Text("Yes")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Button("Add to Cart") {
                // Action
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Product")
    }
}

// MARK: - Category View

/// Category listing view.
struct CategoryView: View {
    let categoryName: String
    
    var body: some View {
        List {
            ForEach(1...10, id: \.self) { index in
                HStack {
                    Image(systemName: "square.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("Item \(index)")
                            .font(.headline)
                        Text("In \(categoryName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(categoryName)
    }
}

// MARK: - User Profile View

/// User profile view.
struct UserProfileView: View {
    let userId: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("@\(userId)")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: 40) {
                VStack {
                    Text("128")
                        .font(.headline)
                    Text("Posts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("1.2K")
                        .font(.headline)
                    Text("Followers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("456")
                        .font(.headline)
                    Text("Following")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button("Follow") {
                // Action
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Profile")
    }
}

// MARK: - Settings Page View

/// Settings page view.
struct SettingsPageView: View {
    var body: some View {
        List {
            Section("Account") {
                Label("Profile", systemImage: "person")
                Label("Privacy", systemImage: "lock")
                Label("Notifications", systemImage: "bell")
            }
            
            Section("General") {
                Label("Appearance", systemImage: "paintbrush")
                Label("Language", systemImage: "globe")
                Label("About", systemImage: "info.circle")
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Search Page View

/// Search page view.
struct SearchPageView: View {
    let initialQuery: String
    @State private var query: String
    
    init(initialQuery: String) {
        self.initialQuery = initialQuery
        _query = State(initialValue: initialQuery)
    }
    
    var body: some View {
        VStack {
            TextField("Search...", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            List {
                ForEach(1...5, id: \.self) { index in
                    Text("Result \(index) for '\(query)'")
                }
            }
        }
        .navigationTitle("Search")
    }
}

// MARK: - Promo Code View

/// Promo code view.
struct PromoCodeView: View {
    let code: String
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "tag.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Promo Code Applied!")
                .font(.title)
            
            Text(code)
                .font(.system(.title, design: .monospaced))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            Text("You'll receive 20% off your next order.")
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Promo")
    }
}

// MARK: - Order Detail View

/// Order detail view.
struct OrderDetailView: View {
    let orderId: String
    
    var body: some View {
        List {
            Section("Order Info") {
                HStack {
                    Text("Order ID")
                    Spacer()
                    Text(orderId)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Status")
                    Spacer()
                    Text("Shipped")
                        .foregroundColor(.green)
                }
                HStack {
                    Text("Date")
                    Spacer()
                    Text("Jan 15, 2025")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Items") {
                ForEach(1...3, id: \.self) { index in
                    HStack {
                        Image(systemName: "square.fill")
                        Text("Item \(index)")
                        Spacer()
                        Text("$\(index * 25).00")
                    }
                }
            }
            
            Section {
                HStack {
                    Text("Total")
                        .fontWeight(.bold)
                    Spacer()
                    Text("$150.00")
                        .fontWeight(.bold)
                }
            }
        }
        .navigationTitle("Order Details")
    }
}

// MARK: - Preview

#Preview {
    DeepLinkExampleApp()
}
