<p align="center">
  <img src="https://raw.githubusercontent.com/muhittincamdali/SwiftUI-Navigation-Pro/main/Assets/logo.png" alt="SwiftUI Navigation Pro" width="180"/>
</p>

<h1 align="center">SwiftUI Navigation Pro</h1>

<p align="center">
  <strong>🧭 Enterprise-grade navigation framework for SwiftUI</strong><br>
  <em>Type-safe routing • Deep linking • State persistence • A/B testing</em>
</p>

<p align="center">
  <a href="https://github.com/muhittincamdali/SwiftUI-Navigation-Pro/actions"><img src="https://img.shields.io/badge/build-passing-brightgreen.svg" alt="Build"/></a>
  <img src="https://img.shields.io/badge/Swift-6.0-F05138.svg?logo=swift&logoColor=white" alt="Swift 6.0"/>
  <img src="https://img.shields.io/badge/iOS-17.0+-007AFF.svg?logo=apple&logoColor=white" alt="iOS 17+"/>
  <img src="https://img.shields.io/badge/macOS-14.0+-000000.svg?logo=apple&logoColor=white" alt="macOS 14+"/>
  <img src="https://img.shields.io/badge/visionOS-1.0+-5856D6.svg?logo=apple&logoColor=white" alt="visionOS 1.0+"/>
  <img src="https://img.shields.io/badge/SPM-compatible-orange.svg?logo=swift" alt="SPM"/>
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"/>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#documentation">Documentation</a> •
  <a href="#advanced">Advanced</a>
</p>

---

## Why SwiftUI Navigation Pro?

Navigation in SwiftUI is powerful but can become complex in production apps. SwiftUI Navigation Pro provides a **complete solution** that scales from simple apps to enterprise-level applications.

```
┌─────────────────────────────────────────────────────────────────┐
│                    SwiftUI Navigation Pro                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐   │
│  │  Router   │  │  Deep     │  │   Tab     │  │   Side    │   │
│  │  Stack    │──│  Links    │──│   Bar     │──│   Menu    │   │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘   │
│        │              │              │              │          │
│  ┌─────┴──────────────┴──────────────┴──────────────┴─────┐   │
│  │                    Navigator Core                        │   │
│  │  • Type-safe routing  • State persistence               │   │
│  │  • Analytics hooks    • Crash recovery                  │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Features

### Core Navigation

| Feature | Description |
|---------|-------------|
| 🎯 **Type-Safe** | Compile-time route validation with Swift generics |
| 📚 **NavigationStack** | Full iOS 16+ NavigationStack integration |
| 🔄 **Push/Pop** | Complete stack management with animations |
| 📱 **Modals** | Sheet, full-screen cover, and popover support |
| ⏪ **History** | Navigation history tracking and back navigation |

### Deep Linking

| Feature | Description |
|---------|-------------|
| 🔗 **URL Schemes** | Custom URL scheme handling |
| 🌐 **Universal Links** | HTTPS universal link support |
| 📲 **App Clips** | App Clip invocation URL parsing |
| ⌨️ **Shortcuts** | Quick Action shortcut handling |
| 🔍 **Pattern Matching** | Flexible path pattern matching |

### State Management

| Feature | Description |
|---------|-------------|
| 💾 **Persistence** | Automatic state restoration |
| 🔄 **Crash Recovery** | Resume navigation after crashes |
| 📝 **Recording** | Record and playback navigation flows |
| 📊 **Analytics** | Built-in navigation analytics |

### Advanced Features

| Feature | Description |
|---------|-------------|
| 📑 **Tab Navigation** | Multi-tab with independent stacks |
| 📋 **Side Menu** | Drawer navigation with gestures |
| 🎬 **Transitions** | Custom animations and transitions |
| 🔬 **A/B Testing** | Test different navigation flows |
| 🌉 **UIKit Bridge** | SwiftUI ↔ UIKit interoperability |
| 🎯 **Coordinators** | Flow coordinator pattern support |

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/muhittincamdali/SwiftUI-Navigation-Pro.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** → Enter repository URL.

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

### 2. Setup Navigator

```swift
import SwiftUI
import SwiftUINavigationPro

@main
struct MyApp: App {
    @StateObject private var navigator = Navigator<AppRoute>()
    
