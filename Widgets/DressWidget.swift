import WidgetKit
import SwiftUI

struct OutfitEntry: TimelineEntry {
    let date: Date
    let city: String
    let temperature: String
    let symbol: String
    let tip: String
    let updated: Date?
    var validUntil: Date? = nil
}
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> OutfitEntry { .init(date: Date(), city: "Your city", temperature: "—", symbol: "cloud.sun", tip: "Your daily layers", updated: nil) }
    func getSnapshot(in context: Context, completion: @escaping (OutfitEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<OutfitEntry>) -> Void) {
        // No network requests in the background: use only the foreground app snapshot.
        let current = entry()
        var entries = [current]
        if let validUntil = current.validUntil, validUntil > Date() {
            entries.append(.init(date: validUntil, city: current.city, temperature: "—", symbol: "arrow.clockwise", tip: "Open for fresh weather & layers", updated: current.updated))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
    private func entry() -> OutfitEntry {
        let defaults = UserDefaults(suiteName: "group.com.oanarinaldi.dressbytheweather")
        let updated = defaults?.object(forKey: "updated") as? Date
        let validUntil = defaults?.object(forKey: "validUntil") as? Date
        let stale = validUntil.map { $0 < Date() } ?? true
        return .init(date: Date(), city: defaults?.string(forKey: "city") ?? "Your city", temperature: stale ? "—" : defaults?.string(forKey: "temperature") ?? "—", symbol: stale ? "arrow.clockwise" : defaults?.string(forKey: "symbol") ?? "cloud.sun", tip: stale ? "Open for fresh weather & layers" : defaults?.string(forKey: "tip") ?? "Open for your outfit", updated: updated, validUntil: validUntil)
    }
}
struct DressWidgetView: View {
    let entry: OutfitEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        if family == .accessoryInline {
            Text("\(entry.temperature) · \(entry.tip)")
        } else if family == .accessoryRectangular {
            VStack(alignment: .leading) { Label(entry.temperature + " · " + entry.city, systemImage: entry.symbol); Text(entry.tip).font(.caption2) }
        } else {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(entry.city.uppercased()).font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1)
                    HStack { Text(entry.temperature).font(.system(size: 52, weight: .ultraLight, design: .serif)); Spacer(); Image(systemName: entry.symbol).symbolRenderingMode(.multicolor).font(.title) }
                    Text(entry.tip).font(.system(size: 13, design: .serif)).lineLimit(2)
                    if let updated = entry.updated { Text("Updated \(updated.formatted(date: .omitted, time: .shortened))").font(.system(size: 8)).foregroundStyle(.secondary) }
                }
                if family == .systemMedium { Image(systemName: "tshirt").font(.system(size: 65, weight: .ultraLight)).foregroundStyle(.secondary).frame(width: 80) }
            }
        }
    }
}
@main struct DressWidget: Widget {
    let kind = "DressByTheWeatherWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DressWidgetView(entry: entry).containerBackground(Color(red: 0.96, green: 0.95, blue: 0.90), for: .widget).widgetURL(URL(string: "dressweather://today"))
        }.configurationDisplayName("Your forecast. Your outfit.").description("The last forecast and a considered layer, at a glance. Open the app to refresh.").supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular])
    }
}
