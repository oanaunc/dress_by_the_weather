import SwiftUI
import WeatherStyle

enum Theme {
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let ink = Color(red: 0.16, green: 0.20, blue: 0.19)
    static let muted = Color(red: 0.43, green: 0.45, blue: 0.41)
    static let olive = Color(red: 0.42, green: 0.47, blue: 0.36)
    static let sand = Color(red: 0.89, green: 0.86, blue: 0.78)
    static func editorial(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
}
extension View {
    func glassCard() -> some View {
        self.padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26)).overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.8), lineWidth: 1))
    }
    func pageBackground() -> some View { self.background(Theme.paper.ignoresSafeArea()) }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(Theme.muted) }
}
struct PageHeading: View {
    let eyebrow: String
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { Eyebrow(text: eyebrow); Text(title).font(Theme.editorial(40)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct WeatherSymbol: View {
    let name: String
    var size: CGFloat = 28
    var body: some View { Image(systemName: name).symbolRenderingMode(.multicolor).font(.system(size: size, weight: .light)).accessibilityHidden(true) }
}
struct OutfitArtwork: View {
    let outfit: Outfit
    var height: CGFloat = 340
    var variant: Int = Calendar.current.ordinality(of: .day, in: .era, for: Date())! % 4
    var fullLength = false
    private var asset: String? {
        guard let base = outfit.imageName else { return nil }
        // Some generated collections failed visual review. Use a reviewed look
        // for the same weather and temperature rather than unsuitable footwear.
        let replacements = ["couple_rain_4_2": "couple_rain_4_1",
                            "couple_rain_6_0": "couple_rain_6_2",
                            "couple_rain_8_0": "couple_rain_8_1",
                            "couple_rain_8_2": "couple_rain_8_1"]
        for candidate in [base, replacements[base]].compactMap({ $0 }) {
            for offset in 0..<4 {
                let name = "\(candidate)_\((variant + offset) % 4)"
                if UIImage(named: name) != nil { return name }
            }
        }
        return nil
    }
    var body: some View {
        Group {
            if let name = asset {
                if fullLength {
                    Image(name).resizable().aspectRatio(3.0 / 4.0, contentMode: .fit)
                } else {
                    Image(name).resizable().scaledToFill().frame(height: height, alignment: .top).clipped()
                }
            } else {
                ZStack {
                    LinearGradient(colors: [Theme.sand.opacity(0.65), .white, Theme.olive.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Circle().fill(.white.opacity(0.55)).frame(width: 230, height: 230).blur(radius: 30).offset(x: 70, y: -70)
                    VStack(spacing: 18) {
                        Eyebrow(text: outfit.band.range)
                        HStack(spacing: 20) {
                            ForEach(outfit.items.prefix(3)) { item in
                                Image(systemName: UIImage(systemName: item.icon) != nil ? item.icon : "tshirt").font(.system(size: 46, weight: .ultraLight)).foregroundStyle(Theme.ink.opacity(0.65))
                            }
                        }
                        Text(outfit.items.first?.name ?? "Your daily layers").font(Theme.editorial(27)).multilineTextAlignment(.center)
                        Text("YOUR WEATHER, TRANSLATED INTO CLOTHES").font(.system(size: 8, design: .monospaced)).tracking(1.5).foregroundStyle(Theme.muted)
                    }.padding(24)
                }.frame(height: height)
            }
        }.frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 28))
    }
}
struct AttributionView: View {
    var body: some View {
        VStack(spacing: 7) {
            Link("Weather data: MET Norway", destination: URL(string: "https://www.met.no/en")!)
            HStack(spacing: 12) {
                Link("CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                Text("Daily ranges & clothing advice by this app")
            }.font(.caption2)
        }.font(.caption).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).padding(.vertical, 18)
    }
}
struct EmptyWeather: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "cloud.sun").font(.system(size: 60, weight: .ultraLight)).foregroundStyle(Theme.olive)
            Text("A forecast for\nyour wardrobe.").font(Theme.editorial(36)).multilineTextAlignment(.center)
            Text(model.error ?? "Get the latest forecast to find your perfect layers.").font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Button { Task { await model.refresh() } } label: { if model.loading { ProgressView() } else { Label("Load free weather", systemImage: "arrow.clockwise") } }.buttonStyle(.borderedProminent).foregroundStyle(.white).disabled(model.loading)
            Button("Explore a sample forecast") { model.showPreview() }.font(.subheadline)
        }.padding(32).frame(maxWidth: .infinity, minHeight: 400).glassCard()
    }
}
