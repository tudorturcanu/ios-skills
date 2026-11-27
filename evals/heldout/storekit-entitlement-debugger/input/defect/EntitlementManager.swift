import StoreKit
import Observation

@MainActor
@Observable
final class EntitlementManager {
    private(set) var isPro = false
    private(set) var products: [Product] = []
    private var updatesTask: Task<Void, Never>?

    static let productIDs: Set<String> = [
        "com.lumen.pro.monthly", "com.lumen.pro.yearly"
    ]

    func loadProducts() async {
        products = (try? await Product.products(for: Self.productIDs)) ?? []
    }

    /// Starts observing Transaction.updates (renewals, refunds, revocations,
    /// Ask to Buy approvals, purchases made on other devices).
    func startListening() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                await tx.finish()
                await self?.refresh()
            }
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let tx) = verification else { return }
            await tx.finish()
            await refresh()
        case .pending, .userCancelled:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    /// Recomputes isPro from current entitlements.
    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if Self.productIDs.contains(tx.productID), tx.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }
}
