import SwiftUI
import WeatherStyle

struct CapsuleHomeView: View {
    @Environment(AppModel.self) private var model
    @State private var creating = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "Considered pieces. More combinations.", title: "Your travel\ncapsule.")
                EditorialPhoto(name: "couple_dry_6_1_1", height: 240).clipShape(.rect(cornerRadius: 28))
                Text("Pack for the coldest, warmest, wettest and windiest parts of your trip. We’ll look for pieces you own and favor suitable pieces that can work again.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(4)
                Button { creating = true } label: { Label("Build a capsule", systemImage: "plus").frame(maxWidth: .infinity).padding(10) }.buttonStyle(.borderedProminent).foregroundStyle(.white).accessibilityIdentifier("newCapsule")
                if model.capsules.isEmpty { Text("Add wardrobe pieces first for personal matches, or start with a suggested capsule.").font(.caption).foregroundStyle(Theme.muted) }
                ForEach(model.capsules) { capsule in NavigationLink { CapsuleDetailView(capsuleID: capsule.id) } label: {
                    HStack { VStack(alignment: .leading, spacing: 8) { Text(capsule.city.name).font(Theme.editorial(29)); Text("\(capsule.plan.days.count) days · \(capsule.plan.pieces.count) clothing pieces · \(capsule.plan.ownedCount) from your wardrobe").font(.caption).foregroundStyle(Theme.muted) }; Spacer(); Image(systemName: "arrow.up.right") }.glassCard()
                }.buttonStyle(.plain) }
            }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.pageBackground().navigationTitle("Travel capsules").navigationBarTitleDisplayMode(.inline).sheet(isPresented: $creating) { NewCapsuleView() }
    }
}
struct NewCapsuleView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var destination: SavedCity?
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(2 * 86400)
    @State private var style: FashionStyle = .casual
    @State private var searching = false
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") { Button { searching = true } label: { Label(destination?.name ?? model.city.name, systemImage: "mappin.and.ellipse") } }
                Section("Travel dates") {
                    DatePicker("Departure", selection: $start, in: Date()...Date().addingTimeInterval(8 * 86400), displayedComponents: .date).onChange(of: start) { if end < start { end = start } }
                    DatePicker("Return", selection: $end, in: start...max(start, Date().addingTimeInterval(8 * 86400)), displayedComponents: .date)
                    Picker("Main occasion", selection: $style) { ForEach(FashionStyle.allCases) { Text($0.rawValue).tag($0) } }
                }
                Section {
                    Button { Task {
                        loading = true; error = nil
                        do { try await model.makeCapsule(city: destination ?? model.city, start: start, end: end, occasion: style); dismiss() }
                        catch { self.error = error.localizedDescription }
                        loading = false
                    } } label: { HStack { if loading { ProgressView() }; Text(loading ? "Considering the forecast…" : "Create my capsule") } }.disabled(loading).accessibilityIdentifier("createCapsule")
                    if let error { Text(error).font(.caption).foregroundStyle(.red) }
                } footer: { Text("Capsules use available forecasts within eight days. Your wardrobe’s comfort ranges and rain-ready choices determine personal matches. Pack fresh base layers and essentials for every day; repeated pieces aren’t a laundry plan.") }
            }.environment(\.timeZone, (destination ?? model.city).timeZone).scrollContentBackground(.hidden).pageBackground().navigationTitle("A lighter suitcase").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(loading) } }
                .sheet(isPresented: $searching) { LocationSheet(onSelect: { destination = $0 }, allowsCurrentLocation: false) }
        }
    }
}
struct CapsuleDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let capsuleID: UUID
    private var capsule: SavedCapsule? { model.capsules.first { $0.id == capsuleID } }
    var body: some View {
        Group { if let capsule {
            List {
                Section {
                    PageHeading(eyebrow: "\(capsule.plan.days.count) days · \(capsule.plan.pieces.count) considered pieces", title: capsule.city.name).padding(.vertical, 15)
                    Text("\(capsule.plan.ownedCount) pieces from your wardrobe. Other pieces are suggestions to add or adapt.").font(.subheadline).foregroundStyle(Theme.muted)
                }.listRowBackground(Color.clear)
                Section("The capsule") { ForEach(capsule.plan.pieces) { piece in
                    Button { model.toggleCapsule(piece.name, capsuleID: capsuleID) } label: { HStack(alignment: .top, spacing: 14) { Image(systemName: capsule.checked.contains(piece.name) ? "checkmark.circle.fill" : "circle").foregroundStyle(Theme.olive); VStack(alignment: .leading, spacing: 5) { Text(piece.name).foregroundStyle(Theme.ink); Text("\(piece.garmentID == nil ? "Suggested" : "You own this") · \(piece.daysUsed) \(piece.daysUsed == 1 ? "day" : "days")").font(.caption).foregroundStyle(Theme.muted) } }.padding(.vertical, 5) }
                } }
                Section("Bring as well") { ForEach(capsule.plan.bring, id: \.self) { item in Button { model.toggleCapsule(item, capsuleID: capsuleID) } label: { Label(item, systemImage: capsule.checked.contains(item) ? "checkmark.circle.fill" : "circle").foregroundStyle(Theme.ink) } } }
                Section("The daily combinations") { ForEach(capsule.plan.days) { day in VStack(alignment: .leading, spacing: 12) {
                    Text(dateTitle(day.date, city: capsule.city)).font(Theme.editorial(25))
                    Text(day.pieces.joined(separator: " · ")).font(.caption).foregroundStyle(Theme.muted)
                }.padding(.vertical, 7) } }
                Section { ShareLink(item: "Capsule for \(capsule.city.name)\n" + capsule.plan.checklist.map { "• " + $0 }.joined(separator: "\n")) { Label("Share capsule checklist", systemImage: "square.and.arrow.up") }; Button("Delete capsule", role: .destructive) { model.capsules.removeAll { $0.id == capsuleID }; dismiss() } }
            }.scrollContentBackground(.hidden).pageBackground()
        } }.navigationTitle("Your capsule").navigationBarTitleDisplayMode(.inline)
    }
    private func dateTitle(_ date: Date, city: SavedCity) -> String {
        let formatter = DateFormatter(); formatter.timeZone = city.timeZone; formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}
