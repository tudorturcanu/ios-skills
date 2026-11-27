import Foundation

var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    guard condition() else { fatalError("Failed: \(message)") }
}
func link(_ id: String) -> URL { URL(string: "https://shop.example.com/products/\(id)")! }
func ids(_ coordinator: RouteCoordinator) -> [String] { coordinator.path.map(\.productID) }

let accepted: [(String, String)] = [
    ("https://shop.example.com/products/a", "a"),
    ("HTTPS://SHOP.EXAMPLE.COM/products/Az_09-", "Az_09-"),
    ("https://shop.example.com/products/%61%5A%30%5f%2D", "aZ0_-"),
    ("https://shop.example.com/products/123?campaign=x#section", "123"),
    ("https://shop.example.com/products/a?next=/other/%2F#/%25", "a")
]
for (string, expected) in accepted {
    expect(RouteCoordinator.route(for: URL(string: string)!)?.productID == expected, "accept \(string)")
}
let rejected = [
    "http://shop.example.com/products/a", "ftp://shop.example.com/products/a",
    "https://other.example.com/products/a", "https://shop.example.com.evil.com/products/a",
    "https://sub.shop.example.com/products/a", "https://shop.example.com./products/a",
    "https://shop.example.com:443/products/a", "https://shop.example.com:8443/products/a",
    "https://shop.example.com:/products/a", "https://user@shop.example.com/products/a",
    "https://user:pass@shop.example.com/products/a", "https://@shop.example.com/products/a",
    "https://shop.example.com", "https://shop.example.com/products", "https://shop.example.com/products/",
    "https://shop.example.com/products/a/", "https://shop.example.com/products/a/b",
    "https://shop.example.com//products/a", "https://shop.example.com/products//a",
    "https://shop.example.com/Products/a", "https://shop.example.com/%70roducts/a",
    "https://shop.example.com/products/a%2Fb", "https://shop.example.com/products/a%5Cb",
    "https://shop.example.com/products/%252F", "https://shop.example.com/products/%2561",
    "https://shop.example.com/products/%25", "https://shop.example.com/products/%",
    "https://shop.example.com/products/a%20b", "https://shop.example.com/products/a+b",
    "https://shop.example.com/products/a.b", "https://shop.example.com/products/..",
    "https://shop.example.com/products/%00", "https://shop.example.com/products/%FF",
    "https://shop.example.com/products/caf%C3%A9", "https://shop.example.com/products/é",
    "https://shop.example.com/products/%3F", "https://shop.example.com/products/%23"
]
for string in rejected {
    expect(RouteCoordinator.route(for: URL(string: string)!) == nil, "reject \(string)")
}

for authenticationFirst in [false, true] {
    let c = RouteCoordinator()
    c.receive(link("old"))
    c.receive(link("latest"))
    c.receive(URL(string: "http://shop.example.com/products/invalid")!)
    expect(c.path.isEmpty, "wait while both conditions false")
    if authenticationFirst { c.setAuthenticated(true) } else { c.setReady(true) }
    expect(c.path.isEmpty, "wait for second condition")
    if authenticationFirst { c.setReady(true) } else { c.setAuthenticated(true) }
    expect(ids(c) == ["latest"], "latest valid intent consumed in either order")
    c.setReady(true)
    c.setAuthenticated(true)
    expect(ids(c) == ["latest"], "repeated callbacks do not replay")
    c.receive(URL(string: "https://SHOP.EXAMPLE.COM/products/%6Catest?track=1#x")!)
    expect(ids(c) == ["latest"], "tracking and encoding do not duplicate top")
    c.receive(link("other"))
    c.receive(link("latest"))
    expect(ids(c) == ["latest", "other", "latest"], "return to older product allowed")
    c.setReady(false)
    c.receive(link("waiting"))
    expect(ids(c) == ["latest", "other", "latest"], "temporary unreadiness queues")
    c.receive(link("last"))
    c.receive(URL(string: "https://shop.example.com/products/no/slash")!)
    c.setReady(true)
    expect(ids(c) == ["latest", "other", "latest", "last"], "temporary unreadiness retains latest valid")
    c.setReady(false)
    c.receive(link("last"))
    c.setReady(true)
    expect(c.path.count == 4, "pending duplicate top consumed without pushing")
    c.receive(link("new"))
    c.setReady(true)
    expect(ids(c).last == "new" && c.path.count == 5, "duplicate pending cannot replay after new route")
}

let cancel = RouteCoordinator()
cancel.receive(link("cancelled"))
cancel.cancelLogin()
cancel.setAuthenticated(true)
cancel.setReady(true)
expect(cancel.path.isEmpty, "cancelLogin clears pending")
cancel.receive(link("fresh"))
expect(ids(cancel) == ["fresh"], "new link after cancellation works")

let logout = RouteCoordinator()
logout.setAuthenticated(true)
logout.setReady(true)
logout.receive(link("history"))
logout.setReady(false)
logout.receive(link("old-pending"))
logout.logOut()
expect(!logout.isAuthenticated && logout.path.isEmpty, "logout clears authentication and history")
logout.setReady(true)
logout.setAuthenticated(true)
expect(logout.path.isEmpty, "logout clears pending")
logout.logOut()
logout.receive(link("next-session"))
expect(logout.path.isEmpty, "future links after logout wait for authentication")
logout.setAuthenticated(true)
expect(ids(logout) == ["next-session"], "future intent works after logout")

let authLoss = RouteCoordinator()
authLoss.setReady(true)
authLoss.setAuthenticated(true)
authLoss.setAuthenticated(false)
authLoss.receive(link("reauth"))
expect(authLoss.path.isEmpty, "authentication false gates navigation")
authLoss.setAuthenticated(true)
expect(ids(authLoss) == ["reauth"], "authentication restoration consumes pending")
print("Passed \(checks) checks")
