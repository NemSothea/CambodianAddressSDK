import SwiftUI
import CambodiaAddressCore

/// Drop-in address picker bound to an ``AddressSelection``.
///
/// ```swift
/// @State private var address = AddressSelection()
/// CambodiaAddressPicker(selection: $address)
///     .addressLanguage(.khmer)
/// ```
///
/// Reads its repository and language from the environment (override via `.cambodiaAddress(_:)`
/// and `.addressLanguage(_:)`). Embeds anywhere — it brings its own sheets, no host
/// `NavigationStack` required.
public struct CambodiaAddressPicker: View {
    @Binding private var selection: AddressSelection
    @Environment(\.addressRepository) private var repository
    @Environment(\.addressLanguage) private var language

    @State private var model: AddressPickerViewModel?
    @State private var activeLevel: AdministrativeLevel?

    public init(selection: Binding<AddressSelection>) {
        self._selection = selection
    }

    public var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .task { await bootstrap() }
            }
        }
    }

    private func bootstrap() async {
        guard model == nil else { return }
        let viewModel = AddressPickerViewModel(
            repository: repository,
            language: language,
            initialSelection: selection
        )
        model = viewModel
        await viewModel.load()
    }

    @ViewBuilder
    private func content(_ model: AddressPickerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField(model)

            if !model.searchResults.isEmpty {
                searchResults(model)
            } else {
                ForEach(AdministrativeLevel.allCases) { level in
                    levelRow(level, model: model)
                }
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .animation(.default, value: model.searchResults.isEmpty)
        .onChange(of: model.selection) { _, newValue in
            selection = newValue
        }
        .sheet(item: $activeLevel) { level in
            LevelSelectionList(
                title: model.strings.label(for: level),
                items: model.items(for: level),
                language: model.language,
                selectedID: model.selectedID(for: level),
                searchPrompt: model.strings.searchPlaceholder,
                onSelect: { id in Task { await model.select(level: level, id: id) } }
            )
        }
    }

    // MARK: - Pieces

    private func searchField(_ model: AddressPickerViewModel) -> some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(
                model.strings.searchPlaceholder,
                text: Binding(get: { model.searchQuery }, set: { model.search($0) })
            )
            .textFieldStyle(.plain)
            if !model.searchQuery.isEmpty {
                Button {
                    model.search("")
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.strings.clearButton)
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func searchResults(_ model: AddressPickerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.searchResults) { result in
                Button {
                    Task { await model.apply(result) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.name.resolved(for: model.language))
                            .foregroundStyle(.primary)
                        Text(AddressFormatter(language: model.language).string(from: result.path))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
                Divider()
            }
        }
    }

    private func levelRow(_ level: AdministrativeLevel, model: AddressPickerViewModel) -> some View {
        let value = model.items(for: level).first { $0.id == model.selectedID(for: level) }
        let enabled = model.isEnabled(level)
        return Button {
            activeLevel = level
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.strings.label(for: level))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value?.name.resolved(for: model.language) ?? model.strings.selectPlaceholder)
                        .foregroundStyle(value == nil ? .secondary : .primary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityHint(model.strings.label(for: level))
    }
}
