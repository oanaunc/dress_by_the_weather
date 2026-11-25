import SwiftUI
import WeatherStyle

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var showLocations = false
    @State private var detail: DetailSelection?
    @State private var selectedHour = 0.0
    @State private var feedbackMessage: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(text: "Your daily style forecast")
                        Button { showLocations = true } label: { HStack(spacing: 6) { Text(model.city.name).font(Theme.editorial(32)); Image(systemName: "chevron.down").font(.caption) } }.accessibilityIdentifier("chooseLocation")
                    }
                    Spacer()
                    Button { Task { await model.refresh() } } label: { if model.loading { ProgressView() } else { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) } }.buttonStyle(.glass).disabled(model.loading).accessibilityLabel("Refresh weather")
                }
                if let forecast = model.forecast, forecast.isPreview {
                    HStack { Label("Sample forecast · not live weather", systemImage: "eye").font(.caption); Spacer(); Button("Go live") { Task { await model.refresh() } }.font(.caption.bold()) }.padding(12).background(Theme.sand.opacity(0.45), in: .rect(cornerRadius: 16)).accessibilityIdentifier("previewBanner")
                }
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.red.opacity(0.06), in: .rect(cornerRadius: 14)) }
                if let conditions = model.current, let outfit = model.recommendation {
                    weatherHeader(conditions)
                    Button { detail = .init(conditions: conditions, style: model.style) } label: {
                        OutfitArtwork(outfit: outfit, height: 465)
                            .overlay(alignment: .bottomLeading) { Text("\(model.style.rawValue.uppercased())  /  \(outfit.band.range)").font(.system(size: 9, design: .monospaced)).tracking(1).padding(12).background(.regularMaterial, in: Capsule()).padding(16) }
                            .overlay(alignment: .bottomTrailing) { Image(systemName: "arrow.up.right").padding(17).glassEffect(.regular, in: Circle()).padding(16) }
                    }.buttonStyle(.plain).accessibilityIdentifier("todayOutfit")
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "What to wear today")
                        Text(outfit.title).font(Theme.editorial(36))
                        Text(outfit.items.map(\.name).joined(separator: ", ") + ".").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(5)
                    }
                    StylePicker()
                    if let caution = outfit.caution { Label(caution, systemImage: "exclamationmark.triangle").font(.subheadline).padding(16).background(.orange.opacity(0.12), in: .rect(cornerRadius: 20)) }
                    essentials(outfit)
                    if !model.upcoming.isEmpty { timeline }
                    hourly
                    conditionsGrid(conditions)
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "Make it feel like you")
                        Text("How do these layers feel?").font(Theme.editorial(26))
                        HStack {
                            ForEach([("Too cold", 1.0), ("Just right", 0), ("Too warm", -1)], id: \.0) { label, amount in
                                Button(label) { model.feedback(amount); feedbackMessage = amount == 0 ? "Perfect. Your comfort profile stays as it is." : "Saved. Future outfits will use \(amount > 0 ? "warmer" : "lighter") layers." }.buttonStyle(.glass).font(.caption)
                            }
                        }
                        if let feedbackMessage { Text(feedbackMessage).font(.caption).foregroundStyle(Theme.olive) }
                    }.glassCard()
                    if let forecast = model.forecast {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(forecast.isPreview ? "Sample edition" : "Forecast updated") · \(model.time(forecast.updatedAt, format: "MMM d, HH:mm"))").font(.caption2)
                            Text("Feels-like temperatures are estimates. Check local official alerts before outdoor plans.").font(.caption2)
                        }.foregroundStyle(Theme.muted)
                    }
                    AttributionView()
                } else { EmptyWeather() }
            }.padding(22).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.pageBackground().toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.refresh() }
            .sheet(isPresented: $showLocations) { LocationSheet(onSelect: { city in Task { await model.select(city) } }) }
            .sheet(item: $detail) { selection in OutfitDetailView(conditions: selection.conditions, style: selection.style) }
    }
    private func weatherHeader(_ conditions: Conditions) -> some View {
        HStack(alignment: .center) {
            Text(model.temperature(conditions.temperature)).font(.system(size: 100, weight: .ultraLight, design: .serif)).tracking(-7).minimumScaleFactor(0.5)
            Spacer()
            VStack(alignment: .trailing, spacing: 9) {
                WeatherSymbol(name: conditions.icon, size: 36)
                Text(conditions.label).font(.subheadline)
                Text("Feels like ≈ \(model.temperature(conditions.apparentTemperature))").font(.caption).foregroundStyle(Theme.muted)
                if let day = model.days.first { Text("H: \(model.temperature(day.high))  L: \(model.temperature(day.low))").font(.caption).foregroundStyle(Theme.muted) }
            }
        }.padding(.vertical, -7)
    }
    private func essentials(_ outfit: Outfit) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Eyebrow(text: "Wear this. Bring that."); Spacer(); Image(systemName: "bag") }
            ForEach(outfit.items.prefix(3)) { item in
                HStack(spacing: 14) {
                    Image(systemName: UIImage(systemName: item.icon) != nil ? item.icon : "tshirt").font(.title3).frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) { Text(item.name).font(.subheadline); Text(item.fabric).font(.caption).foregroundStyle(Theme.muted) }
                    Spacer()
                }
            }
            if !outfit.bring.isEmpty { Divider(); Text("TAKE WITH YOU").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5); Text(outfit.bring.joined(separator: "  ·  ")).font(.subheadline).foregroundStyle(Theme.olive) }
        }.glassCard()
    }
    private var timeline: some View {
        let hours = Array(model.upcoming.prefix(24))
        let index = min(Int(selectedHour), max(0, hours.count - 1))
        let hour = hours[index]
        let look = OutfitEngine.recommend(hour.conditions, style: model.style, comfort: model.comfort)
        return VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "The day, dressed")
            HStack { Text(model.time(hour.date)).font(Theme.editorial(32)); Spacer(); WeatherSymbol(name: hour.conditions.icon); Text(model.temperature(hour.conditions.temperature)).font(Theme.editorial(32)) }
            Text(look.items.first?.name ?? "Light layers").font(.subheadline)
            if hours.count > 1 { Slider(value: $selectedHour, in: 0...Double(hours.count - 1), step: 1).tint(Theme.olive).accessibilityLabel("Explore outfits through the day") }
            HStack { Text(model.time(hours[0].date)); Spacer(); Text(model.time(hours[hours.count - 1].date)) }.font(.caption2).foregroundStyle(Theme.muted)
        }.glassCard()
    }
    private var hourly: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Eyebrow(text: "The next 24 hours"); Spacer(); NavigationLink("All days") { ForecastView() }.font(.caption) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(model.upcoming.prefix(24)) { hour in
                        Button { detail = .init(conditions: hour.conditions, style: model.style) } label: {
                            VStack(spacing: 13) { Text(model.time(hour.date)).font(.caption2); WeatherSymbol(name: hour.conditions.icon, size: 23); Text(model.temperature(hour.conditions.temperature)).font(.subheadline); Text("\(hour.conditions.windKmh.formatted(.number.precision(.fractionLength(0)))) km/h").font(.system(size: 9)).foregroundStyle(Theme.muted) }
                        }.buttonStyle(.plain)
                    }
                }.padding(.vertical, 6)
            }
        }.glassCard()
    }
    private func conditionsGrid(_ conditions: Conditions) -> some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            metric("WIND", "\(Int(conditions.windKmh.rounded()))", "km/h · consider a wind layer", "wind")
            metric("HUMIDITY", "\(Int(conditions.humidity.rounded()))%", "Choose breathable fabrics", "humidity")
            metric("PRECIPITATION", String(format: "%.1f mm", conditions.precipitationMm), "Over the next forecast interval", "drop")
            metric("FEELS LIKE", "≈ " + model.temperature(conditions.apparentTemperature), "Estimated for the shade", "thermometer.medium")
        }
    }
    private func metric(_ title: String, _ value: String, _ note: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 13) { HStack { Image(systemName: symbol); Text(title).font(.system(size: 9, design: .monospaced)).tracking(1) }; Text(value).font(Theme.editorial(29)).minimumScaleFactor(0.6); Text(note).font(.caption2).foregroundStyle(Theme.muted) }.frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading).glassCard()
    }
}
struct DetailSelection: Identifiable { let id = UUID(); let conditions: Conditions; let style: FashionStyle }
struct StylePicker: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(FashionStyle.allCases) { style in
                    Button { withAnimation { model.style = style } } label: { Label(style.rawValue, systemImage: style.icon).font(.caption).padding(.vertical, 12).padding(.horizontal, 14).background(model.style == style ? Theme.ink : .white.opacity(0.6), in: Capsule()).foregroundStyle(model.style == style ? .white : Theme.ink) }.buttonStyle(.plain).accessibilityAddTraits(model.style == style ? .isSelected : [])
                }
            }
        }
    }
}
