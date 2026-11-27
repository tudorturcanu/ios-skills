import Foundation

/// A destination backed by a product identifier.
struct ProductRoute: Equatable {
    let productID: String
}

/// Coordinates link delivery with authentication and navigation readiness.
final class RouteCoordinator {
    private(set) var isAuthenticated = false
    private(set) var isReady = false
    private(set) var path: [ProductRoute] = []
    private var pendingRoute: ProductRoute?

    /// Receives a URL from an already-delivered application event.
    func receive(_ url: URL) {
        guard let route = Self.route(for: url) else { return }
        guard isAuthenticated else { return }
        path.append(route)
    }

    /// Records whether the authenticated root interface can navigate.
    func setReady(_ ready: Bool) {
        isReady = ready
    }

    /// Records a completed authentication transition.
    func setAuthenticated(_ authenticated: Bool) {
        isAuthenticated = authenticated
    }

    /// Cancels the login flow and its outstanding navigation intent.
    func cancelLogin() {
        pendingRoute = nil
    }

    /// Ends the current account session and removes its navigation state.
    func logOut() {
        isAuthenticated = false
    }

    /// Parses a product route from a supported URL.
    static func route(for url: URL) -> ProductRoute? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, parts[0] == "products" else { return nil }
        return ProductRoute(productID: parts[1])
    }
}
