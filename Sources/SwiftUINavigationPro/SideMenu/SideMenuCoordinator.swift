import SwiftUI
import Combine

// MARK: - Side Menu Position

/// The position of the side menu.
public enum SideMenuPosition: Sendable {
    /// Menu slides in from the leading edge.
    case leading
    /// Menu slides in from the trailing edge.
    case trailing
    /// Menu can be opened from either edge.
    case both
}

// MARK: - Side Menu State

/// The current state of the side menu.
public enum SideMenuState: Sendable, Equatable {
    /// Menu is closed.
    case closed
    /// Menu is opening (animating).
    case opening
    /// Menu is fully open.
    case open
    /// Menu is closing (animating).
    case closing
    /// Menu is being dragged.
    case dragging(progress: CGFloat)
    
    /// Whether the menu is visible (open or opening).
    public var isVisible: Bool {
        switch self {
        case .open, .opening, .dragging:
            return true
        case .closed, .closing:
            return false
        }
    }
}

// MARK: - Side Menu Configuration

/// Configuration for side menu behavior and appearance.
public struct SideMenuConfiguration: Sendable {
    /// The width of the menu as a fraction of screen width.
    public var menuWidthRatio: CGFloat
    /// The minimum drag distance to trigger menu open/close.
    public var dragThreshold: CGFloat
    /// The velocity threshold for gesture recognition.
    public var velocityThreshold: CGFloat
    /// Whether to dim the main content when menu is open.
    public var dimBackground: Bool
    /// The background dim opacity when menu is open.
    public var dimOpacity: CGFloat
    /// Whether to allow swipe-to-open gesture.
    public var allowSwipeOpen: Bool
    /// Whether to allow swipe-to-close gesture.
    public var allowSwipeClose: Bool
    /// Whether to close menu when tapping on dimmed area.
    public var closeOnTapOutside: Bool
    /// The animation for menu transitions.
    public var animation: Animation
    /// The edge detection width for swipe-to-open.
    public var edgeDetectionWidth: CGFloat
    /// Shadow configuration.
    public var shadowRadius: CGFloat
    /// Shadow opacity.
    public var shadowOpacity: CGFloat
    /// Whether to apply a 3D rotation effect.
    public var enable3DEffect: Bool
    /// The 3D rotation angle in degrees.
    public var rotationAngle: Double
    
    /// Creates a side menu configuration.
    public init(
        menuWidthRatio: CGFloat = 0.8,
        dragThreshold: CGFloat = 50,
        velocityThreshold: CGFloat = 500,
        dimBackground: Bool = true,
        dimOpacity: CGFloat = 0.4,
        allowSwipeOpen: Bool = true,
        allowSwipeClose: Bool = true,
        closeOnTapOutside: Bool = true,
        animation: Animation = .spring(response: 0.35, dampingFraction: 0.85),
        edgeDetectionWidth: CGFloat = 20,
        shadowRadius: CGFloat = 10,
        shadowOpacity: CGFloat = 0.3,
        enable3DEffect: Bool = false,
        rotationAngle: Double = 15
    ) {
        self.menuWidthRatio = menuWidthRatio
        self.dragThreshold = dragThreshold
        self.velocityThreshold = velocityThreshold
        self.dimBackground = dimBackground
        self.dimOpacity = dimOpacity
        self.allowSwipeOpen = allowSwipeOpen
        self.allowSwipeClose = allowSwipeClose
        self.closeOnTapOutside = closeOnTapOutside
        self.animation = animation
        self.edgeDetectionWidth = edgeDetectionWidth
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
        self.enable3DEffect = enable3DEffect
        self.rotationAngle = rotationAngle
    }
    
    /// Default configuration.
    public static let `default` = SideMenuConfiguration()
    
    /// Configuration optimized for tablets.
    public static let tablet = SideMenuConfiguration(
        menuWidthRatio: 0.35,
        enable3DEffect: true
    )
}

// MARK: - Side Menu Event

/// Events that occur during side menu interactions.
public enum SideMenuEvent: Sendable {
    /// The menu was opened.
    case opened(position: SideMenuPosition)
    /// The menu was closed.
    case closed
    /// A menu item was selected.
    case itemSelected(identifier: String)
    /// A drag gesture started.
    case dragStarted
    /// A drag gesture ended.
    case dragEnded(velocity: CGFloat)
}

// MARK: - Side Menu Coordinator

