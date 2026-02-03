import SwiftUI

// MARK: - Transition Direction

/// The direction of a navigation transition.
public enum TransitionDirection: Sendable {
    case leading
    case trailing
    case top
    case bottom
    case center
    
    /// The edge corresponding to this direction.
    public var edge: Edge {
        switch self {
        case .leading: return .leading
        case .trailing: return .trailing
        case .top: return .top
        case .bottom: return .bottom
        case .center: return .leading
        }
    }
    
    /// The opposite direction.
    public var opposite: TransitionDirection {
        switch self {
        case .leading: return .trailing
        case .trailing: return .leading
        case .top: return .bottom
        case .bottom: return .top
        case .center: return .center
        }
    }
}

// MARK: - Transition Style

/// Predefined transition styles for navigation.
public enum TransitionStyle: Sendable {
    /// Standard iOS push/pop transition.
    case slide
    /// Fade in/out transition.
    case fade
    /// Scale up/down transition.
    case scale
    /// Combined slide and fade.
    case slideAndFade
    /// Combined scale and fade.
    case scaleAndFade
    /// Flip transition.
    case flip
    /// Cube rotation transition.
    case cube
    /// Zoom in/out transition.
    case zoom
    /// Slide over without removing previous view.
    case slideOver
    /// Reveal transition (new view slides to reveal previous).
    case reveal
    /// Morph transition.
    case morph
    /// Custom transition.
    case custom(AnyTransition)
    
    /// The insertion transition.
    public var insertion: AnyTransition {
        switch self {
        case .slide:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        case .fade:
            return .opacity
        case .scale:
            return .scale(scale: 0.8).combined(with: .opacity)
        case .slideAndFade:
            return .move(edge: .trailing).combined(with: .opacity)
        case .scaleAndFade:
            return .scale(scale: 0.9).combined(with: .opacity)
        case .flip:
            return .asymmetric(
                insertion: .modifier(
                    active: FlipModifier(angle: -90, axis: (x: 0, y: 1, z: 0)),
                    identity: FlipModifier(angle: 0, axis: (x: 0, y: 1, z: 0))
                ),
                removal: .modifier(
                    active: FlipModifier(angle: 90, axis: (x: 0, y: 1, z: 0)),
                    identity: FlipModifier(angle: 0, axis: (x: 0, y: 1, z: 0))
                )
            )
        case .cube:
            return .asymmetric(
                insertion: .modifier(
                    active: CubeModifier(rotation: -90, direction: .trailing),
                    identity: CubeModifier(rotation: 0, direction: .trailing)
                ),
                removal: .modifier(
                    active: CubeModifier(rotation: 90, direction: .leading),
                    identity: CubeModifier(rotation: 0, direction: .leading)
                )
            )
        case .zoom:
            return .scale(scale: 0.1).combined(with: .opacity)
        case .slideOver:
            return .move(edge: .trailing)
        case .reveal:
            return .asymmetric(
                insertion: .identity,
                removal: .move(edge: .trailing)
            )
        case .morph:
            return .modifier(
                active: MorphModifier(progress: 0),
                identity: MorphModifier(progress: 1)
            )
        case .custom(let transition):
            return transition
        }
    }
    
    /// The removal transition.
    public var removal: AnyTransition {
        switch self {
        case .slide:
            return .move(edge: .leading)
        case .fade:
            return .opacity
        case .scale:
            return .scale(scale: 1.1).combined(with: .opacity)
        case .slideAndFade:
            return .move(edge: .leading).combined(with: .opacity)
        case .scaleAndFade:
            return .scale(scale: 1.05).combined(with: .opacity)
        case .flip, .cube, .zoom, .slideOver, .reveal, .morph:
            return insertion
        case .custom(let transition):
            return transition
        }
    }
}

// MARK: - Flip Modifier

