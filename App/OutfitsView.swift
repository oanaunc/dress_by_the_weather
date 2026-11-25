import SwiftUI
import WeatherStyle

struct OutfitDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let conditions: Conditions
    let style: FashionStyle
    @State private var saved = false
    @State private var profile = "Both"
    @State private var adjustment = 0.0
    @State private var variant = 0
    private var look: Outfit { OutfitEngine.recommend(conditions, style: style, comfort: model.comfort + adjustment) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    OutfitArtwork(outfit: look, height: 380, variant: variant)
                    Button { withAnimation { variant = (variant + 1) % 4 } } label: { Label("Another look", systemImage: "shuffle").frame(maxWidth: .infinity) }.buttonStyle(.glass)
                    PageHeading(eyebrow: "\(style.rawValue) · \(look.band.range)", title: look.title)
                    Picker("Outfit profile", selection: $profile) { Text("Both").tag("Both"); Text("Women").tag("Women"); Text("Men").tag("Men") }.pickerStyle(.segmented)
                    Text(profile == "Both" ? "A coordinated foundation for both wardrobes." : "A \(profile.lowercased())’s outfit foundation. Adapt the fit and silhouette to your taste.").font(.caption).foregroundStyle(Theme.muted)
                    ForEach(look.items) { item in
                        HStack(spacing: 18) {
                            Image(systemName: UIImage(systemName: item.icon) != nil ? item.icon : "tshirt").font(.system(size: 28, weight: .ultraLight)).frame(width: 45, height: 55).background(Theme.sand.opacity(0.3), in: .rect(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 5) { Eyebrow(text: item.category); Text(personalized(item.name)).font(.subheadline); Text(item.fabric).font(.caption).foregroundStyle(Theme.muted) }
                            Spacer()
                        }
                    }
                    if !look.bring.isEmpty { VStack(alignment: .leading, spacing: 10) { Eyebrow(text: "A few things to bring"); Text(look.bring.joined(separator: " · ")).font(.subheadline).lineSpacing(5) }.glassCard() }
                    VStack(alignment: .leading, spacing: 12) { Eyebrow(text: "Why this works"); Text(look.explanation).font(.subheadline).lineSpacing(5); if let caution = look.caution { Label(caution, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) } }.glassCard()
                    HStack { Button("Warmer") { adjustment = min(6, adjustment + 3) }.buttonStyle(.glass); Button("Lighter") { adjustment = max(-6, adjustment - 3) }.buttonStyle(.glass); Spacer(); if adjustment != 0 { Button("Reset") { adjustment = 0 }.font(.caption) } }
                    Button { model.saveLook(conditions, style: style); saved = true } label: { Label(saved ? "Saved to your looks" : "Save this look", systemImage: saved ? "checkmark" : "bookmark").padding(8).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).disabled(saved).accessibilityIdentifier("saveLook")
                    ShareLink(item: "\(look.title) — Dress by the Weather\n\(look.items.map(\.name).joined(separator: ", "))\nBring: \(look.bring.joined(separator: ", "))") { Label("Share the outfit checklist", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.font(.subheadline)
                    Text("Styling guidance for adults. These are suggested layers, not a guarantee of comfort or protection.").font(.caption2).foregroundStyle(Theme.muted)
                }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
            }.pageBackground().navigationTitle("The outfit edit").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func personalized(_ name: String) -> String {
        if profile == "Men" { return name.replacingOccurrences(of: " / midi skirt", with: "").replacingOccurrences(of: " / airy dress", with: "").replacingOccurrences(of: " / airy blouse", with: "").replacingOccurrences(of: " / shorts", with: " / tailored shorts") }
        return name
    }
}

struct LooksView: View {
    @Environment(AppModel.self) private var model
    @State private var savedOnly = false
    @State private var detail: DetailSelection?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "A wardrobe, weather considered", title: "The looks edit.")
                Picker("Collection", selection: $savedOnly) { Text("For today").tag(false); Text("Saved looks").tag(true) }.pickerStyle(.segmented)
                if savedOnly {
                    if model.savedLooks.isEmpty { ContentUnavailableView("Your personal collection", systemImage: "bookmark", description: Text("Save a look to keep its clothing checklist here.")) }
                    ForEach(model.savedLooks) { saved in
                        let outfit = OutfitEngine.recommend(saved.conditions, style: saved.style, comfort: saved.comfort)
                        VStack(alignment: .leading, spacing: 14) {
                            Button { detail = .init(conditions: saved.conditions, style: saved.style) } label: { OutfitArtwork(outfit: outfit, height: 220) }.buttonStyle(.plain)
                            HStack { VStack(alignment: .leading, spacing: 5) { Eyebrow(text: "\(saved.city) · \(saved.style.rawValue)"); Text(outfit.title).font(Theme.editorial(25)) }; Spacer(); Button(role: .destructive) { model.savedLooks.removeAll { $0.id == saved.id } } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("Delete saved look") }
                        }
                    }
                } else if let conditions = model.current {
                    Text("Four ways to dress for the same forecast. Choose the occasion; we’ll consider the layers.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(5)
                    ForEach(FashionStyle.allCases) { style in
                        let outfit = OutfitEngine.recommend(conditions, style: style, comfort: model.comfort)
                        Button { detail = .init(conditions: conditions, style: style) } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                OutfitArtwork(outfit: outfit, height: 230)
                                HStack { VStack(alignment: .leading, spacing: 6) { Eyebrow(text: style.rawValue); Text(outfit.items.first?.name ?? "Your everyday layers").font(Theme.editorial(28)) }; Spacer(); Image(systemName: "arrow.up.right") }
                                Text(outfit.items.map(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                            }
                        }.buttonStyle(.plain).padding(.bottom, 12)
                    }
                } else { EmptyWeather() }
            }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.pageBackground().toolbar(.hidden, for: .navigationBar).sheet(item: $detail) { selection in OutfitDetailView(conditions: selection.conditions, style: selection.style) }
    }
}
