import SwiftUI
import CambodiaAddress

/// Tab 5 — live address validation and postal-code derivation.
///
/// Demonstrates `AddressValidator`, `ValidationIssue`, and `PostalCode`
/// from `CambodiaAddressCore`, available via `import CambodiaAddress`.
struct ValidationDemoView: View {
    @State private var address = AddressSelection()
    @State private var requiresVillage = true

    private var issues: [ValidationIssue] {
        AddressValidator.validate(address, requiresVillage: requiresVillage)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Address") {
                    CambodiaAddressPicker(selection: $address)
                }

                Section("Options") {
                    Toggle("Require village", isOn: $requiresVillage)
                }

                validationSection

                postalCodeSection

                Section {
                    Button("Clear", role: .destructive) { address = AddressSelection() }
                        .disabled(address.isEmpty)
                }
            }
            .navigationTitle("Validation")
        }
    }

    // MARK: - Sub-sections

    @ViewBuilder
    private var validationSection: some View {
        Section("Validation") {
            if address.isEmpty {
                Text("Pick an address above to see results")
                    .foregroundStyle(.secondary)
            } else if issues.isEmpty {
                Label("Valid address", systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            } else {
                ForEach(issues, id: \.self) { issue in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text(issue.errorDescription ?? "Unknown issue")
                            .font(.caption)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var postalCodeSection: some View {
        Section("Postal Code") {
            if let code = address.postalCode {
                HStack {
                    Text("Code")
                    Spacer()
                    Text(code.rawValue)
                        .monospaced()
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select a province to derive the postal code")
                    .foregroundStyle(.secondary)
            }
            Text("Formula: province (2 digits) + district suffix (2) + \"0\"")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ValidationDemoView()
        .cambodiaAddress(.live())
}