/// A coordinator that manages side menu navigation.
///
/// `SideMenuCoordinator` provides a complete solution for drawer-style
/// navigation, including gesture handling, animations, and state management.
///
/// ```swift
/// @StateObject private var menuCoordinator = SideMenuCoordinator<MenuRoute>()
///
/// var body: some View {
///     SideMenuContainer(coordinator: menuCoordinator) {
///         MainContentView()
///     } menu: {
///         MenuView()
///     }
/// }
/// ```
@MainActor
public final class SideMenuCoordinator<R: Route>: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The current menu state.
    @Published public private(set) var state: SideMenuState = .closed
    
    /// The current position being used (for `.both` mode).
    @Published public private(set) var activePosition: SideMenuPosition = .leading
    
    /// The selected menu item route.
    @Published public var selectedRoute: R?
    
    /// Whether the menu is open.
    @Published public var isOpen: Bool = false {
        didSet {
            if isOpen != oldValue {
                if isOpen {
                    open()
                } else {
                    close()
                }
            }
        }
    }
    
    /// The current drag progress (0 = closed, 1 = open).
    @Published public private(set) var dragProgress: CGFloat = 0
    
    // MARK: - Properties
    
    /// The menu configuration.
    public let configuration: SideMenuConfiguration
    
    /// The position(s) where menu can appear.
    public let position: SideMenuPosition
    
    /// Event publisher.
    private let eventSubject = PassthroughSubject<SideMenuEvent, Never>()
    
    /// Publisher for side menu events.
    public var events: AnyPublisher<SideMenuEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Gesture state tracking.
    private var gestureStartLocation: CGFloat = 0
    private var lastDragValue: CGFloat = 0
    
    // MARK: - Initialization
    
    /// Creates a side menu coordinator.
    ///
    /// - Parameters:
    ///   - position: The menu position.
    ///   - configuration: The menu configuration.
    public init(
        position: SideMenuPosition = .leading,
        configuration: SideMenuConfiguration = .default
    ) {
        self.position = position
        self.configuration = configuration
    }
    
    // MARK: - Menu Control
    
    /// Opens the side menu.
    ///
    /// - Parameter position: The position to open from (for `.both` mode).
    public func open(from position: SideMenuPosition? = nil) {
        guard state != .open else { return }
        
        if let pos = position {
            activePosition = pos
        }
        
        state = .opening
        
        withAnimation(configuration.animation) {
            state = .open
            dragProgress = 1
            isOpen = true
        }
        
        eventSubject.send(.opened(position: activePosition))
    }
    
    /// Closes the side menu.
    public func close() {
        guard state != .closed else { return }
        
        state = .closing
        
        withAnimation(configuration.animation) {
            state = .closed
            dragProgress = 0
            isOpen = false
        }
        
        eventSubject.send(.closed)
    }
    
    /// Toggles the side menu.
    public func toggle() {
        if state == .open {
            close()
        } else {
            open()
        }
    }
    
    // MARK: - Route Selection
    
    /// Selects a menu item and navigates to its route.
    ///
    /// - Parameters:
    ///   - route: The route to navigate to.
    ///   - closeMenu: Whether to close the menu after selection.
    public func select(_ route: R, closeMenu: Bool = true) {
        selectedRoute = route
        eventSubject.send(.itemSelected(identifier: route.path))
        
        if closeMenu {
            close()
        }
    }
    
    // MARK: - Gesture Handling
    
    /// Handles drag gesture changes.
    ///
    /// - Parameters:
    ///   - translation: The drag translation.
    ///   - screenWidth: The screen width for calculations.
    public func handleDrag(translation: CGFloat, screenWidth: CGFloat) {
        let menuWidth = screenWidth * configuration.menuWidthRatio
        
        let rawProgress: CGFloat
        switch activePosition {
        case .leading:
            rawProgress = state == .open
                ? 1 + (translation / menuWidth)
                : translation / menuWidth
        case .trailing:
            rawProgress = state == .open
                ? 1 - (translation / menuWidth)
                : -translation / menuWidth
        case .both:
            rawProgress = abs(translation) / menuWidth
        }
        
        let clampedProgress = max(0, min(1, rawProgress))
        
        state = .dragging(progress: clampedProgress)
        dragProgress = clampedProgress
        lastDragValue = translation
    }
    
    /// Handles drag gesture end.
    ///
    /// - Parameter velocity: The gesture velocity.
    public func handleDragEnd(velocity: CGFloat) {
        eventSubject.send(.dragEnded(velocity: velocity))
        
        let shouldOpen: Bool
        
        if abs(velocity) > configuration.velocityThreshold {
            switch activePosition {
            case .leading:
                shouldOpen = velocity > 0
            case .trailing:
                shouldOpen = velocity < 0
            case .both:
                shouldOpen = true
            }
        } else {
            shouldOpen = dragProgress > 0.5
        }
        
        if shouldOpen {
            open()
        } else {
            close()
        }
    }
    
    /// Creates a drag gesture for the menu.
    ///
    /// - Parameter screenWidth: The screen width.
    /// - Returns: A configured drag gesture.
    public func dragGesture(screenWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                self.handleDrag(translation: value.translation.width, screenWidth: screenWidth)
            }
            .onEnded { value in
                self.handleDragEnd(velocity: value.predictedEndTranslation.width)
            }
    }
}

