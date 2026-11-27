import Foundation

/// A destination backed by a product identifier.
struct ProductRoute: Equatable {
    let productID: String
}

/// A reference implementation for checking that the benchmark contract is feasible.
final class RouteCoordinator {
    private(set) var isAuthenticated = false
    private(set) var isReady = false
    private(set) var path: [ProductRoute] = []
    private var pendingRoute: ProductRoute?

    func receive(_ url: URL) {
        guard let route = Self.route(for: url) else { return }
        pendingRoute = route
        consumePendingRouteIfPossible()
    }

    func setReady(_ ready: Bool) {
        isReady = ready
        consumePendingRouteIfPossible()
    }

    func setAuthenticated(_ authenticated: Bool) {
        isAuthenticated = authenticated
        consumePendingRouteIfPossible()
    }

    func cancelLogin() { pendingRoute = nil }

    func logOut() {
        isAuthenticated = false
        pendingRoute = nil
        path.removeAll()
    }

    private func consumePendingRouteIfPossible() {
        guard isAuthenticated, isReady, let route = pendingRoute else { return }
        pendingRoute = nil
        if path.last != route { path.append(route) }
    }

    static func route(for url: URL) -> ProductRoute? {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "https",
              parts.host?.lowercased() == "shop.example.com",
              parts.port == nil, parts.user == nil, parts.password == nil else { return nil }
        let prefix = "/products/"
        guard parts.percentEncodedPath.hasPrefix(prefix) else { return nil }
        let encodedID = String(parts.percentEncodedPath.dropFirst(prefix.count))
        guard let id = encodedID.removingPercentEncoding, !id.isEmpty,
              id.utf8.allSatisfy({ byte in
                  (65...90).contains(byte) || (97...122).contains(byte) ||
                  (48...57).contains(byte) || byte == 95 || byte == 45
              }) else { return nil }
        return ProductRoute(productID: id)
    }
}
