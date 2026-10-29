import SwiftUI
import SwiftData

struct EditAssetView: View {
    @Environment(\.dismiss) private var dismiss
    
    // @Bindable tells SwiftData to automatically track and save any changes made to this object
    @Bindable var asset: Asset

    var body: some View {
        Form {
            Section(header: Text("Edit \(asset.name)").font(.headline)) {
                LabeledContent("Ticker", value: asset.ticker)
                
                Picker("Asset Type", selection: $asset.assetType) {
                    Text("Stock").tag("Stock")
                    Text("Mutual Fund").tag("Mutual Fund")
                    Text("Crypto").tag("Crypto")
                }
                
                TextField("Quantity", value: $asset.quantity, format: .number)
                TextField("Avg Purchase Price (₹)", value: $asset.averagePurchasePrice, format: .number)
            }
            .padding(.bottom)

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350)
    }
}
