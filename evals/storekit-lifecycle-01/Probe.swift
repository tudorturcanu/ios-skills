import UIKit
import StoreKit
import StoreKitTest

@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Probe", sessionRole: session.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = ProbeController()
        window.makeKeyAndVisible()
        self.window = window
    }
}

final class ProbeController: UIViewController {
    private var started = false
    private var observations: [[String: Any]] = []
    private var checks: [String: Bool] = [:]
    private let premium = "org.example.iosskills.premium"
    private let coins = "org.example.iosskills.coins"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard ProcessInfo.processInfo.environment["IOS_SKILL_HOSTED_TEST"] != "1" else { return }
        guard !started else { return }
        started = true
        Task { await runProbe() }
    }

    private func write(_ value: [String: Any], file: String) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL.documentsDirectory.appending(path: file), options: .atomic)
    }

    private func phase(_ name: String) throws {
        try write(["phase": name, "checks": checks, "observations": observations,
                   "complete": false], file: "progress.json")
    }

    private func snapshot(_ name: String, record: Bool = true) async throws -> (verified: Set<String>, unverified: Set<String>) {
        try Task.checkCancellation()
        var verified: Set<String> = []
        var unverified: Set<String> = []
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction): verified.insert(transaction.productID)
            case .unverified(let transaction, _): unverified.insert(transaction.productID)
            }
        }
        try Task.checkCancellation()
        if record {
            observations.append(["phase": name, "verified": verified.sorted(), "unverified": unverified.sorted()])
        }
        return (verified, unverified)
    }

    private func waitForSnapshot(_ name: String,
                                 matching predicate: (Set<String>, Set<String>) -> Bool) async throws
        -> (verified: Set<String>, unverified: Set<String>) {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        var value = try await snapshot(name, record: false)
        var attempts = 1
        while !predicate(value.verified, value.unverified) && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
            value = try await snapshot(name, record: false)
            attempts += 1
        }
        observations.append(["phase": name, "verified": value.verified.sorted(),
                             "unverified": value.unverified.sorted(), "attempts": attempts])
        return value
    }

    private func waitForUnfinished(_ id: UInt64, present: Bool) async throws -> Set<UInt64> {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        var ids = await unfinishedIDs()
        while ids.contains(id) != present && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
            ids = await unfinishedIDs()
        }
        return ids
    }

    private func unfinishedIDs() async -> Set<UInt64> {
        var ids: Set<UInt64> = []
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result { ids.insert(transaction.id) }
        }
        return ids
    }

    func runProbe() async {
        do {
            try phase("initialize_local_session")
            guard let configuration = Bundle.main.url(forResource: "Products", withExtension: "storekit") else {
                throw NSError(domain: "Probe", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing local configuration"])
            }
            let session = try SKTestSession(contentsOf: configuration)
            session.resetToDefaultState()
            session.disableDialogs = true
            session.clearTransactions()
            defer { session.clearTransactions(); session.resetToDefaultState() }
            try phase("load_products")
            let products = try await Product.products(for: [premium, coins])
            checks["local_products_loaded"] = Set(products.map(\.id)) == [premium, coins]
            let initial = try await snapshot("initial")
            checks["initial_empty"] = initial.verified.isEmpty && initial.unverified.isEmpty

            try phase("buy_nonconsumable")
            let purchase = try await session.buyProduct(identifier: premium)
            observations.append(["phase": "purchase_result", "transaction_id": purchase.id,
                                 "environment": purchase.environment.rawValue, "product_id": purchase.productID])
            checks["purchase_is_local_xcode_transaction"] = purchase.environment == .xcode
            let purchased = try await waitForSnapshot("purchased_nonconsumable") { $0 == [self.premium] && $1.isEmpty }
            checks["purchase_entitles"] = purchased.verified == [premium] && purchased.unverified.isEmpty
            await purchase.finish()
            let finished = try await waitForSnapshot("finished_nonconsumable") { $0 == [self.premium] && $1.isEmpty }
            checks["finish_does_not_remove_nonconsumable"] = checks["purchase_entitles"] == true
                && finished.verified == [premium] && finished.unverified.isEmpty

            try phase("inject_verification_failure")
            try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
            let failedVerification = try await waitForSnapshot("unverified_nonconsumable") { $0.isEmpty && $1 == [self.premium] }
            checks["unverified_is_not_an_empty_snapshot"] = failedVerification.verified.isEmpty
                && failedVerification.unverified == [premium]
            try await session.setSimulatedError(nil, forAPI: .verification)
            let recovered = try await waitForSnapshot("verification_recovered") { $0 == [self.premium] && $1.isEmpty }
            checks["verified_after_injection_reset"] = recovered.verified == [premium] && recovered.unverified.isEmpty

            try phase("refund_nonconsumable")
            try session.refundTransaction(identifier: UInt(purchase.id))
            let refunded = try await waitForSnapshot("after_refund") { $0.isEmpty && $1.isEmpty }
            checks["refund_removes_entitlement"] = checks["purchase_entitles"] == true
                && checks["verified_after_injection_reset"] == true && refunded.verified.isEmpty && refunded.unverified.isEmpty
            var badGrowOnly = purchased.verified
            badGrowOnly.formUnion(refunded.verified)
            checks["grow_only_negative_control_detected"] = badGrowOnly.contains(premium)
                && !refunded.verified.contains(premium) && checks["refund_removes_entitlement"] == true

            try phase("buy_consumable")
            let consumable = try await session.buyProduct(identifier: coins)
            observations.append(["phase": "consumable_result", "transaction_id": consumable.id,
                                 "environment": consumable.environment.rawValue, "product_id": consumable.productID])
            checks["consumable_is_local_xcode_transaction"] = consumable.environment == .xcode
            let beforeFinish = try await snapshot("unfinished_consumable")
            let unfinishedBefore = try await waitForUnfinished(consumable.id, present: true)
            checks["consumable_absent_from_current_entitlements"] = !beforeFinish.verified.contains(coins)
                && !beforeFinish.unverified.contains(coins)
            checks["consumable_in_unfinished_before_finish"] = unfinishedBefore.contains(consumable.id)
            await consumable.finish()
            let unfinishedAfter = try await waitForUnfinished(consumable.id, present: false)
            checks["finished_consumable_leaves_unfinished"] = unfinishedBefore.contains(consumable.id)
                && !unfinishedAfter.contains(consumable.id)
            observations.append(["phase": "consumable_unfinished_ids", "before": unfinishedBefore.sorted(),
                                 "after": unfinishedAfter.sorted(), "transaction_id": consumable.id])

            // Exercise app-facing verification separately from the cached entitlement.
            try phase("fresh_purchase_verification")
            guard let product = products.first(where: { $0.id == coins }),
                  let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
                throw NSError(domain: "Probe", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing product or test-host scene"])
            }
            try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
            let configured = await session.simulatedError(forAPI: .verification)
            checks["verification_injection_readback"] = configured == .verification(.invalidSignature)
            observations.append(["phase": "verification_injection_readback",
                                 "matches_invalid_signature": checks["verification_injection_readback"] == true])
            let freshResult = try await product.purchase(confirmIn: scene)
            var freshID: UInt64?
            checks["fresh_purchase_is_unverified"] = false
            switch freshResult {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    freshID = transaction.id
                    observations.append(["phase": "fresh_purchase", "verification": "verified",
                                         "transaction_id": transaction.id, "environment": transaction.environment.rawValue])
                case .unverified(let transaction, let error):
                    freshID = transaction.id
                    checks["fresh_purchase_is_unverified"] = error == .invalidSignature
                    // Diagnostic fields only: this branch grants and finishes nothing.
                    observations.append(["phase": "fresh_purchase", "verification": "unverified",
                                         "transaction_id": transaction.id, "verification_error": String(describing: error)])
                }
            case .pending:
                observations.append(["phase": "fresh_purchase", "verification": "pending"])
            case .userCancelled:
                observations.append(["phase": "fresh_purchase", "verification": "cancelled"])
            @unknown default:
                observations.append(["phase": "fresh_purchase", "verification": "unknown"])
            }
            try await session.setSimulatedError(nil, forAPI: .verification)
            try phase("fresh_verification_recovery")
            var verifiedAfterReset: Transaction?
            let recoveryDeadline = ContinuousClock.now.advanced(by: .seconds(5))
            repeat {
                try Task.checkCancellation()
                if case .verified(let transaction) = await Transaction.latest(for: coins), transaction.id == freshID {
                    verifiedAfterReset = transaction
                    break
                }
                try await Task.sleep(for: .milliseconds(100))
            } while ContinuousClock.now < recoveryDeadline
            checks["fresh_same_id_verification_recovers"] = checks["fresh_purchase_is_unverified"] == true
                && verifiedAfterReset?.environment == .xcode
            observations.append(["phase": "fresh_verification_recovery", "verified_same_id": verifiedAfterReset != nil,
                                 "transaction_id": verifiedAfterReset.map { $0.id } as Any? ?? NSNull(),
                                 "environment": verifiedAfterReset.map { $0.environment.rawValue } as Any? ?? NSNull()])
            if let transaction = verifiedAfterReset { await transaction.finish() }
            try write(["checks": checks, "observations": observations, "passed": checks.values.allSatisfy { $0 },
                       "environment": "local StoreKitTest", "os": UIDevice.current.systemVersion], file: "results.json")
        } catch {
            try? write(["checks": checks, "observations": observations, "passed": false,
                        "error": String(describing: error), "environment": "local StoreKitTest"], file: "results.json")
        }
    }
}
