import Foundation

public enum FashionStyle: String, CaseIterable, Codable, Sendable, Identifiable {
    case casual = "Everyday", business = "Office", elegant = "Evening", sport = "Active"
    public var id: String { rawValue }
    public var icon: String {
        switch self { case .casual: "sun.max"; case .business: "briefcase"; case .elegant: "sparkles"; case .sport: "figure.walk" }
    }
}

public enum TemperatureBand: Int, CaseIterable, Codable, Sendable {
    case deepFreeze, freezing, winter, cold, cool, mild, warm, summer, hot, extremeHeat
    public init(celsius: Double) {
        switch celsius {
        case ..<(-15): self = .deepFreeze
        case ..<(-5): self = .freezing
        case ..<5: self = .winter
        case ..<10: self = .cold
        case ..<15: self = .cool
        case ..<20: self = .mild
        case ..<25: self = .warm
        case ..<30: self = .summer
        case ..<35: self = .hot
        default: self = .extremeHeat
        }
    }
    public var range: String { ["Below −15°C", "−15 to −5°C", "−5 to 5°C", "5 to 10°C", "10 to 15°C", "15 to 20°C", "20 to 25°C", "25 to 30°C", "30 to 35°C", "35°C and above"][rawValue] }
    public var title: String { ["The deep winter edit", "Wrapped in warmth", "Winter, considered", "A little more layering", "The art of layering", "Light layers, easy days", "An effortless kind of day", "A lighter state of mind", "Made for the sunshine", "Keep your cool"][rawValue] }
}

public struct Conditions: Codable, Sendable, Equatable {
    public var temperature: Double
    public var windKmh: Double
    public var humidity: Double
    public var precipitationMm: Double
    public var symbol: String
    public init(temperature: Double, windKmh: Double = 0, humidity: Double = 50, precipitationMm: Double = 0, symbol: String = "clearsky_day") {
        self.temperature = temperature; self.windKmh = windKmh; self.humidity = humidity
        self.precipitationMm = precipitationMm; self.symbol = symbol
    }
    public var isSnow: Bool { symbol.contains("snow") || symbol.contains("sleet") }
    public var isRain: Bool { precipitationMm > 0.1 || symbol.contains("rain") || symbol.contains("sleet") }
    public var isStorm: Bool { symbol.contains("thunder") }
    public var label: String {
        if isStorm { return "Thunderstorms" }
        if isSnow { return "Snow / sleet" }
        if isRain { return "Rain" }
        if symbol.contains("fog") { return "Foggy" }
        if symbol.contains("partlycloudy") || symbol.contains("fair") { return "Partly cloudy" }
        if symbol.contains("cloudy") { return "Cloudy" }
        return symbol.contains("night") ? "Clear night" : "Sunny"
    }
    public var icon: String {
        if isStorm { return "cloud.bolt.rain.fill" }
        if isSnow { return "cloud.snow.fill" }
        if isRain { return "cloud.rain.fill" }
        if symbol.contains("fog") { return "cloud.fog.fill" }
        if symbol.contains("partlycloudy") || symbol.contains("fair") { return symbol.contains("night") ? "cloud.moon.fill" : "cloud.sun.fill" }
        if symbol.contains("cloudy") { return "cloud.fill" }
        return symbol.contains("night") ? "moon.stars.fill" : "sun.max.fill"
    }
    /// Estimated apparent temperature: wind chill in cold conditions; otherwise the
    /// Australian Bureau of Meteorology shade formula. It is not a MET measurement.
    public var apparentTemperature: Double {
        if temperature <= 10 && windKmh > 4.8 {
            let wind = pow(windKmh, 0.16)
            return 13.12 + 0.6215 * temperature - 11.37 * wind + 0.3965 * temperature * wind
        }
        let vapour = humidity / 100 * 6.105 * exp(17.27 * temperature / (237.7 + temperature))
        return temperature + 0.33 * vapour - 0.70 * (windKmh / 3.6) - 4
    }
}

