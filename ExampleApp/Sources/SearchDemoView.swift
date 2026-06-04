import SwiftUI
import CambodiaAddress

/// Tab 2 — live offline search (Khmer + English, prefix + fuzzy) via the
/// facade's `search(_:levels:limit:)`, with level badges and breadcrumb paths.
struct SearchDemoView: View {
    let cambodia: CambodiaAddress
    let language: AddressLanguage

    @State private var query = ""
    @State private var levels: Set<AdministrativeLevel> = Set(AdministrativeLevel.allCases)
    @State private var results: [AddressSearchResult] = []
    @State private var picked: AddressSelection?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if let picked {
                    Section("Selected") {
                        Text(AddressFormatter(language: language).string(from: picked))
                    }
                }

                Section("Levels") {
                    levelFilter
                }

                Section("Results (\(results.count))") {
                    if results.isEmpty {
                        Text(query.isEmpty ? "Try ដូនពេញ or “Doun Penh”" : "No matches")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(results) { result in
                        Button { picked = result.path } label: { resultRow(result) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "ដូនពេញ / Doun Penh")
            .onChange(of: query) { _, newValue in runSearch(newValue) }
            .onChange(of: levels) { _, _ in runSearch(query) }
        }
    }

    private var levelFilter: some View {
        HStack {
            ForEach(AdministrativeLevel.allCases) { level in
                let isOn = levels.contains(level)
                Button(level.rawValue.capitalized) {
                    if isOn { levels.remove(level) } else { levels.insert(level) }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(isOn ? .accentColor : .secondary)
            }
        }
    }

    private func resultRow(_ result: AddressSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(result.name.resolved(for: language))
                Spacer()
                Text(result.level.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule())
            }
            // Full breadcrumb from province down to the match.
            Text(AddressFormatter(language: language, order: .provinceFirst).string(from: result.path))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func runSearch(_ rawQuery: String) {
        searchTask?.cancel()
        let trimmed = rawQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(200)) // debounce
            guard !Task.isCancelled else { return }
            let hits = (try? await cambodia.search(trimmed, levels: levels)) ?? []
            if !Task.isCancelled { results = hits }
        }
    }
}

#Preview {
    SearchDemoView(cambodia: .live(), language: .english)
}
