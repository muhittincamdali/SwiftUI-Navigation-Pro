import SwiftUI

#if canImport(UIKit)
import UIKit

// MARK: - UIKit Navigation Bridge

/// A bridge that enables interoperability between SwiftUI navigation and UIKit.
///
/// Use this bridge to:
/// - Present UIKit view controllers from SwiftUI
/// - Embed SwiftUI views in UIKit navigation
/// - Handle mixed navigation stacks
///
/// ```swift
/// let bridge = UIKitNavigationBridge<AppRoute>()
/// bridge.present(SomeViewController(), from: navigator)
/// ```
@MainActor
public final class UIKitNavigationBridge<R: Route>: ObservableObject {
    
    // MARK: - Properties
    
    /// The root navigation controller.
    public private(set) var navigationController: UINavigationController?
    
    /// The current presenting view controller.
    public private(set) weak var presentingController: UIViewController?
    
    /// Route to view controller mapping.
    private var routeViewControllerMap: [String: () -> UIViewController] = [:]
    
    /// View controller to route mapping for back-navigation.
    private var viewControllerRouteMap: [ObjectIdentifier: R] = [:]
    
    /// Custom transition delegate.
    private var transitionDelegate: NavigationTransitionDelegate?
    
    /// Combine cancellables.
    private var observers: [NSObjectProtocol] = []
    
    // MARK: - Initialization
    
    /// Creates a UIKit navigation bridge.
    public init() {}
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
    
    // MARK: - Setup
    
    /// Attaches to a UIKit navigation controller.
    ///
    /// - Parameter navigationController: The navigation controller to bridge.
    public func attach(to navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.presentingController = navigationController
        
        setupDelegates()
        observeNavigationChanges()
    }
    
    /// Attaches to a presenting view controller.
    ///
    /// - Parameter viewController: The view controller to present from.
    public func attach(presenting viewController: UIViewController) {
        self.presentingController = viewController
    }
    
    // MARK: - Route Registration
    
    /// Registers a UIKit view controller factory for a route.
    ///
    /// - Parameters:
    ///   - route: The route to register.
    ///   - factory: A factory closure that creates the view controller.
    public func register(_ route: R, factory: @escaping () -> UIViewController) {
        routeViewControllerMap[route.path] = factory
    }
    
    /// Registers a SwiftUI view as a UIKit destination for a route.
    ///
    /// - Parameters:
    ///   - route: The route to register.
    ///   - view: The SwiftUI view to use.
    public func register<V: View>(_ route: R, view: @escaping () -> V) {
        routeViewControllerMap[route.path] = {
            UIHostingController(rootView: view())
        }
    }
    
    // MARK: - Navigation
    
    /// Pushes a route onto the UIKit navigation stack.
    ///
    /// - Parameters:
    ///   - route: The route to push.
    ///   - animated: Whether to animate the transition.
    public func push(_ route: R, animated: Bool = true) {
        guard let factory = routeViewControllerMap[route.path] else {
            assertionFailure("No view controller registered for route: \(route.path)")
            return
        }
        
        let viewController = factory()
        viewControllerRouteMap[ObjectIdentifier(viewController)] = route
        
        navigationController?.pushViewController(viewController, animated: animated)
    }
    
    /// Pushes a UIKit view controller and associates it with a route.
    ///
    /// - Parameters:
    ///   - viewController: The view controller to push.
    ///   - route: The associated route.
    ///   - animated: Whether to animate the transition.
    public func push(_ viewController: UIViewController, for route: R, animated: Bool = true) {
        viewControllerRouteMap[ObjectIdentifier(viewController)] = route
        navigationController?.pushViewController(viewController, animated: animated)
    }
    
    /// Pushes a SwiftUI view onto the UIKit navigation stack.
    ///
    /// - Parameters:
    ///   - view: The SwiftUI view to push.
    ///   - route: The associated route.
    ///   - animated: Whether to animate the transition.
    public func push<V: View>(_ view: V, for route: R, animated: Bool = true) {
        let hostingController = UIHostingController(rootView: view)
        push(hostingController, for: route, animated: animated)
    }
    
