import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(EntitlementManager.self) private var entitlements
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(entitlements.products) { product in
                Button("\(product.displayName) - \(product.displayPrice)") {
                    Task {
                        do { try await entitlements.purchase(product) }
                        catch { errorMessage = error.localizedDescription }
                    }
                }
            }
            Button("Restore Purchases") {
                Task { await entitlements.restore() }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .task {
            await entitlements.loadProducts()
            entitlements.startListening()
        }
    }
}
