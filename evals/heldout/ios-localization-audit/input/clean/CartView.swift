import SwiftUI

struct CartView: View {
    let items: [CartItem]
    let onCheckout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: relies on the String Catalog plural variations for "cart.items.count"
            Text("cart.items.count \(items.count)")
                .font(.headline)

            ForEach(items) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text(item.price, format: .currency(code: item.currencyCode))
                }
            }

            Button("cart.checkout", action: onCheckout)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct CartItem: Identifiable {
    let id: UUID
    let name: String
    let price: Decimal
    let currencyCode: String
}
