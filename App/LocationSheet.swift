import SwiftUI

struct LocationSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let onSelect: (SavedCity) -> Void
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { model.requestLocation(); dismiss() } label: { Label("Use current location", systemImage: "location.fill") }
                } footer: { Text("Optional. Choose any city without sharing your device location.") }
                if !query.isEmpty {
                    Section("Search results") {
                        if model.searching { ProgressView("Searching places…") }
                        if let error = model.searchError { Text(error).font(.caption).foregroundStyle(Theme.muted) }
                        ForEach(model.searchResults) { city in row(city) }
                    }
                } else {
                    Section("Your places") {
                        ForEach(model.cities) { city in
                            HStack { row(city); if city.id == model.city.id { Image(systemName: "checkmark").foregroundStyle(Theme.olive) } }
                        }.onDelete { indices in
                            let removed = Set(indices.map { model.cities[$0].id })
                            model.cities.removeAll { removed.contains($0.id) && $0.id != model.city.id }
                        }
                    }
                    Section("Around the world") { ForEach(SavedCity.suggestions.filter { city in !model.cities.contains(where: { $0.id == city.id }) }) { city in row(city) } }
                }
            }.scrollContentBackground(.hidden).pageBackground().navigationTitle("Your places").searchable(text: $query, prompt: "Search a city, address or destination").task(id: query) {
                do { try await Task.sleep(for: .milliseconds(350)); guard !Task.isCancelled else { return }; await model.search(query) } catch {}
            }.toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func row(_ city: SavedCity) -> some View {
        Button { onSelect(city); dismiss() } label: {
            VStack(alignment: .leading, spacing: 5) { Text(city.name).foregroundStyle(Theme.ink); Text(city.timeZoneID.replacingOccurrences(of: "_", with: " ")).font(.caption2).foregroundStyle(Theme.muted) }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
