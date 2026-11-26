import SwiftUI
import WeatherStyle

struct WeeklyPlannerView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "\(model.city.name) · Your next seven forecast days", title: "A week,\nwell dressed.")
                if model.forecast?.isPreview == true { Label("Sample forecast · not live weather", systemImage: "eye").font(.caption).foregroundStyle(Theme.olive) }
                Text("Give each day an occasion. Your outfit follows its forecast; your choices stay saved for this city.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(4)
                if model.days.isEmpty { EmptyWeather() }
                ForEach(Array(model.days.prefix(7))) { day in WeeklyDayCard(day: day) }
            }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.pageBackground().navigationTitle("Dress the week").navigationBarTitleDisplayMode(.inline)
    }
}
private struct WeeklyDayCard: View {
    @Environment(AppModel.self) private var model
    let day: ForecastDay
    @State private var detail = false
    private var plan: PlannedOutfit? { model.plannedOutfit(for: day.date) }
    private var occasion: FashionStyle { plan?.style ?? model.style }
    private var variant: Int { plan?.variant ?? 0 }
    private var outfit: Outfit { OutfitEngine.recommend(day.representative.conditions, style: occasion, comfort: model.comfort) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { VStack(alignment: .leading, spacing: 5) { Text(model.time(day.date, format: "EEEE")).font(Theme.editorial(30)); Text(model.time(day.date, format: "d MMM")).font(.caption).foregroundStyle(Theme.muted) }; Spacer(); WeatherSymbol(name: day.representative.conditions.icon); Text("\(model.temperature(day.low)) / \(model.temperature(day.high))").font(.subheadline) }
            Button { detail = true } label: { OutfitArtwork(outfit: outfit, height: 210, variant: variant) }.buttonStyle(.plain)
            Picker("Occasion for \(model.time(day.date, format: "EEEE"))", selection: Binding(get: { occasion }, set: { model.planOutfit(date: day.date, style: $0, variant: variant) })) { ForEach(FashionStyle.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            Text(outfit.items.map(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(Theme.muted)
            HStack {
                Button { model.planOutfit(date: day.date, style: occasion, variant: variant) } label: {
                    Label(plan == nil ? "Save this day" : "Day saved", systemImage: plan == nil ? "calendar.badge.plus" : "checkmark.circle")
                        .frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("savePlannedDay")
                Spacer()
                Button("Change look", systemImage: "shuffle") { model.planOutfit(date: day.date, style: occasion, variant: (variant + 1) % 4) }
                if plan != nil { Button { model.clearPlan(date: day.date) } label: { Image(systemName: "xmark.circle") }.accessibilityLabel("Clear this day’s plan") }
            }.font(.caption)
        }.glassCard().sheet(isPresented: $detail) { OutfitDetailView(conditions: day.representative.conditions, style: occasion) }
    }
}
