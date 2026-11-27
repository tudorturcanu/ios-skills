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
        pendingRoute = route
        consumePendingRouteIfPossible()
    }

    /// Records whether the authenticated root interface can navigate.
    func setReady(_ ready: Bool) {
        isReady = ready
        consumePendingRouteIfPossible()
    }

    /// Records a completed authentication transition.
    func setAuthenticated(_ authenticated: Bool) {
        isAuthenticated = authenticated
        consumePendingRouteIfPossible()
    }

    /// Cancels the login flow and its outstanding navigation intent.
    func cancelLogin() {
        pendingRoute = nil
    }

    /// Ends the current account session and removes its navigation state.
    func logOut() {
        isAuthenticated = false
        pendingRoute = nil
        path.removeAll()
    }

    private func consumePendingRouteIfPossible() {
        guard isAuthenticated, isReady, let route = pendingRoute else { return }
        pendingRoute = nil
        guard path.last != route else { return }
        path.append(route)
    }

    /// Parses a product route from a supported URL.
    static func route(for url: URL) -> ProductRoute? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.scheme?.lowercased() == "https",
              components.percentEncodedHost?.lowercased() == "shop.example.com",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              let serialized = components.string,
              let hostRange = components.rangeOfHost else { return nil }

        // Foundation represents an explicitly empty port as nil, too.
        guard !serialized[hostRange.upperBound...].hasPrefix(":") else { return nil }

        // Split before decoding so encoded separators cannot alter the path shape.
        let segments = components.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.count == 3,
              segments[0].isEmpty,
              segments[1] == "products",
              let productID = String(segments[2]).removingPercentEncoding,
              !productID.isEmpty,
              productID.utf8.allSatisfy({ byte in
                  (65...90).contains(byte) || (97...122).contains(byte)
                      || (48...57).contains(byte) || byte == 95 || byte == 45
              }) else { return nil }
        return ProductRoute(productID: productID)
    }
}
