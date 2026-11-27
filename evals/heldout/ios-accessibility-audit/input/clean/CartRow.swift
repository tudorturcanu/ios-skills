import SwiftUI

struct CartRow: View {
    let item: CartItem
    @ObservedObject var store: CartStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.name)
                    .font(.headline)
                Spacer()
                Text(item.lineTotal, format: .currency(code: "USD"))
                    .font(.body)
            }

            HStack(spacing: 16) {
                Button { store.decrement(item) } label: {
                    Image("ic_minus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Decrease quantity")
                .accessibilityValue(Text("\(item.quantity)"))

                Text("\(item.quantity)")
                    .font(.body.monospacedDigit())

                Button { store.increment(item) } label: {
                    Image("ic_plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Increase quantity")
                .accessibilityValue(Text("\(item.quantity)"))

                Spacer()

                Button(role: .destructive) { store.remove(item) } label: {
                    Image("ic_remove")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Remove \(item.name) from cart")
            }
        }
        .padding(.vertical, 4)
    }
}
