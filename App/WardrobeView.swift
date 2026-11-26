import SwiftUI
import PhotosUI
import WeatherStyle

struct GarmentThumbnail: View {
    let garment: Garment
    var body: some View {
        Group {
            if let filename = garment.photoFilename, let image = UIImage(contentsOfFile: AppModel.wardrobePhotoDirectory.appending(path: filename).path) { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: UIImage(systemName: garment.category.icon) != nil ? garment.category.icon : "tshirt").font(.title2).foregroundStyle(Theme.olive) }
        }.frame(width: 62, height: 78).background(Theme.sand.opacity(0.3), in: .rect(cornerRadius: 13)).accessibilityHidden(true)
    }
}
struct WardrobeView: View {
    @Environment(AppModel.self) private var model
    @State private var adding = false
    @State private var editing: Garment?
    var body: some View {
        List {
            Section {
                PageHeading(eyebrow: "The clothes you already love", title: "Your own\nwardrobe.").padding(.vertical, 14)
                Text("A private collection on this device. Add pieces, choose their comfortable temperatures and mark what’s ready to wear.").font(.subheadline).foregroundStyle(Theme.muted)
                Button { adding = true } label: { Label("Add a piece", systemImage: "plus") }.accessibilityIdentifier("addGarment")
            }.listRowBackground(Color.clear)
            Section("Your pieces · \(model.wardrobe.count)") {
                if model.wardrobe.isEmpty { Text("Start with a coat, a favorite shirt and your most comfortable shoes.").font(.subheadline).foregroundStyle(Theme.muted) }
                ForEach(model.wardrobe) { garment in
                    Button { editing = garment } label: {
                        HStack(spacing: 15) {
                            GarmentThumbnail(garment: garment)
                            VStack(alignment: .leading, spacing: 6) { Text(garment.name).font(Theme.editorial(24)); Text([garment.category.rawValue, garment.color].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(Theme.muted); Text(garment.available ? "Ready to wear" : "In the laundry").font(.caption2).foregroundStyle(garment.available ? Theme.olive : Theme.muted) }
                            Spacer(); Image(systemName: "chevron.right").font(.caption)
                        }.padding(.vertical, 4)
                    }.buttonStyle(.plain)
                }.onDelete { offsets in let removed = offsets.map { model.wardrobe[$0] }; for garment in removed { model.removeGarment(garment) } }
            }
            if let weather = model.current, !model.wardrobe.isEmpty {
                let outfit = OutfitEngine.recommend(weather, style: model.style, comfort: model.comfort)
                Section {
                    ForEach(WardrobeMatcher.match(outfit, weather: weather, garments: model.wardrobe)) { match in
                        HStack(spacing: 15) {
                            if let garment = match.garment { GarmentThumbnail(garment: garment) }
                            else { Image(systemName: "plus.circle.dashed").font(.title2).frame(width: 62, height: 60).foregroundStyle(Theme.muted) }
                            VStack(alignment: .leading, spacing: 6) { Eyebrow(text: match.garment == nil ? "An idea to add" : "From your wardrobe"); Text(match.name).font(.subheadline); Text(match.suggested.category).font(.caption).foregroundStyle(Theme.muted) }
                        }.padding(.vertical, 5)
                    }
                } header: { Text("For today in \(model.city.name)") } footer: { Text("Matches consider your comfort ranges, occasion, ready-to-wear status and rain-ready setting. Add only ranges that feel right for you.") }
            }
        }.scrollContentBackground(.hidden).pageBackground().navigationTitle("Your wardrobe").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $adding) { GarmentEditor(garment: Garment(name: "", category: .top)) }
            .sheet(item: $editing) { garment in GarmentEditor(garment: garment) }
    }
}
struct GarmentEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var garment: Garment
    @State private var selection: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var loadingPhoto = false
    @State private var error: String?
    @State private var confirmDelete = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Your piece") {
                    TextField("Name, e.g. cream linen shirt", text: $garment.name).accessibilityIdentifier("garmentName")
                    Picker("Category", selection: $garment.category) { ForEach(GarmentCategory.allCases) { category in Text(category.rawValue).tag(category) } }
                    TextField("Color or pattern", text: $garment.color)
                    PhotosPicker(selection: $selection, matching: .images) { Label("Choose an optional photo", systemImage: "photo") }.disabled(loadingPhoto)
                    if loadingPhoto { ProgressView("Preparing photo…") }
                    if let photoData, let image = UIImage(data: photoData) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200).frame(maxWidth: .infinity) }
                    else if garment.photoFilename != nil { GarmentThumbnail(garment: garment) }
                }
                Section {
                    VStack(alignment: .leading) { Text("Comfortable from \(model.temperature(garment.minimumTemperature))"); Slider(value: $garment.minimumTemperature, in: -25...45, step: 1).onChange(of: garment.minimumTemperature) { if garment.maximumTemperature < garment.minimumTemperature { garment.maximumTemperature = garment.minimumTemperature } } }
                    VStack(alignment: .leading) { Text("Comfortable up to \(model.temperature(garment.maximumTemperature))"); Slider(value: $garment.maximumTemperature, in: -25...45, step: 1).onChange(of: garment.maximumTemperature) { if garment.minimumTemperature > garment.maximumTemperature { garment.minimumTemperature = garment.maximumTemperature } } }
                    Toggle("Suitable for rain or snow", isOn: $garment.waterResistant)
                    Toggle("Ready to wear", isOn: $garment.available)
                } header: { Text("When you wear it") } footer: { Text("Choose your own estimated feels-like comfort range. Mark outerwear and shoes as rain-ready only when they suit wet conditions.") }
                Section("Occasions") {
                    ForEach(FashionStyle.allCases) { style in Toggle(style.rawValue, isOn: Binding(get: { garment.occasions.contains(style) }, set: { if $0 { garment.occasions.insert(style) } else { garment.occasions.remove(style) } })) }
                }
                if let error { Section { Text(error).font(.caption).foregroundStyle(.red) } }
                if model.wardrobe.contains(where: { $0.id == garment.id }) { Section { Button("Delete this piece", role: .destructive) { confirmDelete = true } } }
                Section { Text("Photos are saved only in this app on your device. They aren’t uploaded for AI analysis.").font(.caption).foregroundStyle(Theme.muted) }
            }.scrollContentBackground(.hidden).pageBackground().navigationTitle("A wardrobe piece").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save piece") { do { try model.saveGarment(garment, photoData: photoData); dismiss() } catch { self.error = "The piece couldn’t be saved. Please try again." } }.disabled(garment.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || garment.occasions.isEmpty || loadingPhoto).accessibilityIdentifier("saveGarment") }
                }.confirmationDialog("Delete this piece and its saved photo?", isPresented: $confirmDelete) { Button("Delete piece", role: .destructive) { model.removeGarment(garment); dismiss() } }
                .onChange(of: selection) { Task {
                    loadingPhoto = true; error = nil
                    do { guard let data = try await selection?.loadTransferable(type: Data.self), UIImage(data: data) != nil else { throw CocoaError(.fileReadCorruptFile) }; photoData = data }
                    catch { self.error = "That photo couldn’t be loaded. Try another image." }
                    loadingPhoto = false
                } }
        }
    }
}
