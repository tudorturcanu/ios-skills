import SwiftUI

struct OrderSummary: View {
    let recipient: String
    let city: String
    let total: Decimal
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("order.shipping \(recipient) \(city)")
            Text("order.total \(total.formatted(.currency(code: currencyCode)))")
                .bold()
        }
    }
}
