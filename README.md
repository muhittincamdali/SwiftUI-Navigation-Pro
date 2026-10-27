<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/SwiftUI-Navigation-Pro/main/.github/brand/banner-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/SwiftUI-Navigation-Pro/main/.github/brand/banner-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/SwiftUI-Navigation-Pro/main/.github/brand/banner-light.svg" alt="SwiftUI Navigation Pro has moved to SwiftRouter"></picture></p>

<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a></p>

# This project now lives in SwiftRouter

SwiftUI Navigation Pro is archived. Its navigation features (stacks, sheets, guards, deep links,
state restoration and tabs) now live in
[SwiftRouter](https://github.com/muhittincamdali/SwiftRouter), a typed router for SwiftUI on iOS,
macOS, tvOS, watchOS and visionOS.

The code was not copied over. The last version of this repository with navigation code does not build with
Swift 6.4, so each feature was written again on top of SwiftRouter's `Router`. The API is
different, and this repository's own code stays here, unchanged, as a record.

## Install SwiftRouter

```swift
.package(url: "https://github.com/muhittincamdali/SwiftRouter.git", from: "2.0.0")
```

Add the `SwiftRouter` product to your target. SwiftRouter 2.0.0 needs Swift 6.2, iOS 17,
macOS 14, tvOS 17, watchOS 10 or visionOS 1.

## Where each part went

| SwiftUI Navigation Pro                                    | SwiftRouter                                                                                                                                                                                                                    |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Router`, `Navigator`, `NavigationPathManager`            | [`Router`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/Router.swift) shown by a [`RouterView`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/RouterView.swift) |
| Navigation guards                                         | [`RouteGuard`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/RouteGuard.swift)                                                                                                                  |
| `NavigationState`, `encodeState()`, `restoreState(from:)` | [`RouterSnapshot`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/RouterSnapshot.swift)                                                                                                          |
| `TabRouter`, `TabCoordinator`                             | [`TabRouter`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/TabRouter.swift)                                                                                                                    |
| `DeepLinkParser`, `DeepLinkHandler`                       | [`DeepLinks`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/DeepLinks.swift) and [`URLPattern`](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/URLPattern.swift)  |

Some parts were not carried over (`FlowCoordinator`, the side menu, the UIKit bridge, A/B testing
and analytics). The migration guide lists each one with the reason and what to use instead.

- [Migration guide](https://muhittincamdali.github.io/SwiftRouter/documentation/swiftrouter/migratingfromversion1) ([source](https://github.com/muhittincamdali/SwiftRouter/blob/main/Sources/SwiftRouter/SwiftRouter.docc/MigratingFromVersion1.md))
- [SwiftRouter source](https://github.com/muhittincamdali/SwiftRouter/tree/main/Sources/SwiftRouter)
- [Examples](https://github.com/muhittincamdali/SwiftRouter/tree/main/Examples)

## License

MIT, see [LICENSE](LICENSE).