public struct OutfitItem: Codable, Sendable, Hashable, Identifiable {
    public let category: String
    public let name: String
    public let fabric: String
    public let icon: String
    public var id: String { category + name }
    public init(_ category: String, _ name: String, _ fabric: String, _ icon: String) {
        self.category = category; self.name = name; self.fabric = fabric; self.icon = icon
    }
}

public struct Outfit: Sendable, Identifiable {
    public let band: TemperatureBand
    public let style: FashionStyle
    public let items: [OutfitItem]
    public let bring: [String]
    public let explanation: String
    public let caution: String?
    public let imageName: String?
    public var id: String { "\(band.rawValue)-\(style.rawValue)-\(items.map(\.name).joined(separator: "-"))" }
    public var title: String { band.title }
}

public enum OutfitEngine {
    /// Positive comfort means the person feels cold and needs warmer clothing.
    public static func recommend(_ weather: Conditions, style: FashionStyle = .casual, comfort: Double = 0) -> Outfit {
        let adjusted = weather.apparentTemperature - comfort + (style == .sport ? 3 : 0)
        let band = TemperatureBand(celsius: adjusted)
        let formal = style == .business || style == .elegant
        var items: [OutfitItem] = []
        switch band {
        case .deepFreeze:
            items = [.init("Outerwear", "Expedition parka", "Heavy insulated shell", "jacket"), .init("Base", "Thermal base layers", "Merino wool", "tshirt"), .init("Midlayer", "Thick knit / fleece", "Wool or technical fleece", "sweater"), .init("Bottom", "Insulated trousers", "Lined wind-resistant fabric", "figure.stand"), .init("Footwear", "Insulated winter boots", "Grippy sole", "shoe.2")]
        case .freezing:
            items = [.init("Outerwear", "Insulated winter coat", "Down or synthetic insulation", "jacket"), .init("Top", "Thermal layer & heavy knit", "Merino wool", "sweater"), .init("Bottom", "Warm lined trousers", "Wool blend", "figure.stand"), .init("Footwear", "Winter boots", "Insulated, grippy sole", "shoe.2")]
        case .winter:
            items = [.init("Outerwear", formal ? "Lined wool overcoat" : "Insulated jacket", "Warm insulating layer", "jacket"), .init("Top", "Sweater & base layer", "Merino wool", "sweater"), .init("Bottom", "Warm trousers", "Wool blend", "figure.stand"), .init("Footwear", "Lined ankle boots", "Grippy sole", "shoe.2")]
        case .cold:
            items = [.init("Outerwear", formal ? "Tailored wool coat" : "Medium-weight coat", "Wool blend", "jacket"), .init("Top", "Warm knit", "Merino or cashmere", "sweater"), .init("Bottom", "Full-length trousers", "Wool or cotton twill", "figure.stand"), .init("Footwear", "Ankle boots", "Closed, sturdy shoes", "shoe.2")]
        case .cool:
            items = [.init("Outerwear", formal ? "Light trench coat" : "Light jacket", "Wind-resistant weave", "jacket"), .init("Top", "Fine-knit sweater", "Cotton or merino", "sweater"), .init("Bottom", "Long trousers", "Cotton twill", "figure.stand"), .init("Footwear", formal ? "Loafers / closed shoes" : "Sneakers", "Comfortable closed shoes", "shoe.2")]
        case .mild:
            items = [.init("Layer", formal ? "Unstructured blazer" : "Light overshirt", "Cotton or linen blend", "jacket"), .init("Top", "Long-sleeved shirt", "Breathable cotton", "tshirt"), .init("Bottom", "Light trousers", "Cotton", "figure.stand"), .init("Footwear", formal ? "Loafers" : "Sneakers", "Breathable closed shoes", "shoe.2")]
        case .warm:
            items = [.init("Top", formal ? "Light tailored shirt" : "Cotton tee / airy blouse", "Breathable cotton", "tshirt"), .init("Bottom", "Light trousers / midi skirt", "Linen blend", "figure.stand"), .init("Footwear", formal ? "Light loafers" : "Light sneakers", "Breathable materials", "shoe.2")]
        case .summer, .hot, .extremeHeat:
            items = [.init("Top", formal ? "Relaxed linen shirt" : "Airy linen shirt", "Light, breathable linen", "tshirt"), .init("Bottom", formal ? "Linen trousers / airy dress" : "Loose linen trousers / shorts", "Lightweight natural fabric", "figure.stand"), .init("Footwear", formal ? "Breathable loafers" : "Sandals", "Comfortable, ventilated shoes", "shoe.2")]
        }
        if style == .sport {
            items = items.map { item in
                if item.category == "Top" { return .init("Top", band.rawValue < 4 ? "Wicking base & active midlayer" : "Breathable active top", "Quick-drying technical fabric", "tshirt") }
                if item.category == "Bottom" { return .init("Bottom", band.rawValue < 6 ? "Technical trousers / leggings" : "Light active shorts", "Stretch, quick-drying fabric", "figure.run") }
                if item.category == "Footwear" { return .init("Footwear", "Supportive trainers", "Grip suited to your route", "shoe.2") }
                return item
            }
        }
        var bring: [String] = []
        if band.rawValue <= 2 { bring += ["Gloves", "Warm hat", "Scarf"] }
        else if band.rawValue == 3 { bring += ["Scarf"] }
        if weather.isSnow || weather.isRain {
            items.removeAll { ["Outerwear", "Layer"].contains($0.category) }
            items.insert(.init("Outerwear", weather.isSnow ? "Insulated waterproof coat" : (band.rawValue < 3 ? "Insulated rainproof coat" : "Breathable rain shell"), "Waterproof outer layer", "jacket"), at: 0)
            items.removeAll { $0.category == "Footwear" }
            items.append(.init("Footwear", weather.isSnow ? "Waterproof winter boots" : "Water-resistant closed shoes", "Grippy sole", "shoe.2"))
            bring += weather.isSnow ? ["Warm hat", "Gloves"] : [weather.windKmh >= 35 ? "Rain hood" : "Umbrella"]
        }
        if weather.windKmh >= 25 { bring += ["Windproof outer layer"] }
        if weather.temperature >= 20 && !weather.symbol.contains("night") { bring += ["Sunglasses", "Sun protection", "Water"] }
        if band.rawValue >= 8 { bring += ["Sun hat"] }
        var caution: String?
        if weather.isStorm { caution = "Thunderstorms forecast. Plan an indoor alternative and check local weather warnings." }
        else if weather.temperature < -15 { caution = "Extreme cold. Limit exposure and check official local warnings." }
        else if weather.temperature >= 35 { caution = "Extreme heat. Seek shade, take breaks and follow local heat advice." }
        let styleIndex = FashionStyle.allCases.firstIndex(of: style)!
        let category: String
        let imageBand: Int
        if weather.isSnow || (weather.isRain && band.rawValue < 3) {
            category = "snow"; imageBand = band.rawValue <= 1 ? 1 : 2
        } else if weather.isRain {
            category = "rain"; imageBand = band.rawValue < 4 ? 3 : band.rawValue < 6 ? 4 : band.rawValue < 8 ? 6 : 8
        } else { category = "dry"; imageBand = band.rawValue }
        let image = "couple_\(category)_\(imageBand)_\(styleIndex)"
        let why = "Chosen for an estimated feels-like temperature of \(Int(weather.apparentTemperature.rounded()))°C. " + (weather.isRain ? "A waterproof outer layer keeps the rain out. " : "") + (weather.windKmh >= 25 ? "Wind protection matters today. " : "") + "Use removable layers to adjust your comfort."
        return Outfit(band: band, style: style, items: items, bring: Array(Set(bring)).sorted(), explanation: why, caution: caution, imageName: image)
    }
}