    /// Pops the top view controller from the navigation stack.
    ///
    /// - Parameter animated: Whether to animate the transition.
    /// - Returns: The popped view controller, if any.
    @discardableResult
    public func pop(animated: Bool = true) -> UIViewController? {
        navigationController?.popViewController(animated: animated)
    }
    
    /// Pops to the root of the navigation stack.
    ///
    /// - Parameter animated: Whether to animate the transition.
    /// - Returns: The popped view controllers.
    @discardableResult
    public func popToRoot(animated: Bool = true) -> [UIViewController]? {
        navigationController?.popToRootViewController(animated: animated)
    }
    
    /// Pops to a specific route in the navigation stack.
    ///
    /// - Parameters:
    ///   - route: The route to pop to.
    ///   - animated: Whether to animate the transition.
    /// - Returns: The popped view controllers, if any.
    @discardableResult
    public func popTo(_ route: R, animated: Bool = true) -> [UIViewController]? {
        guard let navController = navigationController else { return nil }
        
        let targetVC = navController.viewControllers.first { vc in
            viewControllerRouteMap[ObjectIdentifier(vc)]?.path == route.path
        }
        
        guard let target = targetVC else { return nil }
        return navController.popToViewController(target, animated: animated)
    }
    
    // MARK: - Presentation
    
    /// Presents a UIKit view controller modally.
    ///
    /// - Parameters:
    ///   - viewController: The view controller to present.
    ///   - style: The presentation style.
    ///   - animated: Whether to animate the presentation.
    ///   - completion: Completion handler.
    public func present(
        _ viewController: UIViewController,
        style: UIModalPresentationStyle = .automatic,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        viewController.modalPresentationStyle = style
        presentingController?.present(viewController, animated: animated, completion: completion)
    }
    
    /// Presents a SwiftUI view modally.
    ///
    /// - Parameters:
    ///   - view: The SwiftUI view to present.
    ///   - style: The presentation style.
    ///   - animated: Whether to animate the presentation.
    ///   - completion: Completion handler.
    public func present<V: View>(
        _ view: V,
        style: UIModalPresentationStyle = .automatic,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let hostingController = UIHostingController(rootView: view)
        present(hostingController, style: style, animated: animated, completion: completion)
    }
    
    /// Presents a route modally.
    ///
    /// - Parameters:
    ///   - route: The route to present.
    ///   - style: The presentation style.
    ///   - animated: Whether to animate the presentation.
    public func present(_ route: R, style: UIModalPresentationStyle = .automatic, animated: Bool = true) {
        guard let factory = routeViewControllerMap[route.path] else {
            assertionFailure("No view controller registered for route: \(route.path)")
            return
        }
        
        let viewController = factory()
        present(viewController, style: style, animated: animated)
    }
    
    /// Dismisses the currently presented view controller.
    ///
    /// - Parameters:
    ///   - animated: Whether to animate the dismissal.
    ///   - completion: Completion handler.
    public func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        presentingController?.dismiss(animated: animated, completion: completion)
    }
    
    // MARK: - Custom Transitions
    
    /// Sets a custom transition for navigation.
    ///
    /// - Parameter transition: The custom transition.
    public func setTransition(_ transition: NavigationTransitionDelegate) {
        self.transitionDelegate = transition
        navigationController?.delegate = transition
    }
    
    // MARK: - Private Methods
    
    private func setupDelegates() {
        // Setup navigation controller delegate if needed
    }
    
    private func observeNavigationChanges() {
        // Observe navigation changes for route tracking
    }
}

// MARK: - Navigation Transition Delegate

/// A delegate for custom navigation transitions.
public class NavigationTransitionDelegate: NSObject, UINavigationControllerDelegate {
    
    /// The custom animator for transitions.
    public var animator: UIViewControllerAnimatedTransitioning?
    
    /// The interactive transition controller.
    public var interactionController: UIPercentDrivenInteractiveTransition?
    
    /// Whether the current transition is interactive.
    public var isInteractive: Bool = false
    
    public func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        return animator
    }
    
    public func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        return isInteractive ? interactionController : nil
    }
}

// MARK: - Slide Animator

