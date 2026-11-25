import SwiftUI
import Charts
import WeatherStyle

struct ForecastView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedDay: DaySelection?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: "\(model.city.name) · the days ahead", title: "Forecast your\nwardrobe.")
                if model.forecast?.isPreview == true { Label("Sample forecast · not live weather", systemImage: "eye").font(.caption).foregroundStyle(Theme.olive) }
                if model.forecast != nil {
                    if let day = model.days.dropFirst().first {
                        OutfitArtwork(outfit: OutfitEngine.recommend(day.representative.conditions, style: model.style, comfort: model.comfort), height: 240, variant: 1)
                            .overlay(alignment: .bottomLeading) { Text("TOMORROW’S EDIT").font(.system(size: 9, design: .monospaced)).tracking(1.5).padding(12).background(.regularMaterial, in: Capsule()).padding(14) }
                    }
                    Text("Hourly detail first. A wider view after that. Tap a day for its weather and layers.").font(.subheadline).foregroundStyle(Theme.muted).lineSpacing(5)
                    if !model.upcoming.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Eyebrow(text: "Temperature · next 48 hours")
                            Chart(Array(model.upcoming.prefix(48))) { hour in
                                AreaMark(x: .value("Time", hour.date), y: .value("Temperature", model.fahrenheit ? hour.conditions.temperature * 9/5 + 32 : hour.conditions.temperature)).foregroundStyle(LinearGradient(colors: [Theme.olive.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                                LineMark(x: .value("Time", hour.date), y: .value("Temperature", model.fahrenheit ? hour.conditions.temperature * 9/5 + 32 : hour.conditions.temperature)).foregroundStyle(Theme.olive).interpolationMethod(.catmullRom)
                            }.frame(height: 155).chartXAxis { AxisMarks(values: .stride(by: .hour, count: 12)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.hour(), centered: true) } }.environment(\.timeZone, model.city.timeZone).accessibilityLabel("Temperature forecast for the next 48 hours")
                        }.glassCard()
                    }
                    VStack(spacing: 0) {
                        ForEach(model.days) { day in
                            Button { selectedDay = .init(day: day) } label: {
                                HStack(spacing: 15) {
                                    VStack(alignment: .leading, spacing: 5) { Text(model.time(day.date, format: "EEE")).font(.subheadline.bold()); Text(model.time(day.date, format: "MMM d")).font(.caption2).foregroundStyle(Theme.muted) }.frame(width: 54, alignment: .leading)
                                    WeatherSymbol(name: day.representative.conditions.icon, size: 24).frame(width: 28)
                                    VStack(alignment: .leading, spacing: 6) { Text(OutfitEngine.recommend(day.representative.conditions, style: model.style, comfort: model.comfort).items.first?.name ?? "Light layers").font(.caption); HStack { Text(model.temperature(day.low)); Capsule().fill(LinearGradient(colors: [Theme.olive.opacity(0.4), .orange.opacity(0.7)], startPoint: .leading, endPoint: .trailing)).frame(height: 4); Text(model.temperature(day.high)) }.font(.caption2).foregroundStyle(Theme.muted) }
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.muted)
                                }.padding(.vertical, 18)
                            }.buttonStyle(.plain)
                            if day.id != model.days.last?.id { Divider() }
                        }
                    }.glassCard()
                    Text("Daily high / low values are ranges across available forecast samples. Today may cover only the remaining hours. Later dates use six-hour intervals, so brief changes may not appear.").font(.caption2).foregroundStyle(Theme.muted).lineSpacing(3)
                    AttributionView()
                } else { EmptyWeather() }
            }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.pageBackground().navigationBarTitleDisplayMode(.inline).sheet(item: $selectedDay) { selected in DayDetailView(day: selected.day) }
    }
}
struct DaySelection: Identifiable { let id = UUID(); let day: ForecastDay }
struct DayDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let day: ForecastDay
    @State private var detail: DetailSelection?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeading(eyebrow: model.city.name, title: model.time(day.date, format: "EEEE, MMM d"))
                    OutfitArtwork(outfit: OutfitEngine.recommend(day.representative.conditions, style: model.style, comfort: model.comfort), height: 240)
                    ForEach(day.hours) { hour in
                        Button { detail = .init(conditions: hour.conditions, style: model.style) } label: {
                            HStack(spacing: 15) {
                                Text(model.time(hour.date)).font(.caption).frame(width: 55)
                                WeatherSymbol(name: hour.conditions.icon, size: 23)
                                VStack(alignment: .leading, spacing: 5) { Text(OutfitEngine.recommend(hour.conditions, style: model.style, comfort: model.comfort).items.first?.name ?? "Light layers").font(.subheadline); Text("\(hour.intervalHours)-hour interval · \(hour.conditions.label)").font(.caption2).foregroundStyle(Theme.muted) }
                                Spacer(); Text(model.temperature(hour.conditions.temperature)).font(Theme.editorial(26))
                            }.padding(.vertical, 8)
                        }.buttonStyle(.plain)
                        Divider()
                    }
                }.padding(24).frame(maxWidth: 700).frame(maxWidth: .infinity)
            }.pageBackground().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }.sheet(item: $detail) { item in OutfitDetailView(conditions: item.conditions, style: item.style) }
        }
    }
}
