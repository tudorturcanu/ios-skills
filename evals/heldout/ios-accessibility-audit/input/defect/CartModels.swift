import Foundation

struct CartItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var unitPrice: Decimal
    var quantity: Int

    var lineTotal: Decimal { unitPrice * Decimal(quantity) }
}

@MainActor
final class CartStore: ObservableObject {
    @Published var items: [CartItem]

    init(items: [CartItem] = []) { self.items = items }

    var total: Decimal { items.reduce(0) { $0 + $1.lineTotal } }

    func increment(_ item: CartItem) {
        guard let i = items.firstIndex(of: item) else { return }
        items[i].quantity += 1
    }

    func decrement(_ item: CartItem) {
        guard let i = items.firstIndex(of: item) else { return }
        if items[i].quantity > 1 { items[i].quantity -= 1 }
    }

    func remove(_ item: CartItem) {
        items.removeAll { $0.id == item.id }
    }
}
