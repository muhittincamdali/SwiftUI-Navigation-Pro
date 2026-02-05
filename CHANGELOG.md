# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- visionOS navigation support

## [1.1.0] - 2025-02-06

### Added
- **Side Menu Navigation** - Full drawer-style navigation with gesture support
  - `SideMenuCoordinator` for state management
  - `SideMenuContainer` view
  - Configurable animations and 3D effects
  - Swipe gestures for open/close
- **UIKit Bridge** - SwiftUI ↔ UIKit interoperability
  - `UIKitNavigationBridge` for mixed navigation
  - Custom transition animators
  - `UIKitViewControllerBridge` and `UIKitViewBridge` representables
- **Navigation Recording & Playback**
  - `NavigationRecorder` for capturing user journeys
  - `NavigationPlayer` for replaying sessions
  - Session persistence and export
  - Analytics aggregation utilities
- **Crash Recovery**
  - `CrashRecoveryManager` for state persistence
  - Configurable recovery policies
  - `SafeNavigator` wrapper for automatic state saving
- **A/B Testing Support**
  - `NavigationABTestingManager` for experiments
  - Variant assignment with weights
  - Event tracking for conversions
  - `FlowExperimentBuilder` for easy setup

### Fixed
- CHANGELOG repository links corrected

## [1.0.0] - 2024-01-15

### Added
- Type-safe navigation with compile-time checks
- SwiftUI NavigationStack integration
- Deep linking support with URL parsing
- Tab bar coordination
- Modal presentation handling
- Navigation state persistence
- Route parameters with type safety
- Navigation interceptors (guards)
- Animated transitions
- Back stack management
- Child router support (coordinator pattern)

### Features
- Zero dependencies
- Protocol-oriented design
- Full async/await support

[Unreleased]: https://github.com/muhittincamdali/SwiftUI-Navigation-Pro/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/muhittincamdali/SwiftUI-Navigation-Pro/releases/tag/v1.0.0
