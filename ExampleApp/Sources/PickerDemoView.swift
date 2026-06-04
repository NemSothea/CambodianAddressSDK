import SwiftUI
import CambodiaAddress

/// Tab 1 — the drop-in cascading picker bound to an `AddressSelection`,
/// plus the standalone `AddressPickerView` presented as a sheet.
struct PickerDemoView: View {
    @Binding var language: AddressLanguage
    @State private var address = AddressSelection()
    @State private var showingStandalone = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Picker") {
                    CambodiaAddressPicker(selection: $address)
                }

                Section("Selected address") {
                    if address.isEmpty {
                        Text("Nothing selected yet").foregroundStyle(.secondary)
                    } else {
                        Text(AddressFormatter(language: language).string(from: address))
                        if address.isComplete {
                            Label("Complete", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.footnote)
                        }
                    }
                }

                Section("Options") {
                    Picker("Language", selection: $language) {
                        Text("English").tag(AddressLanguage.english)
                        Text("ខ្មែរ").tag(AddressLanguage.khmer)
                    }
                    Button("Open standalone screen") { showingStandalone = true }
                    Button("Clear", role: .destructive) { address = AddressSelection() }
                        .disabled(address.isEmpty)
                }
            }
            .navigationTitle("Cambodia Address")
            .sheet(isPresented: $showingStandalone) {
                AddressPickerView(initialSelection: address) { selected in
                    address = selected
                    showingStandalone = false
                }
                .addressLanguage(language)
            }
        }
    }
}

#Preview {
    PickerDemoView(language: .constant(.english))
        .cambodiaAddress(.live())
}
