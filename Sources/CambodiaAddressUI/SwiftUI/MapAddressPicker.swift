#if canImport(MapKit) && canImport(SwiftUI)
import SwiftUI
import MapKit
import CambodiaAddressCore
import CambodiaAddressGeo

/// A SwiftUI view that lets the user choose a location on a map and resolves
/// it to the nearest commune via ``AddressGeoService``.
///
/// Present as a sheet or navigation destination. When the user taps **Confirm**,
/// `onSelect` is called with a partial ``AddressSelection``
/// (province + district + commune; village is `nil` — the user should confirm it
/// in the normal picker flow).
///
/// ```swift
/// @State private var showMap = false
/// @State private var selection = AddressSelection()
///
/// Button("Pick on map") { showMap = true }
///   .sheet(isPresented: $showMap) {
///       MapAddressPicker(geoService: service) { result in
///           selection = result
///           showMap = false
///       }
///   }
/// ```
@available(iOS 18.0, *)
public struct MapAddressPicker: View {

    private let geoService: AddressGeoService
    private let onSelect: @MainActor (AddressSelection) -> Void

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 12.5, longitude: 104.9),
            span: MKCoordinateSpan(latitudeDelta: 4.5, longitudeDelta: 4.5)
        )
    )
    @State private var pin: CLLocationCoordinate2D? = nil
    @State private var isResolving = false
    @State private var errorMessage: String? = nil
    @State private var resolvedName: String? = nil

    /// - Parameters:
    ///   - geoService: Service that maps a coordinate to the nearest commune.
    ///   - onSelect: Called on the main actor when the user confirms a location.
    public init(
        geoService: AddressGeoService,
        onSelect: @escaping @MainActor (AddressSelection) -> Void
    ) {
        self.geoService = geoService
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapLayer
                    .ignoresSafeArea(edges: .bottom)

                if let name = resolvedName {
                    resolvedBanner(name)
                }
            }
            .navigationTitle("Pick Location")
            .navigationBarTitleDisplayModeInlineIfAvailable()
            .toolbar { toolbarContent }
            .overlay(alignment: .bottomTrailing) {
                if isResolving {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial, in: Circle())
                        .padding()
                }
            }
            .alert("Location Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sub-views

    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let pin {
                    Annotation("", coordinate: pin) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red, .white)
                    }
                }
            }
            .onTapGesture { point in
                guard let coord = proxy.convert(point, from: .local) else { return }
                pin = coord
                resolvedName = nil
                Task { await resolve(coordinate: coord) }
            }
        }
    }

    private func resolvedBanner(_ name: String) -> some View {
        HStack {
            Image(systemName: "mappin")
            Text(name)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .padding(.bottom, 16)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { onSelect(.init()) }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Confirm") {
                Task { await confirmCurrentPin() }
            }
            .disabled(pin == nil || isResolving)
        }
    }

    // MARK: - Actions

    @MainActor
    private func resolve(coordinate: CLLocationCoordinate2D) async {
        isResolving = true
        defer { isResolving = false }
        do {
            let geoCoord = Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let result = try await geoService.selection(near: geoCoord)
            resolvedName = [
                result.commune?.name.en,
                result.district?.name.en,
                result.province?.name.en
            ].compactMap { $0 }.joined(separator: ", ")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func confirmCurrentPin() async {
        guard let pin else { return }
        isResolving = true
        defer { isResolving = false }
        do {
            let geoCoord = Coordinate(latitude: pin.latitude, longitude: pin.longitude)
            let result = try await geoService.selection(near: geoCoord)
            onSelect(result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#endif