    var body: some Scene {
        WindowGroup {
            NavigatorView(navigator: navigator) { route in
                switch route {
                case .home:
                    HomeView()
                case .profile(let userId):
                    ProfileView(userId: userId)
                case .settings:
                    SettingsView()
                case .detail(let itemId):
                    DetailView(itemId: itemId)
                }
            }
            .onOpenURL { url in
                navigator.handle(url)
            }
        }
    }
}
```

### 3. Navigate!

```swift
struct HomeView: View {
    @EnvironmentObject var navigator: Navigator<AppRoute>
    
    var body: some View {
        VStack(spacing: 20) {
            Button("View Profile") {
                navigator.push(.profile(userId: "123"))
            }
            
            Button("Open Settings") {
                navigator.present(.settings, style: .sheet)
            }
        }
    }
}
```

## Documentation

### Navigation Operations

```swift
// Push (standard navigation)
navigator.push(.profile(userId: "123"))
navigator.push(.detail(itemId: 42), animated: false)

// Pop
navigator.pop()
navigator.pop(2)  // Pop 2 screens
navigator.popToRoot()
navigator.popTo(.home)

// Modal presentation
navigator.present(.settings, style: .sheet)
navigator.present(.login, style: .fullScreenCover)
navigator.presentPopover(.options)

// Dismiss
navigator.dismiss()
navigator.dismissAll()

// Replace
navigator.replace(with: .newRoute)
```

### Deep Linking

```swift
// Configure parser
var parser = DeepLinkParser<AppRoute>(
    schemes: ["myapp", "https"],
    host: "myapp.com"
) { url in
    // Custom parsing logic
    switch url.path {
    case "/": return .home
    default: return nil
    }
}

// Register patterns
parser.register("/profile/:userId") { params in
    guard let id = params["userId"] else { return nil }
    return .profile(userId: id)
}

parser.register("/item/:id") { params in
    guard let id = params["id"], let intId = Int(id) else { return nil }
    return .detail(itemId: intId)
}

// Handle in app
.onOpenURL { url in
    if let route = parser.parse(url) {
        navigator.push(route)
    }
}
```

### Tab Navigation

```swift
enum AppTab: String, TabItem, CaseIterable {
    case home, search, profile
    
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .profile: return "person.fill"
        }
    }
}