/// A modifier that applies a 3D flip effect.
public struct FlipModifier: ViewModifier {
    let angle: Double
    let axis: (x: CGFloat, y: CGFloat, z: CGFloat)
    
    public init(angle: Double, axis: (x: CGFloat, y: CGFloat, z: CGFloat)) {
        self.angle = angle
        self.axis = axis
    }
    
    public func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(angle),
                axis: axis,
                perspective: 0.5
            )
            .opacity(abs(angle) > 89 ? 0 : 1)
    }
}

// MARK: - Cube Modifier

/// A modifier that applies a 3D cube rotation effect.
public struct CubeModifier: ViewModifier {
    let rotation: Double
    let direction: TransitionDirection
    
    public init(rotation: Double, direction: TransitionDirection) {
        self.rotation = rotation
        self.direction = direction
    }
    
    public func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .rotation3DEffect(
                    .degrees(rotation),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: direction == .trailing ? .leading : .trailing,
                    perspective: 0.5
                )
                .offset(x: offsetX(geometry: geometry))
        }
    }
    
    private func offsetX(geometry: GeometryProxy) -> CGFloat {
        let progress = rotation / 90.0
        switch direction {
        case .trailing:
            return geometry.size.width * CGFloat(progress)
        case .leading:
            return -geometry.size.width * CGFloat(progress)
        default:
            return 0
        }
    }
}

// MARK: - Morph Modifier

/// A modifier that applies a morphing effect.
public struct MorphModifier: ViewModifier {
    let progress: CGFloat
    
    public init(progress: CGFloat) {
        self.progress = progress
    }
    
    public func body(content: Content) -> some View {
        content
            .scaleEffect(0.8 + (0.2 * progress))
            .opacity(Double(progress))
            .blur(radius: (1 - progress) * 10)
    }
}

// MARK: - Slide Transition Modifier

/// A modifier for custom slide transitions.
public struct SlideTransitionModifier: ViewModifier {
    let offset: CGSize
    let opacity: Double
    
    public init(offset: CGSize, opacity: Double = 1.0) {
        self.offset = offset
        self.opacity = opacity
    }
    
    public func body(content: Content) -> some View {
        content
            .offset(offset)
            .opacity(opacity)
    }
}

// MARK: - Scale Transition Modifier

/// A modifier for custom scale transitions.
public struct ScaleTransitionModifier: ViewModifier {
    let scale: CGFloat
    let anchor: UnitPoint
    let opacity: Double
    
    public init(scale: CGFloat, anchor: UnitPoint = .center, opacity: Double = 1.0) {
        self.scale = scale
        self.anchor = anchor
        self.opacity = opacity
    }
    
    public func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: anchor)
            .opacity(opacity)
    }
}

// MARK: - Blur Transition Modifier

/// A modifier for transitions with blur effect.
public struct BlurTransitionModifier: ViewModifier {
    let radius: CGFloat
    let opacity: Double
    
    public init(radius: CGFloat, opacity: Double = 1.0) {
        self.radius = radius
        self.opacity = opacity
    }
    
    public func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .opacity(opacity)
    }
}

// MARK: - Rotation Transition Modifier

/// A modifier for rotation transitions.
public struct RotationTransitionModifier: ViewModifier {
    let angle: Angle
    let anchor: UnitPoint
    let opacity: Double
    
    public init(angle: Angle, anchor: UnitPoint = .center, opacity: Double = 1.0) {
        self.angle = angle
        self.anchor = anchor
        self.opacity = opacity
    }
    
    public func body(content: Content) -> some View {
        content
            .rotationEffect(angle, anchor: anchor)
            .opacity(opacity)
    }
}

// MARK: - Skew Transition Modifier

/// A modifier for skew transitions.
public struct SkewTransitionModifier: ViewModifier {
    let angle: Angle
    let axis: (x: CGFloat, y: CGFloat)
    let opacity: Double
    
