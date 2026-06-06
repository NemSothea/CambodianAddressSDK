import SwiftUI
import CambodiaAddress

/// Tab 4 — GPS → nearest commune and MapKit map picker.
///
/// Demonstrates `AddressGeoService` (programmatic GPS lookup) and
/// `MapAddressPicker` (tap-on-map flow), both from `CambodiaAddressGeo`.
struct GeoMapDemoView: View {
    let cambodia: CambodiaAddress

    @State private var address = AddressSelection()
    @State private var showingMapPicker = false
    @State private var isLookingUp = false
    @State private var errorMessage: String?
    @State private var language: AddressLanguage = .english

    // Phnom Penh city centre — a realistic demo coordinate.
    private let demoCoordinate = Coordinate(latitude: 11.5625, longitude: 104.916)

    private var geoService: AddressGeoService {
        AddressGeoService(repository: cambodia.repository)
    }

    var body: some View {
        NavigationStack {
            Form {
                resultSection
                gpsSection
                mapSection
                optionsSection
            }
            .navigationTitle("GPS & Map")
            .sheet(isPresented: $showingMapPicker) {
                if #available(iOS 18, *) {
                    MapAddressPicker(geoService: geoService) { selected in
                        address = selected
                        showingMapPicker = false
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sub-sections

    @ViewBuilder
    private var resultSection: some View {
        Section("Result") {
            if address.isEmpty {
                Text("Tap a button below to resolve a location")
                    .foregroundStyle(.secondary)
            } else {
                Text(AddressFormatter(language: language).string(from: address))
                if let code = address.postalCode {
                    Label("Postal code: \(code.rawValue)", systemImage: "envelope")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var gpsSection: some View {
        Section {
            Button {
                Task { await lookUp() }
            } label: {
                if isLookingUp {
                    HStack {
                        ProgressView()
                        Text("Resolving nearest commune…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Label("Nearest commune for Phnom Penh", systemImage: "location.fill")
                }
            }
            .disabled(isLookingUp)
        } header: {
            Text("GPS lookup")
        } footer: {
            Text("Uses AddressGeoService + bundled centroids (haversine).")
        }
    }

    @ViewBuilder
    private var mapSection: some View {
        Section {
            Button {
                showingMapPicker = true
            } label: {
                Label("Open map picker", systemImage: "map")
            }
        } header: {
            Text("Map picker")
        } footer: {
            Text("MapAddressPicker (iOS 18+) — tap any point to drop a pin.")
        }
    }

    @ViewBuilder
    private var optionsSection: some View {
        Section("Options") {
            Picker("Language", selection: $language) {
                Text("English").tag(AddressLanguage.english)
                Text("ខ្មែរ").tag(AddressLanguage.khmer)
            }
            Button("Clear", role: .destructive) { address = AddressSelection() }
                .disabled(address.isEmpty)
        }
    }

    // MARK: - Actions

    private func lookUp() async {
        isLookingUp = true
        defer { isLookingUp = false }
        do {
            address = try await geoService.selection(near: demoCoordinate)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    GeoMapDemoView(cambodia: .live())
}
