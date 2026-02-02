# SwiftUI Navigation Pro

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2016%2B-blue.svg)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

A production-ready, type-safe navigation framework for SwiftUI built on top of `NavigationStack`. Provides coordinator pattern, deep linking, sheet management, and tab routing — all with zero boilerplate.

---

## Features

- **Type-safe routing** — Define routes as enums, get compile-time safety
- **NavigationStack based** — Built on the modern SwiftUI navigation API
- **Coordinator pattern** — Organize navigation flows with reusable coordinators
- **Deep linking** — Parse URLs into routes with a single line of code
- **Sheet presentation** — Manage sheets, full-screen covers, and popovers
- **Tab routing** — Coordinate navigation across tab-based interfaces
- **State persistence** — Save and restore navigation state across launches
- **Lightweight** — No external dependencies, pure SwiftUI

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 16.0+          |
| macOS    | 13.0+          |
| tvOS     | 16.0+          |
| watchOS  | 9.0+           |

## Installation

### Swift Package Manager

Add SwiftUI Navigation Pro to your project through Xcode:

1. Go to **File → Add Package Dependencies**
2. Enter the repository URL:
   ```
   https://github.com/muhittincamdali/SwiftUI-Navigation-Pro.git
   ```
3. Select **Up to Next Major Version** starting from `1.0.0`

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/SwiftUI-Navigation-Pro.git", from: "1.0.0")
]
```

## Quick Start

### 1. Define Your Routes

```swift
import SwiftUINavigationPro

enum AppRoute: Route {
    case home
    case profile(userId: String)
    case settings
    case detail(itemId: Int)

    var path: String {
        switch self {
        case .home: return "/home"
        case .profile(let id): return "/profile/\(id)"
        case .settings: return "/settings"
        case .detail(let id): return "/detail/\(id)"
        }
    }
}
```

### 2. Set Up the Router

```swift
struct ContentView: View {
    @StateObject private var router = Router<AppRoute>()

    var body: some View {
        NavigationStackView(router: router) {
            HomeView()
        }
    }
}
```

### 3. Navigate

```swift
struct HomeView: View {
    @EnvironmentObject var router: Router<AppRoute>

    var body: some View {
        VStack {
            Button("Go to Profile") {
                router.push(.profile(userId: "123"))
            }

            Button("Show Settings") {
                router.present(.settings, style: .sheet)
            }
        }
    }
}
```

## Deep Linking

Parse incoming URLs into strongly-typed routes:

```swift
let parser = DeepLinkParser<AppRoute> { url in
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return nil
    }
    switch components.path {
    case "/home":
        return .home
    case let path where path.hasPrefix("/profile/"):
        let userId = String(path.dropFirst("/profile/".count))
        return .profile(userId: userId)
    default:
        return nil
    }
}

// In your App struct
router.handleDeepLink(url, parser: parser)
```

## Coordinator Pattern

Organize complex flows using coordinators:

```swift
class OnboardingCoordinator: Coordinator<AppRoute> {
    override func start() {
        push(.welcome)
    }

    func showNextStep() {
        push(.profile(userId: "new"))
    }

    func finish() {
        parentRouter?.popToRoot()
    }
}
```

Display coordinators with the dedicated view:

```swift
CoordinatorView(coordinator: OnboardingCoordinator()) { route in
    switch route {
    case .home:
        HomeView()
    case .profile(let id):
        ProfileView(userId: id)
    default:
        EmptyView()
    }
}
```

## Tab Routing

Manage navigation across multiple tabs:

```swift
enum AppTab: String, TabItem {
    case home, search, profile

    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .profile: return "person"
        }
    }
}

struct MainTabView: View {
    @StateObject var tabRouter = TabRouter<AppTab, AppRoute>()

    var body: some View {
        TabRouterView(router: tabRouter) { tab in
            switch tab {
            case .home: HomeView()
            case .search: SearchView()
            case .profile: ProfileView()
            }
        }
    }
}
```

## Sheet Presentation

Present sheets, full-screen covers and popovers with type safety:

```swift
// Present a sheet
router.present(.settings, style: .sheet)

// Full screen cover
router.present(.onboarding, style: .fullScreenCover)

// Dismiss
router.dismiss()
```

## View Extensions

Convenient modifiers for common navigation patterns:

```swift
Text("Hello")
    .onNavigation(.profile(userId: "123")) { route in
        ProfileView(userId: route.userId)
    }
    .navigationSheet(router: router) { route in
        SettingsView()
    }
```

## Architecture

```
SwiftUINavigationPro/
├── Core/
│   ├── Router.swift              # Main navigation router
│   ├── Route.swift               # Route protocol definition
│   └── NavigationState.swift     # State management
├── DeepLink/
│   └── DeepLinkParser.swift      # URL to route parsing
├── Coordinator/
│   ├── Coordinator.swift         # Base coordinator class
│   └── CoordinatorView.swift     # SwiftUI coordinator wrapper
├── Presentation/
│   └── SheetPresenter.swift      # Sheet/cover management
├── Tab/
│   └── TabRouter.swift           # Tab-based navigation
└── Extensions/
    └── View+Navigation.swift     # View modifier helpers
```

## Advanced Usage

### State Persistence

Save navigation state and restore it on next launch:

```swift
// Save
let data = try router.encodeState()
UserDefaults.standard.set(data, forKey: "nav_state")

// Restore
if let data = UserDefaults.standard.data(forKey: "nav_state") {
    try router.restoreState(from: data)
}
```

### Custom Transitions

Apply custom animations to navigation transitions:

```swift
router.push(.detail(itemId: 42), animation: .spring(duration: 0.4))
router.pop(animation: .easeInOut)
```

## Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Author

**Muhittin Camdali** — [@muhittincamdali](https://github.com/muhittincamdali)
