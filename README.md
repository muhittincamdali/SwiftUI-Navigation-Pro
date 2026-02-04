<p align="center">
  <img src="Assets/logo.png" alt="SwiftUI Navigation Pro" width="200"/>
</p>

<h1 align="center">SwiftUI Navigation Pro</h1>

<p align="center">
  <strong>🧭 Production navigation framework for SwiftUI with deep linking & state restoration</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift"/>
  <img src="https://img.shields.io/badge/iOS-17.0+-blue.svg" alt="iOS"/>
</p>

---

## Features

| Feature | Description |
|---------|-------------|
| 🎯 **Type-Safe** | Compile-time route validation |
| 🔗 **Deep Linking** | URL scheme & universal links |
| 💾 **State Restoration** | Automatic persistence |
| 📱 **Tab + Stack** | Combined navigation patterns |
| ⚡ **Async** | Async navigation support |

## Quick Start

```swift
import SwiftUINavigationPro

@main
struct MyApp: App {
    @StateObject var navigator = Navigator<AppRoute>()
    
    var body: some Scene {
        WindowGroup {
            NavigatorView(navigator: navigator) { route in
                switch route {
                case .home: HomeView()
                case .profile(let id): ProfileView(id: id)
                case .settings: SettingsView()
                }
            }
            .onOpenURL { navigator.handle($0) }
        }
    }
}
```

## Navigation

```swift
// Push
navigator.push(.profile(id: "123"))

// Pop
navigator.pop()
navigator.popToRoot()

// Present
navigator.present(.settings, style: .sheet)
navigator.present(.login, style: .fullScreen)

// Dismiss
navigator.dismiss()
```

## Deep Linking

```swift
enum AppRoute: Route {
    case home
    case profile(id: String)
    
    init?(url: URL) {
        switch url.path {
        case "/": self = .home
        case let path where path.hasPrefix("/profile/"):
            self = .profile(id: String(path.dropFirst(9)))
        default: return nil
        }
    }
}
```

## Tab Navigation

```swift
TabNavigatorView(selection: $tab) {
    Tab(.home, icon: "house") {
        NavigatorView(navigator: homeNav) { ... }
    }
    Tab(.search, icon: "magnifyingglass") {
        NavigatorView(navigator: searchNav) { ... }
    }
}
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License

---

## 📈 Star History

<a href="https://star-history.com/#muhittincamdali/SwiftUI-Navigation-Pro&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=muhittincamdali/SwiftUI-Navigation-Pro&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=muhittincamdali/SwiftUI-Navigation-Pro&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=muhittincamdali/SwiftUI-Navigation-Pro&type=Date" />
 </picture>
</a>
