import SwiftUI

struct Screen: View {
    let serverStatus: String
    var body: some View {
        VStack {
            Text("Save")
            Text(verbatim: serverStatus)
            Text("BrandName")
        }
    }
}
