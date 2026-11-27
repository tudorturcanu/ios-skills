import Foundation

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    guard condition() else { fatalError("FAILED: \(message)") }
}
func url(_ value: String) -> URL { URL(string: value)! }
func product(_ id: String) -> URL { url("https://shop.example.com/products/\(id)") }
func ids(_ coordinator: RouteCoordinator) -> [String] { coordinator.path.map(\.productID) }

let accepted: [(String, String)] = [
    ("https://shop.example.com/products/a", "a"),
    ("HTTPS://SHOP.EXAMPLE.COM/products/Az09_-", "Az09_-"),
    ("https://shop.example.com/products/%41%7a%30%39%5f%2D", "Az09_-"),
    ("https://shop.example.com/products/a?x=1&x=2#fragment", "a"),
    ("https://shop.example.com/products/a?product=b#products/c", "a")
]
for (input, expected) in accepted {
    expect(RouteCoordinator.route(for: url(input))?.productID == expected, "accept \(input)")
}
let rejected = [
    "http://shop.example.com/products/a", "ftp://shop.example.com/products/a",
    "https://evil.example.com/products/a", "https://shop.example.com.evil/products/a",
    "https://sub.shop.example.com/products/a", "https://shop.example.com./products/a",
    "https://shop.example.com:443/products/a", "https://shop.example.com:80/products/a",
    "https://shop.example.com:/products/a", "https://user@shop.example.com/products/a",
    "https://user:pass@shop.example.com/products/a", "https://@shop.example.com/products/a",
    "https://shop.example.com", "https://shop.example.com/products",
    "https://shop.example.com/products/", "https://shop.example.com/products/a/",
    "https://shop.example.com/products/a/b", "https://shop.example.com//products/a",
    "https://shop.example.com/products//a", "https://shop.example.com/Products/a",
    "https://shop.example.com/%70roducts/a", "https://shop.example.com/products/a%2Fb",
    "https://shop.example.com/products/a%5Cb", "https://shop.example.com/products/%2541",
    "https://shop.example.com/products/%252F", "https://shop.example.com/products/a%20b",
    "https://shop.example.com/products/%00", "https://shop.example.com/products/%FF",
    "https://shop.example.com/products/%", "https://shop.example.com/products/%GG",
    "https://shop.example.com/products/%C3%A9", "https://shop.example.com/products/a.b",
    "https://shop.example.com/products/%3F", "https://shop.example.com/products/%23",
    "https://shop.example.com/products/a+b", "/products/a"
]
for input in rejected {
    expect(RouteCoordinator.route(for: url(input)) == nil, "reject \(input)")
}

for authenticationFirst in [true, false] {
    let c = RouteCoordinator()
    c.receive(product("first"))
    c.receive(product("latest"))
    c.receive(url("https://evil.example.com/products/invalid"))
    expect(c.path.isEmpty, "hold intent initially")
    if authenticationFirst { c.setAuthenticated(true) } else { c.setReady(true) }
    expect(c.path.isEmpty, "hold intent after one prerequisite")
    if authenticationFirst { c.setReady(true) } else { c.setAuthenticated(true) }
    expect(ids(c) == ["latest"], "latest valid wins in both prerequisite orders")
    c.setReady(true)
    c.setAuthenticated(true)
    expect(ids(c) == ["latest"], "callbacks do not replay")
    c.receive(url("https://shop.example.com/products/%6Catest?x=1&x=2#tracking"))
    expect(ids(c) == ["latest"], "same route with encoding and tracking deduplicates")
    c.receive(product("other"))
    c.receive(product("latest"))
    expect(ids(c) == ["latest", "other", "latest"], "older product can be revisited")
    c.setReady(false)
    c.receive(product("waiting"))
    c.receive(product("newest"))
    c.receive(url("http://shop.example.com/products/invalid"))
    expect(ids(c) == ["latest", "other", "latest"], "readiness loss pauses navigation")
    c.setReady(true)
    expect(ids(c) == ["latest", "other", "latest", "newest"], "readiness recovery consumes latest")
    c.setReady(false)
    c.receive(product("newest"))
    c.setReady(true)
    c.receive(product("different"))
    c.setReady(true)
    expect(ids(c) == ["latest", "other", "latest", "newest", "different"], "pending top duplicate is consumed")
    c.setAuthenticated(false)
    c.receive(product("reauthenticated"))
    expect(c.path.count == 5, "expired session holds route")
    c.setAuthenticated(true)
    expect(ids(c).last == "reauthenticated", "reauthentication consumes pending route")
}

let cancelled = RouteCoordinator()
cancelled.receive(product("cancelled"))
cancelled.cancelLogin()
cancelled.setReady(true)
cancelled.setAuthenticated(true)
expect(cancelled.path.isEmpty, "cancelled login clears pending intent")
cancelled.receive(product("fresh"))
expect(ids(cancelled) == ["fresh"], "fresh route after cancellation works")

let logout = RouteCoordinator()
logout.setReady(true)
logout.setAuthenticated(true)
logout.receive(product("old"))
logout.setReady(false)
logout.receive(product("pending"))
logout.logOut()
expect(!logout.isAuthenticated && logout.path.isEmpty, "logout clears authentication and history")
logout.setReady(true)
logout.setAuthenticated(true)
expect(logout.path.isEmpty, "logout clears pending route")
logout.logOut()
logout.receive(product("new-account"))
expect(logout.path.isEmpty, "post-logout route waits for authentication")
logout.setAuthenticated(true)
expect(ids(logout) == ["new-account"], "post-logout new intent survives")

print("Passed \(checks) checks")