struct ContentView: View {
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

### Side Menu Navigation

```swift
@StateObject var menuCoordinator = SideMenuCoordinator<AppRoute>(
    position: .leading,
    configuration: .init(
        menuWidthRatio: 0.8,
        dimBackground: true,
        enable3DEffect: true
    )
)

var body: some View {
    SideMenuContainer(coordinator: menuCoordinator) {
        // Main content
        MainView()
    } menu: {
        // Menu content
        MenuView()
    }
}
```

### Flow Coordination

```swift
enum OnboardingStep: FlowStep {
    case welcome, profile, permissions, complete
}

@StateObject var flow = FlowCoordinator(
    configuration: .init(steps: [
        .welcome, .profile, .permissions, .complete
    ])
)

var body: some View {
    VStack {
        FlowProgressView(coordinator: flow)
        
        FlowView(coordinator: flow) { step in
            switch step {
            case .welcome: WelcomeView()
            case .profile: ProfileSetupView()
            case .permissions: PermissionsView()
            case .complete: CompleteView()
            }
        }
        
        FlowNavigationBar(coordinator: flow)
    }
}
```

## Advanced

### Crash Recovery

```swift
let recovery = CrashRecoveryManager<AppRoute>(
    policy: .conservative,
    routeFactory: { path in
        // Convert path back to route
        AppRoute(path: path)
    }
)

// On app launch
if let result = recovery.attemptRecovery() {
    switch result {
    case .success(let routes, let presented):
        for route in routes {
            navigator.push(route, animated: false)
        }
    default:
        break
    }
}

// Attach to navigator
let safeNavigator = SafeNavigator(navigator: navigator, recovery: recovery)
```

### Navigation Recording & Playback

```swift
// Record user journeys
let recorder = NavigationRecorder<AppRoute>()
recorder.startSession()

// ... user navigates ...

// Export session
let session = recorder.exportCurrentSession()
let json = recorder.exportAsJSONString()

// Playback for testing
let player = NavigationPlayer<AppRoute>(
    routeFactory: { path in AppRoute(path: path) },
    navigationHandler: { record, route in
        navigator.push(route)
    }
)
player.load(session: session)
player.play()
```

### A/B Testing Navigation Flows

```swift
let abManager = NavigationABTestingManager<AppRoute>()

// Define experiment
let experiment = FlowExperimentBuilder<AppRoute>(
    id: "checkout_flow_v2",
    name: "Simplified Checkout"
)
.control(name: "Original", flow: [.cart, .shipping, .payment, .confirm])
.treatment(id: "simplified", name: "Simplified", flow: [.cart, .payment, .confirm])
.metrics(["conversion_rate", "time_to_complete"])
.build()

abManager.registerExperiment(experiment)

// Get user's flow
if let flow = abManager.getFlow(for: "checkout_flow_v2") {
    // Navigate through flow
}

// Track conversion
abManager.trackFlowCompletion(for: "checkout_flow_v2", success: true)
```

### UIKit Bridge

```swift
let bridge = UIKitNavigationBridge<AppRoute>()

// Register UIKit view controllers
bridge.register(.legacy) {
    LegacyViewController()
}

// Register SwiftUI views for UIKit navigation
bridge.register(.modern) {
    ModernSwiftUIView()
}

// Push from SwiftUI to UIKit
bridge.push(.legacy)

// Present SwiftUI from UIKit
bridge.present(SomeSwiftUIView(), style: .pageSheet)
```

### Custom Transitions

```swift
// Use preset transitions
navigator.with(animation: .spring(response: 0.4, dampingFraction: 0.8)) {
    navigator.push(.detail)
}

// Register custom transitions
let flipTransition: AnyTransition = .flip(axis: (0, 1, 0))
navigator.registerTransition(flipTransition, for: "/special")

// Built-in transition styles
.slide           // iOS standard
.fade            // Fade in/out
.scale           // Scale up/down
.cube            // 3D cube rotation
.flip            // 3D flip
.morph           // Morphing effect
```

## Architecture

```
SwiftUINavigationPro/
├── Core/
│   ├── Navigator.swift        # Main navigation controller
│   ├── Route.swift            # Route protocol
│   ├── Router.swift           # Lightweight router
│   └── NavigationState.swift  # State management
├── DeepLink/
│   └── DeepLinkParser.swift   # URL parsing
├── Tab/
│   └── TabRouter.swift        # Tab coordination
├── SideMenu/
│   └── SideMenuCoordinator.swift
├── Coordinator/
│   ├── FlowCoordinator.swift  # Multi-step flows
│   └── TabCoordinator.swift
├── Transitions/
│   ├── CustomTransitions.swift
│   └── HeroTransition.swift
├── Bridge/
│   └── UIKitBridge.swift      # UIKit interop
├── Recording/
│   └── NavigationRecorder.swift
├── Recovery/
│   └── CrashRecovery.swift
├── ABTesting/
│   └── NavigationABTesting.swift
└── Analytics/
    └── NavigationAnalytics.swift
```

## Requirements

- iOS 17.0+ / macOS 14.0+ / visionOS 1.0+
- Swift 6.0+
- Xcode 16.0+

## Comparison

| Feature | SwiftUI Navigation Pro | pointfreeco/swiftui-navigation | FlowStacks |
|---------|:---------------------:|:-----------------------------:|:----------:|
| Type-safe routing | ✅ | ✅ | ✅ |
| Deep linking | ✅ | ✅ | ⚠️ |
| Universal links | ✅ | ❌ | ❌ |
| Tab navigation | ✅ | ⚠️ | ✅ |
| Side menu | ✅ | ❌ | ❌ |
| Crash recovery | ✅ | ❌ | ❌ |
| A/B testing | ✅ | ❌ | ❌ |
| Recording/Playback | ✅ | ❌ | ❌ |
| UIKit bridge | ✅ | ❌ | ❌ |
| Custom transitions | ✅ | ❌ | ⚠️ |
| Flow coordinators | ✅ | ✅ | ✅ |
| Zero dependencies | ✅ | ✅ | ✅ |

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) first.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

SwiftUI Navigation Pro is available under the MIT license. See [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ for the Swift community
</p>
