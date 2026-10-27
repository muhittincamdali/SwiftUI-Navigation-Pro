<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/SwiftUI-Navigation-Pro/main/.github/brand/banner-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/SwiftUI-Navigation-Pro/main/.github/brand/banner-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/SwiftUI-Navigation-Pro/main/.github/brand/banner-light.svg" alt="SwiftUI Navigation Pro, SwiftRouter'a taşındı"></picture></p>

<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a></p>

# Bu proje artık SwiftRouter içinde

SwiftUI Navigation Pro arşivlendi. Gezinme özellikleri (yığınlar, sheet'ler, guard'lar, deep
link'ler, durum geri yükleme ve sekmeler) artık
[SwiftRouter](https://github.com/muhittincamdali/SwiftRouter) içinde yaşıyor: iOS, macOS, tvOS,
watchOS ve visionOS için tip güvenli bir SwiftUI router'ı.

Kod olduğu gibi taşınmadı. Bu deponun gezinme kodu içeren son sürümü Swift 6.4 ile derlenmiyor;
bu yüzden her özellik SwiftRouter'ın `Router` yapısı üzerinde yeniden yazıldı. API farklı, bu
deponun kendi kodu ise kayıt olarak burada değişmeden duruyor.

## SwiftRouter'ı kurun

```swift
.package(url: "https://github.com/muhittincamdali/SwiftRouter.git", from: "2.0.0")
```

`SwiftRouter` ürününü hedefinize ekleyin. SwiftRouter 2.0.0 için Swift 6.2 ve iOS 17, macOS 14,
tvOS 17, watchOS 10 ya da visionOS 1 gerekir.

## Her parça nereye gitti

| SwiftUI Navigation Pro                                    | SwiftRouter                                                                                                                                                                                                                                |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Router`, `Navigator`, `NavigationPathManager`            | [`Router`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/Router.swift), bir [`RouterView`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/RouterView.swift) içinde gösterilir |
| Gezinme guard'ları                                        | [`RouteGuard`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/RouteGuard.swift)                                                                                                                              |
| `NavigationState`, `encodeState()`, `restoreState(from:)` | [`RouterSnapshot`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/RouterSnapshot.swift)                                                                                                                      |
| `TabRouter`, `TabCoordinator`                             | [`TabRouter`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/TabRouter.swift)                                                                                                                                |
| `DeepLinkParser`, `DeepLinkHandler`                       | [`DeepLinks`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/DeepLinks.swift) ve [`URLPattern`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/URLPattern.swift)               |

Bazı parçalar taşınmadı (`FlowCoordinator`, yan menü, UIKit köprüsü, A/B testi ve analitik).
Geçiş kılavuzu her birini nedeniyle ve yerine ne kullanılacağıyla birlikte listeler.

- [Geçiş kılavuzu](https://muhittincamdali.github.io/SwiftRouter/documentation/swiftrouter/migratingfromversion1) ([kaynak](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/SwiftRouter.docc/MigratingFromVersion1.md))
- [SwiftRouter kaynak kodu](https://github.com/muhittincamdali/SwiftRouter/tree/main/Sources/SwiftRouter)
- [Örnekler](https://github.com/muhittincamdali/SwiftRouter/tree/main/Examples)

## Lisans

MIT, bkz. [LICENSE](LICENSE).
