import SwiftUI

struct PlannerView: View {
    @Environment(AppModel.self) private var model
    @State private var newTrip = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "Less packing. More possibility.", title: "Go beautifully\nprepared.")
                ZStack(alignment: .bottomLeading) {
                    Image("couple_dry_7_0_3").resizable().scaledToFill().frame(height: 230, alignment: .top).clipped()
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 8) { Text("THE ART OF THE GETAWAY").font(.system(size: 9, design: .monospaced)).tracking(2); Text("A forecast. A capsule.\nA lighter suitcase.").font(Theme.editorial(30)) }.foregroundStyle(.white).padding(22)
                }.clipShape(.rect(cornerRadius: 28))
                Text("Choose your destination and dates. Build a packing list from its actual weather, including the warmest, coldest and wettest parts of your trip.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(5)
                Button { newTrip = true } label: { Label("Plan a new trip", systemImage: "plus").padding(9).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).foregroundStyle(.white).accessibilityIdentifier("newTrip")
                if model.trips.isEmpty { ContentUnavailableView("Your next chapter", systemImage: "suitcase.rolling", description: Text("Trips and packing lists stay on this device. Plan up to eight days ahead.")) }
                ForEach(model.trips) { trip in
                    NavigationLink { PackingListView(tripID: trip.id) } label: {
                        HStack(spacing: 18) {
                            Image(systemName: "airplane").font(.title).frame(width: 50)
                            VStack(alignment: .leading, spacing: 7) { Text(trip.city.name).font(Theme.editorial(28)); Text("\(trip.start.formatted(date: .abbreviated, time: .omitted)) – \(trip.end.formatted(date: .abbreviated, time: .omitted))").font(.caption); Text("\(trip.checked.count) of \(trip.items.count) packed").font(.caption2).foregroundStyle(Theme.olive) }
                            Spacer(); Image(systemName: "chevron.right").font(.caption)
                        }.glassCard()
                    }.buttonStyle(.plain)
                }
            }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.pageBackground().toolbar(.hidden, for: .navigationBar).sheet(isPresented: $newTrip) { NewTripSheet() }
    }
}
struct NewTripSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var destination: SavedCity?
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(86400 * 2)
    @State private var locations = false
    @State private var loading = false
    @State private var error: String?
    private var maximum: Date { Calendar.current.date(byAdding: .day, value: 8, to: Date())! }
    var body: some View {
        NavigationStack {
            Form {
                Section("Your destination") { Button { locations = true } label: { HStack { Label(destination?.name ?? "Choose a destination", systemImage: "mappin.and.ellipse"); Spacer(); Image(systemName: "chevron.right") } } }
                Section {
                    DatePicker("Departure", selection: $start, in: Date()...maximum, displayedComponents: .date).onChange(of: start) { if end < start { end = start } }
                    DatePicker("Return", selection: $end, in: start...maximum, displayedComponents: .date)
                } header: { Text("Travel dates") } footer: { Text("Lists use available forecasts, not seasonal guesses. Plan within eight days of today. Dates refer to the destination’s local calendar.") }
                Section {
                    Button { Task {
                        guard let destination else { return }
                        loading = true; error = nil
                        do { try await model.makeTrip(city: destination, start: start, end: end); dismiss() } catch { self.error = error.localizedDescription }
                        loading = false
                    } } label: { HStack { Spacer(); if loading { ProgressView() }; Text(loading ? "Checking destination weather…" : "Create my packing list"); Spacer() } }.disabled(destination == nil || loading)
                    if let error { Text(error).font(.caption).foregroundStyle(.red) }
                }
            }.environment(\.timeZone, destination?.timeZone ?? .current).scrollContentBackground(.hidden).pageBackground().navigationTitle("A new adventure").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(loading) } }.sheet(isPresented: $locations) { LocationSheet(onSelect: { destination = $0 }, allowsCurrentLocation: false) }
        }
    }
}
struct PackingListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let tripID: UUID
    var body: some View {
        if let trip = model.trips.first(where: { $0.id == tripID }) {
            List {
                Section { VStack(alignment: .leading, spacing: 12) { Eyebrow(text: "Your capsule wardrobe"); Text(trip.city.name).font(Theme.editorial(38)); Text("\(trip.checked.count) of \(trip.items.count) packed").font(.subheadline).foregroundStyle(Theme.olive); ProgressView(value: Double(trip.checked.count), total: Double(max(1, trip.items.count))).tint(Theme.olive) }.padding(.vertical, 14) }
                Section("Pack thoughtfully") { ForEach(trip.items, id: \.self) { item in Button { model.togglePacking(item, tripID: tripID) } label: { Label(item, systemImage: trip.checked.contains(item) ? "checkmark.circle.fill" : "circle").foregroundStyle(trip.checked.contains(item) ? Theme.olive : Theme.ink).padding(.vertical, 7) }.accessibilityValue(trip.checked.contains(item) ? "Packed" : "Not packed") } }
                Section { ShareLink(item: "Packing for \(trip.city.name)\n" + trip.items.map { "• " + $0 }.joined(separator: "\n")) { Label("Share packing list", systemImage: "square.and.arrow.up") }; Button("Delete trip", role: .destructive) { model.trips.removeAll { $0.id == tripID }; dismiss() } }
            }.scrollContentBackground(.hidden).pageBackground().navigationTitle("Packing list").navigationBarTitleDisplayMode(.inline)
        }
    }
}