    public init(angle: Angle, axis: (x: CGFloat, y: CGFloat) = (1, 0), opacity: Double = 1.0) {
        self.angle = angle
        self.axis = axis
        self.opacity = opacity
    }
    
    public func body(content: Content) -> some View {
        content
            .transformEffect(
                CGAffineTransform(a: 1, b: tan(angle.radians) * axis.y,
                                  c: tan(angle.radians) * axis.x, d: 1,
                                  tx: 0, ty: 0)
            )
            .opacity(opacity)
    }
}

// MARK: - Navigation Transition

/// A custom navigation transition configuration.
public struct NavigationTransition: Sendable {
    /// The transition for pushing views.
    public let push: AnyTransition
    /// The transition for popping views.
    public let pop: AnyTransition
    /// The animation for the transition.
    public let animation: Animation
    /// Whether to use interactive gesture.
    public let isInteractive: Bool
    
    /// Creates a navigation transition.
    public init(
        push: AnyTransition,
        pop: AnyTransition,
        animation: Animation = .easeInOut(duration: 0.35),
        isInteractive: Bool = true
    ) {
        self.push = push
        self.pop = pop
        self.animation = animation
        self.isInteractive = isInteractive
    }
    
    /// Creates a symmetric navigation transition.
    public init(
        style: TransitionStyle,
        animation: Animation = .easeInOut(duration: 0.35),
        isInteractive: Bool = true
    ) {
        self.push = style.insertion
        self.pop = style.removal
        self.animation = animation
        self.isInteractive = isInteractive
    }
    
    // MARK: - Preset Transitions
    
    /// The default iOS-style transition.
    public static let `default` = NavigationTransition(style: .slide)
    
    /// A fade transition.
    public static let fade = NavigationTransition(style: .fade)
    
    /// A scale transition.
    public static let scale = NavigationTransition(style: .scale)
    
    /// A flip transition.
    public static let flip = NavigationTransition(
        style: .flip,
        animation: .easeInOut(duration: 0.5)
    )
    
    /// A cube transition.
    public static let cube = NavigationTransition(
        style: .cube,
        animation: .easeInOut(duration: 0.5)
    )
    
    /// A zoom transition.
    public static let zoom = NavigationTransition(style: .zoom)
    
    /// No transition.
    public static let none = NavigationTransition(
        push: .identity,
        pop: .identity,
        animation: .linear(duration: 0)
    )
}

// MARK: - AnyTransition Extensions

public extension AnyTransition {
    
    /// A transition that slides from the specified direction.
    ///
    /// - Parameter direction: The direction to slide from.
    /// - Returns: A slide transition.
    static func slide(from direction: TransitionDirection) -> AnyTransition {
        .move(edge: direction.edge)
    }
    
