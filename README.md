<div align="center">

# 🧭 SwiftUI-Navigation-Pro

**Production navigation framework for SwiftUI with deep linking & state restoration**

[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-16.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-Compatible-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

</div>

---

## ✨ Features

- 🧭 **Type-Safe Navigation** — Compile-time checked routes
- 🔗 **Deep Linking** — Universal & custom URL schemes
- 💾 **State Restoration** — Auto-persist navigation state
- 📱 **Tab & Stack** — Support for all navigation patterns
- 🎯 **Coordinator Pattern** — Clean separation of concerns

---

## 🚀 Quick Start

```swift
import SwiftUINavigationPro

enum AppRoute: Routable {
    case home, profile(id: String), settings
}

struct ContentView: View {
    @StateObject var navigator = Navigator<AppRoute>()
    
    var body: some View {
        RouterView(navigator: navigator) { route in
            switch route {
            case .home: HomeView()
            case .profile(let id): ProfileView(id: id)
            case .settings: SettingsView()
            }
        }
    }
}
```

---

## 📄 License

MIT • [@muhittincamdali](https://github.com/muhittincamdali)
