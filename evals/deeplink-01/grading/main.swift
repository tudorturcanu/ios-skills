import Foundation

var outcomes: [[String: Any]] = []
func check(_ name: String, _ condition: Bool) {
    outcomes.append(["name": name, "passed": condition])
}
func url(_ value: String) -> URL { URL(string: value)! }
func link(_ id: String) -> URL { url("https://shop.example.com/products/\(id)") }
func ids(_ c: RouteCoordinator) -> [String] { c.path.map(\.productID) }
func active() -> RouteCoordinator {
    let c = RouteCoordinator(); c.setAuthenticated(true); c.setReady(true); return c
}

for raw in ["https://shop.example.com/products/A_b-12", "HTTPS://SHOP.EXAMPLE.COM/products/A_b-12", "https://shop.example.com/products/%41_b-12", "https://shop.example.com/products/A_b-12?utm=x#campaign"] {
    check("accept " + raw, RouteCoordinator.route(for: url(raw))?.productID == "A_b-12")
}
for raw in ["http://shop.example.com/products/x", "https://evil.example/products/x", "https://shop.example.com.evil/products/x", "https://user@shop.example.com/products/x", "https://shop.example.com:443/products/x", "https://shop.example.com/products/", "https://shop.example.com/products/x/", "https://shop.example.com/products/x/extra", "https://shop.example.com/products/a%2Fb", "https://shop.example.com/products/a%252Fb", "https://shop.example.com/products/%C3%A9", "https://shop.example.com/products/a.b", "https://shop.example.com/other/x"] {
    check("reject " + raw, RouteCoordinator.route(for: url(raw)) == nil)
}
let a = RouteCoordinator()
a.receive(link("one")); check("signed out retains without navigating", ids(a).isEmpty)
a.setAuthenticated(true); check("authentication waits for readiness", ids(a).isEmpty)
a.setReady(true); check("auth first drains", ids(a) == ["one"])
a.setReady(true); a.setAuthenticated(true); check("callbacks do not replay", ids(a) == ["one"])
let b = RouteCoordinator()
b.receive(link("one")); b.setReady(true); check("readiness waits for authentication", ids(b).isEmpty)
b.setAuthenticated(true); check("ready first drains", ids(b) == ["one"])
let c = RouteCoordinator()
c.receive(link("one")); c.receive(link("two")); c.receive(url("https://evil.example/products/evil"))
c.setReady(true); c.setAuthenticated(true); check("latest valid pending survives invalid link", ids(c) == ["two"])
let d = active()
d.receive(link("one")); d.receive(url("https://shop.example.com/products/one?utm=again"))
check("current top deduplicates", ids(d) == ["one"])
d.receive(link("two")); d.receive(link("one")); check("return to older route allowed", ids(d) == ["one", "two", "one"])
let e = RouteCoordinator()
e.receive(link("one")); e.cancelLogin(); e.setReady(true); e.setAuthenticated(true)
check("cancel discards pending", ids(e).isEmpty)
let f = active(); f.receive(link("one")); f.setReady(false); f.receive(link("two"))
check("temporary unready does not navigate", ids(f) == ["one"])
f.setReady(true); check("temporary readiness resumes", ids(f) == ["one", "two"])
f.setReady(false); f.receive(link("three")); f.logOut()
check("logout clears history and auth", ids(f).isEmpty && !f.isAuthenticated)
f.setReady(true); f.setAuthenticated(true); check("logout clears pending", ids(f).isEmpty)
f.logOut(); f.receive(link("four")); f.setAuthenticated(true); check("new postlogout link allowed", ids(f) == ["four"])
let data = try JSONSerialization.data(withJSONObject: outcomes, options: [.prettyPrinted, .sortedKeys])
print(String(data: data, encoding: .utf8)!)
