import Foundation

@main
struct Verification {
    static func main() {
        var assertions = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            assertions += 1
            guard condition() else { fatalError("Failed: \(label)") }
        }
        func url(_ value: String) -> URL {
            guard let result = URL(string: value) else { fatalError("Invalid fixture: \(value)") }
            return result
        }
        func link(_ id: String) -> URL { url("https://shop.example.com/products/\(id)") }
        let valid: [(String, String)] = [
            ("https://shop.example.com/products/a", "a"),
            ("HTTPS://SHOP.EXAMPLE.COM/products/Az_09-", "Az_09-"),
            ("https://shop.example.com/products/%41%7a%5f%30%39%2D", "Az_09-"),
            ("https://shop.example.com/products/a?campaign=x#tracking", "a"),
            ("https://shop.example.com/products/a?next=/products/b#c", "a")
        ]
        for (raw, id) in valid {
            check(RouteCoordinator.route(for: url(raw)) == ProductRoute(productID: id), raw)
        }
        let invalid = [
            "http://shop.example.com/products/a", "ftp://shop.example.com/products/a",
            "https://example.com/products/a", "https://shop.example.com.evil.com/products/a",
            "https://sub.shop.example.com/products/a", "https://shop.example.com./products/a",
            "https://shop.example.com:443/products/a", "https://shop.example.com:8443/products/a",
            "https://shop.example.com:/products/a", "https://u@shop.example.com/products/a",
            "https://u:p@shop.example.com/products/a", "https://@shop.example.com/products/a",
            "https://shop.example.com/products", "https://shop.example.com/products/",
            "https://shop.example.com/products/a/", "https://shop.example.com/products/a/b",
            "https://shop.example.com//products/a", "https://shop.example.com/Products/a",
            "https://shop.example.com/%70roducts/a", "https://shop.example.com/products/a%2Fb",
            "https://shop.example.com/products/a%5Cb", "https://shop.example.com/products/a%252Fb",
            "https://shop.example.com/products/%2541", "https://shop.example.com/products/a%20b",
            "https://shop.example.com/products/%00", "https://shop.example.com/products/%FF",
            "https://shop.example.com/products/a.b", "https://shop.example.com/products/café",
            "https://shop.example.com/products/%3F", "https://shop.example.com/products/%23",
            "https://shop.example.com/products/%", "https://shop.example.com/products/%ZZ"
        ]
        for raw in invalid { check(RouteCoordinator.route(for: url(raw)) == nil, raw) }

        for authenticateFirst in [false, true] {
            let c = RouteCoordinator()
            c.receive(link("first"))
            c.receive(link("latest"))
            c.receive(url("http://shop.example.com/products/invalid"))
            check(c.path.isEmpty, "retained while gated")
            if authenticateFirst { c.setAuthenticated(true) } else { c.setReady(true) }
            check(c.path.isEmpty, "both gates required")
            if authenticateFirst { c.setReady(true) } else { c.setAuthenticated(true) }
            check(c.path.map(\.productID) == ["latest"], "latest valid consumed in either order")
            c.setReady(true)
            c.setAuthenticated(true)
            check(c.path.count == 1, "callbacks do not replay")
            c.receive(url("https://shop.example.com/products/%6Catest?new=true#fragment"))
            check(c.path.count == 1, "canonical duplicate suppressed")
            c.receive(link("other"))
            c.receive(link("latest"))
            check(c.path.map(\.productID) == ["latest", "other", "latest"], "older destination allowed")
            c.setReady(false)
            c.receive(link("wait"))
            c.receive(link("newest"))
            check(c.path.count == 3, "readiness can suspend navigation")
            c.setReady(true)
            check(c.path.last?.productID == "newest", "readiness resumes latest")
            c.setReady(false)
            c.receive(link("cancelled"))
            c.cancelLogin()
            c.setReady(true)
            check(c.path.last?.productID == "newest", "cancel clears pending")
            c.setReady(false)
            c.receive(link("stale"))
            c.logOut()
            check(c.path.isEmpty && !c.isAuthenticated, "logout clears history and authentication")
            c.setReady(true)
            c.setAuthenticated(true)
            check(c.path.isEmpty, "logout clears pending")
            c.logOut()
            c.receive(link("fresh"))
            check(c.path.isEmpty, "post-logout waits for authentication")
            c.setAuthenticated(true)
            check(c.path.map(\.productID) == ["fresh"], "post-logout fresh intent works")
        }
        let c = RouteCoordinator()
        c.receive(link("cancelled"))
        c.cancelLogin()
        c.setAuthenticated(true)
        c.setReady(true)
        check(c.path.isEmpty, "login cancellation while logged out")
        c.setAuthenticated(false)
        c.receive(link("resume"))
        check(c.path.isEmpty, "authentication false gates navigation")
        c.setAuthenticated(true)
        check(c.path.map(\.productID) == ["resume"], "authentication transition drains pending")
        c.setReady(false)
        c.receive(link("resume"))
        c.setReady(true)
        c.receive(link("next"))
        c.setReady(true)
        c.setAuthenticated(true)
        check(c.path.map(\.productID) == ["resume", "next"], "pending duplicate consumed without later replay")
        print("Passed \(assertions) assertions")
    }
}
