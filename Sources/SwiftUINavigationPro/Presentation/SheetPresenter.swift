import SwiftUI

/// Manages the presentation of sheets, full-screen covers, and popovers.
///
/// `SheetPresenter` can queue multiple presentations and handle dismissal
/// callbacks. Use it alongside ``Router`` for advanced modal flows.
///
/// ```swift
/// let presenter = SheetPresenter<AppRoute>()
/// presenter.present(.settings, style: .sheet) {
///     print("Settings dismissed")
/// }
/// ```
@MainActor
public final class SheetPresenter<R: Route>: ObservableObject {

    // MARK: - Types

    /// A queued presentation request.
    struct PresentationRequest {
        let route: R
        let style: PresentationStyle
        let onDismiss: (() -> Void)?
    }

    // MARK: - Published State

    /// The currently active sheet route.
    @Published public var activeSheet: R?

    /// The currently active full-screen cover route.
    @Published public var activeFullScreenCover: R?

    /// Whether a sheet is showing.
    @Published public var isShowingSheet: Bool = false

    /// Whether a full-screen cover is showing.
    @Published public var isShowingFullScreenCover: Bool = false

    // MARK: - Internal State

    /// Queue of pending presentation requests.
    private var presentationQueue: [PresentationRequest] = []

    /// The dismiss callback for the current presentation.
    private var currentDismissHandler: (() -> Void)?

    /// Whether a presentation is currently active.
    public var isPresenting: Bool {
        isShowingSheet || isShowingFullScreenCover
    }

    // MARK: - Initialization

    /// Creates a new sheet presenter.
    public init() {}

    // MARK: - Present

    /// Presents a route with the given style.
    ///
    /// If another presentation is already active, the request is queued.
    ///
    /// - Parameters:
    ///   - route: The route to present.
    ///   - style: The presentation style (`.sheet` or `.fullScreenCover`).
    ///   - onDismiss: An optional closure called when the presentation is dismissed.
    public func present(_ route: R, style: PresentationStyle, onDismiss: (() -> Void)? = nil) {
        let request = PresentationRequest(route: route, style: style, onDismiss: onDismiss)

        if isPresenting {
            presentationQueue.append(request)
            return
        }

        executePresentation(request)
    }

    // MARK: - Dismiss

    /// Dismisses the current presentation.
    ///
    /// After dismissal, the next queued presentation (if any) is shown.
    public func dismiss() {
        if isShowingSheet {
            isShowingSheet = false
            activeSheet = nil
        }

        if isShowingFullScreenCover {
            isShowingFullScreenCover = false
            activeFullScreenCover = nil
        }

        currentDismissHandler?()
        currentDismissHandler = nil

        presentNextIfNeeded()
    }

    /// Dismisses all presentations and clears the queue.
    public func dismissAll() {
        isShowingSheet = false
        isShowingFullScreenCover = false
        activeSheet = nil
        activeFullScreenCover = nil
        currentDismissHandler?()
        currentDismissHandler = nil
        presentationQueue.removeAll()
    }

    // MARK: - Queue

    /// The number of pending presentations in the queue.
    public var queueCount: Int {
        presentationQueue.count
    }

    /// Clears all pending presentations without dismissing the current one.
    public func clearQueue() {
        presentationQueue.removeAll()
    }

    // MARK: - Private

    private func executePresentation(_ request: PresentationRequest) {
        currentDismissHandler = request.onDismiss

        switch request.style {
        case .sheet:
            activeSheet = request.route
            isShowingSheet = true
        case .fullScreenCover:
            activeFullScreenCover = request.route
            isShowingFullScreenCover = true
        }
    }

    private func presentNextIfNeeded() {
        guard !presentationQueue.isEmpty else { return }
        let next = presentationQueue.removeFirst()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.executePresentation(next)
        }
    }
}