// MARK: - Side Menu Container

/// A container view that provides side menu functionality.
public struct SideMenuContainer<R: Route, Content: View, Menu: View>: View {
    @ObservedObject private var coordinator: SideMenuCoordinator<R>
    private let content: Content
    private let menu: Menu
    
    /// Creates a side menu container.
    ///
    /// - Parameters:
    ///   - coordinator: The side menu coordinator.
    ///   - content: The main content view.
    ///   - menu: The menu view.
    public init(
        coordinator: SideMenuCoordinator<R>,
        @ViewBuilder content: () -> Content,
        @ViewBuilder menu: () -> Menu
    ) {
        self.coordinator = coordinator
        self.content = content()
        self.menu = menu()
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let menuWidth = geometry.size.width * coordinator.configuration.menuWidthRatio
            
            ZStack(alignment: menuAlignment) {
                // Main content
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(x: contentOffset(menuWidth: menuWidth))
                    .if(coordinator.configuration.enable3DEffect) { view in
                        view.rotation3DEffect(
                            .degrees(contentRotation),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                    }
                
                // Dim overlay
                if coordinator.configuration.dimBackground && coordinator.dragProgress > 0 {
                    Color.black
                        .opacity(coordinator.configuration.dimOpacity * coordinator.dragProgress)
                        .ignoresSafeArea()
                        .onTapGesture {
                            if coordinator.configuration.closeOnTapOutside {
                                coordinator.close()
                            }
                        }
                }
                
                // Menu
                menu
                    .frame(width: menuWidth)
                    .offset(x: menuOffset(menuWidth: menuWidth, screenWidth: geometry.size.width))
                    .shadow(
                        color: .black.opacity(coordinator.configuration.shadowOpacity * coordinator.dragProgress),
                        radius: coordinator.configuration.shadowRadius
                    )
            }
            .gesture(
                coordinator.configuration.allowSwipeOpen || coordinator.configuration.allowSwipeClose
                    ? coordinator.dragGesture(screenWidth: geometry.size.width)
                    : nil
            )
        }
    }
    
    private var menuAlignment: Alignment {
        switch coordinator.activePosition {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .both:
            return .leading
        }
    }
    
    private func contentOffset(menuWidth: CGFloat) -> CGFloat {
        guard coordinator.configuration.enable3DEffect == false else { return 0 }
        
        switch coordinator.activePosition {
        case .leading:
            return menuWidth * coordinator.dragProgress
        case .trailing:
            return -menuWidth * coordinator.dragProgress
        case .both:
            return menuWidth * coordinator.dragProgress
        }
    }
    
    private func menuOffset(menuWidth: CGFloat, screenWidth: CGFloat) -> CGFloat {
        switch coordinator.activePosition {
        case .leading:
            return -menuWidth * (1 - coordinator.dragProgress)
        case .trailing:
            return menuWidth * (1 - coordinator.dragProgress)
        case .both:
            return -menuWidth * (1 - coordinator.dragProgress)
        }
    }
    
    private var contentRotation: Double {
        guard coordinator.configuration.enable3DEffect else { return 0 }
        return coordinator.configuration.rotationAngle * coordinator.dragProgress
    }
}

// MARK: - Side Menu Item

/// A menu item view for use within a side menu.
public struct SideMenuItem<R: Route>: View {
    private let route: R
    private let icon: String
    private let title: String
    private let badge: String?
    private let isSelected: Bool
    private let action: () -> Void
    
    /// Creates a side menu item.
    ///
    /// - Parameters:
    ///   - route: The route this item represents.
    ///   - icon: The SF Symbol icon name.
    ///   - title: The item title.
    ///   - badge: An optional badge value.
    ///   - isSelected: Whether this item is currently selected.
    ///   - action: Action when tapped.
    public init(
        route: R,
        icon: String,
        title: String,
        badge: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.route = route
        self.icon = icon
        self.title = title
        self.badge = badge
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                
                Spacer()
                
                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Extension

private extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Environment Key

private struct SideMenuCoordinatorKey: EnvironmentKey {
    static let defaultValue: AnyObject? = nil
}

public extension EnvironmentValues {
    /// The current side menu coordinator in the environment.
    var sideMenuCoordinator: AnyObject? {
        get { self[SideMenuCoordinatorKey.self] }
        set { self[SideMenuCoordinatorKey.self] = newValue }
    }
}

public extension View {
    /// Injects a side menu coordinator into the environment.
    func sideMenuCoordinator<R: Route>(_ coordinator: SideMenuCoordinator<R>) -> some View {
        environment(\.sideMenuCoordinator, coordinator)
    }
}