/// An animator that provides iOS-style slide transitions.
public class SlideAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    private let operation: UINavigationController.Operation
    private let duration: TimeInterval
    
    /// Creates a slide animator.
    ///
    /// - Parameters:
    ///   - operation: The navigation operation.
    ///   - duration: The animation duration.
    public init(operation: UINavigationController.Operation, duration: TimeInterval = 0.35) {
        self.operation = operation
        self.duration = duration
        super.init()
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        let width = containerView.frame.width
        
        if operation == .push {
            toView.frame.origin.x = width
            containerView.addSubview(toView)
            
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut) {
                fromView.frame.origin.x = -width * 0.3
                toView.frame.origin.x = 0
            } completion: { finished in
                fromView.frame.origin.x = 0
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        } else {
            toView.frame.origin.x = -width * 0.3
            containerView.insertSubview(toView, belowSubview: fromView)
            
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut) {
                fromView.frame.origin.x = width
                toView.frame.origin.x = 0
            } completion: { finished in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }
}

// MARK: - Fade Animator

/// An animator that provides fade transitions.
public class FadeAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
    private let duration: TimeInterval
    
    /// Creates a fade animator.
    ///
    /// - Parameter duration: The animation duration.
    public init(duration: TimeInterval = 0.35) {
        self.duration = duration
        super.init()
    }
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        
        let containerView = transitionContext.containerView
        toView.alpha = 0
        containerView.addSubview(toView)
        
        UIView.animate(withDuration: duration) {
            toView.alpha = 1
        } completion: { finished in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

// MARK: - SwiftUI Bridge View

/// A SwiftUI view that wraps a UIKit view controller.
public struct UIKitViewControllerBridge<VC: UIViewController>: UIViewControllerRepresentable {
    
    private let makeController: () -> VC
    private let updateController: ((VC) -> Void)?
    
    /// Creates a bridge view.
    ///
    /// - Parameters:
    ///   - make: A factory closure that creates the view controller.
    ///   - update: An optional update closure.
    public init(
        make: @escaping () -> VC,
        update: ((VC) -> Void)? = nil
    ) {
        self.makeController = make
        self.updateController = update
    }
    
    public func makeUIViewController(context: Context) -> VC {
        makeController()
    }
    
    public func updateUIViewController(_ uiViewController: VC, context: Context) {
        updateController?(uiViewController)
    }
}

// MARK: - UIKit View Bridge

/// A SwiftUI view that wraps a UIKit view.
public struct UIKitViewBridge<V: UIView>: UIViewRepresentable {
    
    private let makeView: () -> V
    private let updateView: ((V) -> Void)?
    
    /// Creates a bridge view.
    ///
    /// - Parameters:
    ///   - make: A factory closure that creates the view.
    ///   - update: An optional update closure.
    public init(
        make: @escaping () -> V,
        update: ((V) -> Void)? = nil
    ) {
        self.makeView = make
        self.updateView = update
    }
    
    public func makeUIView(context: Context) -> V {
        makeView()
    }
    
    public func updateUIView(_ uiView: V, context: Context) {
        updateView?(uiView)
    }
}

// MARK: - Navigation Controller Representable

/// A SwiftUI representable that wraps a UINavigationController.
public struct NavigationControllerView<Content: View>: UIViewControllerRepresentable {
    
    private let content: Content
    private let configure: ((UINavigationController) -> Void)?
    
    /// Creates a navigation controller view.
    ///
    /// - Parameters:
    ///   - configure: A closure to configure the navigation controller.
    ///   - content: The root content view.
    public init(
        configure: ((UINavigationController) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.configure = configure
        self.content = content()
    }
    
    public func makeUIViewController(context: Context) -> UINavigationController {
        let hostingController = UIHostingController(rootView: content)
        let navigationController = UINavigationController(rootViewController: hostingController)
        configure?(navigationController)
        return navigationController
    }
    
    public func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

// MARK: - View Extension

public extension View {
    /// Wraps this SwiftUI view in a UIHostingController.
    ///
    /// - Returns: A UIHostingController containing this view.
    func asHostingController() -> UIHostingController<Self> {
        UIHostingController(rootView: self)
    }
}

#endif