    /// A transition that scales with the specified parameters.
    ///
    /// - Parameters:
    ///   - scale: The scale factor.
    ///   - anchor: The anchor point for scaling.
    /// - Returns: A scale transition.
    static func scale(_ scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition {
        .modifier(
            active: ScaleTransitionModifier(scale: scale, anchor: anchor, opacity: 0),
            identity: ScaleTransitionModifier(scale: 1, anchor: anchor, opacity: 1)
        )
    }
    
    /// A transition that blurs with the specified radius.
    ///
    /// - Parameter radius: The blur radius.
    /// - Returns: A blur transition.
    static func blur(radius: CGFloat) -> AnyTransition {
        .modifier(
            active: BlurTransitionModifier(radius: radius, opacity: 0),
            identity: BlurTransitionModifier(radius: 0, opacity: 1)
        )
    }
    
    /// A transition that rotates with the specified angle.
    ///
    /// - Parameters:
    ///   - angle: The rotation angle.
    ///   - anchor: The anchor point for rotation.
    /// - Returns: A rotation transition.
    static func rotate(_ angle: Angle, anchor: UnitPoint = .center) -> AnyTransition {
        .modifier(
            active: RotationTransitionModifier(angle: angle, anchor: anchor, opacity: 0),
            identity: RotationTransitionModifier(angle: .zero, anchor: anchor, opacity: 1)
        )
    }
    
    /// A transition that skews with the specified angle.
    ///
    /// - Parameters:
    ///   - angle: The skew angle.
    ///   - axis: The skew axis.
    /// - Returns: A skew transition.
    static func skew(_ angle: Angle, axis: (x: CGFloat, y: CGFloat) = (1, 0)) -> AnyTransition {
        .modifier(
            active: SkewTransitionModifier(angle: angle, axis: axis, opacity: 0),
            identity: SkewTransitionModifier(angle: .zero, axis: axis, opacity: 1)
        )
    }
    
    /// A combined slide and fade transition.
    ///
    /// - Parameter direction: The slide direction.
    /// - Returns: A combined transition.
    static func slideAndFade(from direction: TransitionDirection) -> AnyTransition {
        .move(edge: direction.edge).combined(with: .opacity)
    }
    
    /// A combined scale and fade transition.
    ///
    /// - Parameters:
    ///   - scale: The scale factor.
    ///   - anchor: The anchor point.
    /// - Returns: A combined transition.
    static func scaleAndFade(_ scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition {
        .scale(scale, anchor: anchor).combined(with: .opacity)
    }
    
    /// A flip transition along the specified axis.
    ///
    /// - Parameter axis: The flip axis.
    /// - Returns: A flip transition.
    static func flip(axis: (x: CGFloat, y: CGFloat, z: CGFloat) = (0, 1, 0)) -> AnyTransition {
        .modifier(
            active: FlipModifier(angle: 90, axis: axis),
            identity: FlipModifier(angle: 0, axis: axis)
        )
    }
    
    /// A 3D cube rotation transition.
    ///
    /// - Parameter direction: The rotation direction.
    /// - Returns: A cube transition.
    static func cube(direction: TransitionDirection = .trailing) -> AnyTransition {
        .modifier(
            active: CubeModifier(rotation: 90, direction: direction),
            identity: CubeModifier(rotation: 0, direction: direction)
        )
    }
    
    /// A morph transition.
    ///
    /// - Returns: A morph transition.
    static var morph: AnyTransition {
        .modifier(
            active: MorphModifier(progress: 0),
            identity: MorphModifier(progress: 1)
        )
    }
}

// MARK: - Transition Container View

/// A view that applies a custom transition to its content.
public struct TransitionContainer<Content: View>: View {
    let content: Content
    let transition: AnyTransition
    let animation: Animation
    @Binding var isPresented: Bool
    
    /// Creates a transition container.
    ///
    /// - Parameters:
    ///   - transition: The transition to apply.
    ///   - animation: The animation to use.
    ///   - isPresented: Binding to control presentation.
    ///   - content: The content to transition.
    public init(
        transition: AnyTransition,
        animation: Animation = .easeInOut(duration: 0.35),
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.transition = transition
        self.animation = animation
        self._isPresented = isPresented
        self.content = content()
    }
    
    public var body: some View {
        if isPresented {
            content
                .transition(transition)
                .animation(animation, value: isPresented)
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Applies a custom navigation transition to this view.
    ///
    /// - Parameters:
    ///   - transition: The navigation transition.
    ///   - isActive: Whether the transition is active.
    /// - Returns: A view with the transition applied.
    func navigationTransition(_ transition: NavigationTransition, isActive: Bool = true) -> some View {
        self
            .transition(isActive ? transition.push : .identity)
            .animation(transition.animation, value: isActive)
    }
    
    /// Applies a transition style to this view.
    ///
    /// - Parameters:
    ///   - style: The transition style.
    ///   - isActive: Whether the transition is active.
    /// - Returns: A view with the transition applied.
    func transitionStyle(_ style: TransitionStyle, isActive: Bool = true) -> some View {
        self
            .transition(isActive ? style.insertion : .identity)
    }
}
