import SwiftUI
import WeatherStyle

struct EditorialEntry: Codable, Identifiable {
    var id: String
    var collection: String
    var band: Int
    var range: String
    var weather: String
    var occasion: String
    var style: FashionStyle { FashionStyle(rawValue: occasion) ?? .casual }
    static let all: [Self] = {
        guard let url = Bundle.main.url(forResource: "lookbook", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Self].self, from: data)) ?? []
    }()
}
struct StyleEdit: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var collections: [String]
    var notes: [(String, String)]
    var entries: [EditorialEntry] { collections.compactMap { key in EditorialEntry.all.first { $0.collection == key } } }
    static let all: [Self] = [
        .init(id: "office", title: "The modern office", subtitle: "Structure, softened.", collections: ["dry_4_1", "dry_5_1", "dry_6_1", "dry_3_1"], notes: [("Start with a column", "Choose a shirt and trousers in neighboring tones. A simple base lets one tailored layer do the work."), ("Make room for the commute", "Carry the warm layer you need outdoors, then remove it inside. In rain, choose closed water-resistant shoes over a decorative finish."), ("Keep one detail", "A belt, a watch or a small bag adds definition. Let the rest of the outfit feel quiet.")]),
        .init(id: "evening", title: "After the light fades", subtitle: "An evening with intention.", collections: ["dry_2_2", "dry_4_2", "dry_5_2", "dry_7_2"], notes: [("Dress for the journey", "Choose an outer layer that works with the silhouette beneath it. A beautiful coat can be part of the look."), ("Change the texture", "A fine knit, crisp cotton or fluid woven fabric creates interest within a restrained palette."), ("Remember the return", "Check the evening forecast before leaving. The temperature on the way home may call for an extra layer.")]),
        .init(id: "weekend", title: "A slower weekend", subtitle: "Easy pieces. Thoughtful proportions.", collections: ["dry_3_0", "dry_5_0", "dry_6_0", "dry_7_0"], notes: [("Balance the volume", "Pair a relaxed shirt with a cleaner trouser shape, or a compact top with a wider leg."), ("Repeat your favorites", "A familiar pair of comfortable shoes makes a good starting point. Build around pieces you enjoy wearing."), ("Bring the removable layer", "An overshirt or knit can travel in your bag. Choose the weight from the actual forecast.")]),
        .init(id: "carryon", title: "The carry-on edit", subtitle: "Less luggage. More ways to wear it.", collections: ["dry_4_0", "dry_5_1", "dry_6_2", "rain_4_1", "dry_7_0"], notes: [("Choose a small palette", "Start with two neutrals and one accent. Repeating colors makes it easier to combine fewer pieces."), ("Let layers cross occasions", "A simple shirt and a refined overshirt can work for travel, a casual dinner and a day in the city."), ("Pack for the full range", "Use the destination forecast, including wet and windy periods. Repeated outer layers do not replace fresh base layers or enough socks.")]),
        .init(id: "rain", title: "The rain issue", subtitle: "Prepared can be beautiful.", collections: ["rain_3_0", "rain_4_0", "rain_4_1", "rain_6_2", "rain_8_1"], notes: [("Start with function", "A suitable waterproof outer layer and grippy closed shoes come first. Check the care label and condition of your own pieces."), ("Keep the lower half practical", "Choose hems that stay clear of puddles and fabrics that suit the expected weather."), ("Choose the right extra", "An umbrella suits calmer rain. In strong wind, use a rain hood and follow local weather advice.")]),
        .init(id: "winter", title: "Winter, considered", subtitle: "Warmth with a clear silhouette.", collections: ["snow_1_0", "snow_2_1", "dry_1_0", "dry_0_0"], notes: [("Build from the inside", "Start with a comfortable base, then add an insulating midlayer and an outer layer suited to wind and precipitation."), ("Let the coat lead", "A simple palette beneath a substantial coat keeps the outfit coherent. Warmth and freedom of movement matter more than a narrow fit."), ("Finish at the edges", "Remember hands, head and feet. Ordinary fashion clothing is not specialist equipment for severe cold or remote outdoor travel.")]),
        .init(id: "linen", title: "Sun-washed linen", subtitle: "Lightness, without the rush.", collections: ["dry_7_0", "dry_7_1", "dry_8_0", "dry_9_0"], notes: [("Give fabric some air", "Loose, breathable pieces allow room to move. A light long sleeve can be useful when you want more coverage."), ("Keep the palette soft", "Ivory, sand and a muted accent make an easy foundation. Add texture through a woven bag or natural-looking fabric."), ("Plan around the heat", "Carry water and sun protection, seek shade and adjust your activity to local conditions. A photograph does not promise protection from heat.")]),
        .init(id: "active", title: "Move beautifully", subtitle: "Comfort sets the pace.", collections: ["dry_2_3", "dry_4_3", "dry_6_3", "dry_7_3", "dry_9_3"], notes: [("Choose the route first", "Shoes and layers should suit the surface, duration and weather. Editorial looks are inspiration for everyday activity."), ("Make the layer removable", "A quick-drying top and an easy outer layer let you adjust as you warm up or stop."), ("Leave room to change plans", "Check storms, extreme temperatures and local warnings. In hot weather, choose cooler hours and take breaks.")])
    ]
}

