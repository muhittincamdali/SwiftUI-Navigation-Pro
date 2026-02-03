import SwiftUI

// MARK: - Navigation View Modifiers

public extension View {

    /// Attaches a navigation destination handler for a specific route type.
    ///
    /// - Parameters:
    ///   - routeType: The route type to handle.
    ///   - destination: A view builder that creates the destination for a route.
    /// - Returns: A view with the navigation destination attached.
    func navigationDestination<R: Route, Destination: View>(
        for routeType: R.Type,
        @ViewBuilder destination: @escaping (R) -> Destination
    ) -> some View {
        self.navigationDestination(for: routeType) { route in
            destination(route)
        }
    }

    /// Presents a sheet driven by a router's sheet state.
    ///
    /// - Parameters:
    ///   - router: The router whose sheet state drives presentation.
    ///   - content: A view builder for the sheet content.
    /// - Returns: A view that presents sheets from the router.
    func navigationSheet<R: Route, SheetContent: View>(
        router: Router<R>,
        @ViewBuilder content: @escaping (R) -> SheetContent
    ) -> some View {
        self.sheet(isPresented: Binding(
            get: { router.isSheetPresented },
            set: { if !$0 { router.dismiss() } }
        )) {
            if let route = router.presentedSheet {
                content(route)
            }
        }
    }

    /// Presents a full-screen cover driven by a router's state.
    ///
    /// - Parameters:
    ///   - router: The router whose full-screen cover state drives presentation.
    ///   - content: A view builder for the cover content.
    /// - Returns: A view that presents full-screen covers from the router.
    func navigationFullScreenCover<R: Route, CoverContent: View>(
        router: Router<R>,
        @ViewBuilder content: @escaping (R) -> CoverContent
    ) -> some View {
        #if os(iOS)
        self.fullScreenCover(isPresented: Binding(
            get: { router.isFullScreenCoverPresented },
            set: { if !$0 { router.dismiss() } }
        )) {
            if let route = router.presentedFullScreenCover {
                content(route)
            }
        }
        #else
        self.sheet(isPresented: Binding(
            get: { router.isFullScreenCoverPresented },
            set: { if !$0 { router.dismiss() } }
        )) {
            if let route = router.presentedFullScreenCover {
                content(route)
            }
        }
        #endif
    }

    /// Adds a close button that dismisses the current presentation.
    ///
    /// - Parameter router: The router to dismiss from.
    /// - Returns: A view with a toolbar close button.
    func withCloseButton<R: Route>(router: Router<R>) -> some View {
        self.toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    router.dismiss()
                }
            }
        }
    }

    /// Conditionally wraps the view in a `NavigationStack` if not already embedded.
    ///
    /// - Parameter embedded: Whether to wrap in a navigation stack.
    /// - Returns: The view optionally wrapped in a `NavigationStack`.
    @ViewBuilder
    func embeddedInNavigation(if embedded: Bool = true) -> some View {
        if embedded {
            NavigationStack {
                self
            }
        } else {
            self
        }
    }
}
