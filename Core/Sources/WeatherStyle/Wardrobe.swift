import Foundation

public enum GarmentCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case outerwear = "Outerwear", top = "Tops", midlayer = "Knitwear", bottom = "Bottoms", footwear = "Shoes", accessory = "Accessories"
    public var id: String { rawValue }
    public var icon: String { switch self { case .outerwear: "jacket"; case .top: "tshirt"; case .midlayer: "sweater"; case .bottom: "figure.stand"; case .footwear: "shoe.2"; case .accessory: "bag" } }
    public static func forOutfitCategory(_ category: String) -> Self {
        switch category { case "Outerwear", "Layer": .outerwear; case "Top", "Base": .top; case "Midlayer": .midlayer; case "Bottom": .bottom; case "Footwear": .footwear; default: .accessory }
    }
}

public struct Garment: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var category: GarmentCategory
    public var color: String
    public var minimumTemperature: Double
    public var maximumTemperature: Double
    public var waterResistant: Bool
    public var available: Bool
    public var occasions: Set<FashionStyle>
    public var photoFilename: String?
    public init(id: UUID = UUID(), name: String, category: GarmentCategory, color: String = "", minimumTemperature: Double = 5, maximumTemperature: Double = 25, waterResistant: Bool = false, available: Bool = true, occasions: Set<FashionStyle> = Set(FashionStyle.allCases), photoFilename: String? = nil) {
        self.id = id; self.name = name; self.category = category; self.color = color
        self.minimumTemperature = min(minimumTemperature, maximumTemperature)
        self.maximumTemperature = max(minimumTemperature, maximumTemperature)
        self.waterResistant = waterResistant; self.available = available; self.occasions = occasions; self.photoFilename = photoFilename
    }
}

public struct WardrobeMatch: Identifiable, Sendable {
    public let suggested: OutfitItem
    public let garment: Garment?
    public var id: String { suggested.id }
    public var name: String { garment?.name ?? suggested.name }
}

public enum WardrobeMatcher {
    /// User-entered comfort ranges are estimates. Never substitute an unprotected
    /// shoe or outer layer when the forecast calls for rain or snow protection.
    public static func match(_ outfit: Outfit, weather: Conditions, garments: [Garment], preferredIDs: Set<UUID> = []) -> [WardrobeMatch] {
        var used = Set<UUID>()
        return outfit.items.map { item in
            let category = GarmentCategory.forOutfitCategory(item.category)
            let candidates = garments.filter { garment in
                garment.available && !used.contains(garment.id) && garment.category == category && garment.occasions.contains(outfit.style)
                && (garment.minimumTemperature...garment.maximumTemperature).contains(weather.apparentTemperature)
                && (!(weather.isRain || weather.isSnow) || ![.outerwear, .footwear].contains(category) || garment.waterResistant)
            }.sorted { lhs, rhs in
                let lp = preferredIDs.contains(lhs.id), rp = preferredIDs.contains(rhs.id)
                if lp != rp { return lp }
                let ld = abs((lhs.minimumTemperature + lhs.maximumTemperature) / 2 - weather.apparentTemperature)
                let rd = abs((rhs.minimumTemperature + rhs.maximumTemperature) / 2 - weather.apparentTemperature)
                return ld == rd ? lhs.id.uuidString < rhs.id.uuidString : ld < rd
            }
            let garment = candidates.first
            if let garment { used.insert(garment.id) }
            return WardrobeMatch(suggested: item, garment: garment)
        }
    }
}

public struct CapsuleDay: Codable, Sendable, Identifiable {
    public var date: Date
    public var conditions: Conditions
    public var style: FashionStyle
    public var pieces: [String]
    public var id: Date { date }
}
public struct CapsulePiece: Codable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var garmentID: UUID?
    public var category: String
    public var daysUsed: Int
}
public struct CapsulePlan: Codable, Sendable {
    public var days: [CapsuleDay]
    public var pieces: [CapsulePiece]
    public var bring: [String]
    public var ownedCount: Int { pieces.filter { $0.garmentID != nil }.count }
    public var checklist: [String] { pieces.map(\.name) + bring }
}
public enum CapsulePlanner {
    public static func make(days: [ForecastDay], style: FashionStyle, comfort: Double, garments: [Garment]) -> CapsulePlan {
        var pieces: [String: CapsulePiece] = [:], preferred = Set<UUID>(), bring = Set<String>(), result: [CapsuleDay] = []
        for day in days where !day.hours.isEmpty {
            var dailyKeys = Set<String>(), dailyNames = Set<String>()
            let samples = [day.hours.min { $0.conditions.apparentTemperature < $1.conditions.apparentTemperature }, day.hours.max { $0.conditions.apparentTemperature < $1.conditions.apparentTemperature }, day.hours.first { $0.conditions.isRain || $0.conditions.isSnow }, day.hours.max { $0.conditions.windKmh < $1.conditions.windKmh }].compactMap { $0 }
            for sample in samples {
                let outfit = OutfitEngine.recommend(sample.conditions, style: style, comfort: comfort)
                for match in WardrobeMatcher.match(outfit, weather: sample.conditions, garments: garments, preferredIDs: preferred) {
                    let key = match.garment.map { "owned-" + $0.id.uuidString } ?? "suggested-" + match.suggested.id
                    if pieces[key] == nil { pieces[key] = CapsulePiece(id: key, name: match.name, garmentID: match.garment?.id, category: match.suggested.category, daysUsed: 0) }
                    dailyKeys.insert(key); dailyNames.insert(match.name)
                    if let garment = match.garment { preferred.insert(garment.id) }
                }
                bring.formUnion(outfit.bring)
            }
            for key in dailyKeys { pieces[key]?.daysUsed += 1 }
            result.append(CapsuleDay(date: day.date, conditions: day.representative.conditions, style: style, pieces: dailyNames.sorted()))
        }
        return CapsulePlan(days: result, pieces: pieces.values.sorted { $0.daysUsed == $1.daysUsed ? $0.name < $1.name : $0.daysUsed > $1.daysUsed }, bring: bring.sorted())
    }
}