struct EditorialLibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var library = false
    @State private var weather = "All"
    @State private var occasion = "All"
    @State private var band = -1
    @State private var favoritesOnly = false
    @State private var selection: EditorialEntry?
    private var entries: [EditorialEntry] { EditorialEntry.all.filter { (weather == "All" || $0.weather == weather.lowercased()) && (occasion == "All" || $0.occasion == occasion) && (band == -1 || $0.band == band) && (!favoritesOnly || model.editorialFavorites.contains($0.id)) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "The Pro editorial collection", title: "Good looks.\nEvery forecast.")
                Picker("Editorial collection", selection: $library) { Text("The style guides").tag(false); Text("All photographs").tag(true) }.pickerStyle(.segmented)
                if library {
                    HStack { Picker("Weather", selection: $weather) { ForEach(["All", "Dry", "Rain", "Snow"], id: \.self) { Text($0).tag($0) } }; Picker("Occasion", selection: $occasion) { ForEach(["All"] + FashionStyle.allCases.map(\.rawValue), id: \.self) { Text($0).tag($0) } } }
                    Picker("Temperature", selection: $band) { Text("All temperature ranges").tag(-1); ForEach(TemperatureBand.allCases, id: \.rawValue) { Text($0.range).tag($0.rawValue) } }
                    Toggle("Only my saved photographs", isOn: $favoritesOnly).font(.caption)
                    Text("\(entries.count) editorial photographs · inspiration, not a live forecast").font(.caption).foregroundStyle(Theme.muted)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 22) { ForEach(entries) { entry in
                        Button { selection = entry } label: { VStack(alignment: .leading, spacing: 9) { Image(entry.id).resizable().aspectRatio(3.0 / 4.0, contentMode: .fit).clipShape(.rect(cornerRadius: 18)); Text(entry.occasion).font(.caption.bold()); Text(entry.range).font(.caption2).foregroundStyle(Theme.muted) } }.buttonStyle(.plain)
                    } }
                    if entries.isEmpty { ContentUnavailableView("A little room for inspiration", systemImage: "bookmark", description: Text("Try different filters, or save photographs from the collection.")) }
                } else {
                    ForEach(StyleEdit.all) { edit in NavigationLink { StyleGuideView(edit: edit) } label: { VStack(alignment: .leading, spacing: 13) {
                        if let entry = edit.entries.first { EditorialPhoto(name: entry.id, height: 230).clipShape(.rect(cornerRadius: 25)) }
                        HStack { VStack(alignment: .leading, spacing: 6) { Text(edit.title).font(Theme.editorial(29)); Text(edit.subtitle).font(.caption).foregroundStyle(Theme.muted) }; Spacer(); Image(systemName: "arrow.up.right") }
                    } }.buttonStyle(.plain).padding(.bottom, 8) }
                }
            }.padding(24).frame(maxWidth: 850).frame(maxWidth: .infinity)
        }.pageBackground().navigationTitle("The editorial library").navigationBarTitleDisplayMode(.inline).sheet(item: $selection) { EditorialDetailView(entry: $0) }
    }
}
struct StyleGuideView: View {
    let edit: StyleEdit
    @State private var selected: EditorialEntry?
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 26) {
            PageHeading(eyebrow: edit.subtitle, title: edit.title)
            ForEach(Array(edit.notes.enumerated()), id: \.offset) { index, note in VStack(alignment: .leading, spacing: 10) { Eyebrow(text: "Note \(index + 1)"); Text(note.0).font(Theme.editorial(28)); Text(note.1).font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(5) }.glassCard() }
            Eyebrow(text: "The visual edit")
            ForEach(edit.entries) { entry in Button { selected = entry } label: { VStack(alignment: .leading, spacing: 12) { Image(entry.id).resizable().aspectRatio(3.0 / 4.0, contentMode: .fit).clipShape(.rect(cornerRadius: 25)); Text("\(entry.range) · \(entry.weather.capitalized)").font(.caption).foregroundStyle(Theme.muted) } }.buttonStyle(.plain) }
        }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity) }.pageBackground().navigationTitle(edit.title).navigationBarTitleDisplayMode(.inline).sheet(item: $selected) { EditorialDetailView(entry: $0) }
    }
}
struct EditorialDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let entry: EditorialEntry
    @State private var adapt = false
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 23) {
                Image(entry.id).resizable().aspectRatio(3.0 / 4.0, contentMode: .fit).clipShape(.rect(cornerRadius: 28))
                PageHeading(eyebrow: "Editorial inspiration · \(entry.weather)", title: "\(entry.occasion),\nconsidered.")
                Text("\(entry.range). A fictional couple, a considered palette and a starting point for your own wardrobe. This photograph is editorial inspiration; follow your actual forecast and clothing checklist when choosing layers.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(5)
                Button { if model.editorialFavorites.contains(entry.id) { model.editorialFavorites.remove(entry.id) } else { model.editorialFavorites.insert(entry.id) } } label: { Label(model.editorialFavorites.contains(entry.id) ? "Saved to your collection" : "Save this inspiration", systemImage: model.editorialFavorites.contains(entry.id) ? "bookmark.fill" : "bookmark").frame(maxWidth: .infinity) }.buttonStyle(.glass)
                if model.current != nil { Button("Adapt this occasion to my weather") { adapt = true }.buttonStyle(.borderedProminent).foregroundStyle(.white) }
            }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity) }.pageBackground().navigationTitle("The visual edit").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $adapt) { if let weather = model.current { OutfitDetailView(conditions: weather, style: entry.style) } }
        }
    }
}
