import SwiftUI

struct CheckoutView: View {
    @StateObject private var store: CartStore
    var onPay: () -> Void

    init(store: CartStore, onPay: @escaping () -> Void) {
        _store = StateObject(wrappedValue: store)
        self.onPay = onPay
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(store.items) { item in
                    CartRow(item: item, store: store)
                }
            }
            .listStyle(.plain)

            VStack(spacing: 12) {
                HStack {
                    Text("Total")
                        .font(.title3.bold())
                    Spacer()
                    Text(store.total, format: .currency(code: "USD"))
                        .font(.title3.bold())
                }
                Button(action: onPay) {
                    Text("Pay now")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("Cart")
    }
}
