import Foundation

/// Checks supported valid formatting examples; incompatible argument types are never executed.
@main struct FoundationChecks {
    static func main() throws {
        let locale = Locale(identifier: "en_US_POSIX")
        let name = "Rita" as NSString
        let cases: [(String, String, [any CVarArg], String)] = [
            ("implicit objects and integers", "%@ has %lld", [name, Int64(7)], "Rita has 7"),
            ("positional reordering", "%2$lld for %1$@", [name, Int64(7)], "7 for Rita"),
            ("repeated positional object", "%1$@ / %1$@", [name], "Rita / Rita"),
            ("literal percent", "%1$lld%%", [Int64(70)], "70%"),
            ("long long q alias", "%qd", [Int64(7)], "7"),
            ("unsigned hexadecimal presentation", "%X", [UInt32(255)], "FF"),
            ("width and precision", "%1$8.2f", [Double(3.14)], "    3.14"),
            ("signed integer", "%d", [Int32(-2)], "-2")
        ]
        let results = cases.map { label, format, arguments, expected in
            let actual = String(format: format, locale: locale, arguments: arguments)
            return ["case": label, "format": format, "actual": actual, "expected": expected,
                    "passed": actual == expected] as [String: Any]
        }
        let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        if results.contains(where: { $0["passed"] as? Bool != true }) { exit(1) }
    }
}
