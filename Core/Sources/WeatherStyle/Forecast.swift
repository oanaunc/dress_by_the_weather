import Foundation

public struct ForecastHour: Codable, Sendable, Identifiable {
    public var date: Date
    public var conditions: Conditions
    public var intervalHours: Int
    public var id: Date { date }
    public init(date: Date, conditions: Conditions, intervalHours: Int = 1) { self.date = date; self.conditions = conditions; self.intervalHours = intervalHours }
}

public struct ForecastDay: Sendable, Identifiable {
    public var date: Date
    public var hours: [ForecastHour]
    public var id: Date { date }
    public var low: Double { hours.map(\.conditions.temperature).min() ?? 0 }
    public var high: Double { hours.map(\.conditions.temperature).max() ?? 0 }
    public var representative: ForecastHour { hours.first(where: { $0.conditions.isRain || $0.conditions.isSnow }) ?? hours[hours.count / 2] }
}

public struct Forecast: Codable, Sendable {
    public var updatedAt: Date
    public var fetchedAt: Date
    public var hours: [ForecastHour]
    public var isPreview: Bool
    public init(updatedAt: Date, fetchedAt: Date = Date(), hours: [ForecastHour], isPreview: Bool = false) {
        self.updatedAt = updatedAt; self.fetchedAt = fetchedAt; self.hours = hours; self.isPreview = isPreview
    }
    public func current(now: Date = Date()) -> ForecastHour? {
        hours.last(where: { $0.date <= now }) ?? hours.first
    }
    public func days(timeZone: TimeZone) -> [ForecastDay] {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let groups = Dictionary(grouping: hours) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted().map { ForecastDay(date: $0, hours: groups[$0]!.sorted { $0.date < $1.date }) }
    }
    public static func preview(now: Date = Date()) -> Forecast {
        let start = Calendar.current.dateInterval(of: .hour, for: now)!.start
        let hours = (0..<216).map { index in
            let temperature = 28.0 + sin(Double(index % 24) / 24 * .pi * 2) * 3 - Double(index / 24) * 0.35
            let rain = index / 24 == 2 || index / 24 == 5
            let night = index % 24 >= 12
            return ForecastHour(date: start.addingTimeInterval(Double(index) * 3600), conditions: Conditions(temperature: temperature, windKmh: 7, humidity: 35, precipitationMm: rain ? 1.2 : 0, symbol: rain ? "rain" : (night ? "clearsky_night" : "fair_day")))
        }
        return Forecast(updatedAt: now, hours: hours, isPreview: true)
    }
}

/// Missing period blocks at the end of a MET forecast are expected, not errors.
public struct METResponse: Decodable, Sendable {
    public let properties: Properties
    public struct Properties: Decodable, Sendable { public let meta: Meta; public let timeseries: [Entry] }
    public struct Meta: Decodable, Sendable { public let updated_at: Date }
    public struct Entry: Decodable, Sendable { public let time: Date; public let data: Details }
    public struct Details: Decodable, Sendable {
        public let instant: Instant
        public let next_1_hours: Period?
        public let next_6_hours: Period?
        public let next_12_hours: Period?
    }
    public struct Instant: Decodable, Sendable { public let details: [String: Double] }
    public struct Period: Decodable, Sendable { public let summary: Summary; public let details: [String: Double] }
    public struct Summary: Decodable, Sendable { public let symbol_code: String }
    public static func decode(_ data: Data, fetchedAt: Date = Date()) throws -> Forecast {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(Self.self, from: data)
        let hours = response.properties.timeseries.compactMap { entry -> ForecastHour? in
            let values = entry.data.instant.details
            guard let temperature = values["air_temperature"], temperature.isFinite else { return nil }
            let period = entry.data.next_1_hours ?? entry.data.next_6_hours ?? entry.data.next_12_hours
            let span = entry.data.next_1_hours != nil ? 1 : (entry.data.next_6_hours != nil ? 6 : 12)
            let cloud = values["cloud_area_fraction"] ?? 0
            let symbol = period?.summary.symbol_code ?? (cloud > 75 ? "cloudy" : cloud > 20 ? "partlycloudy_day" : "clearsky_day")
            return ForecastHour(date: entry.time, conditions: Conditions(temperature: temperature, windKmh: (values["wind_speed"] ?? 0) * 3.6, humidity: values["relative_humidity"] ?? 50, precipitationMm: period?.details["precipitation_amount"] ?? 0, symbol: symbol), intervalHours: span)
        }
        guard !hours.isEmpty else { throw ForecastError.empty }
        return Forecast(updatedAt: response.properties.meta.updated_at, fetchedAt: fetchedAt, hours: hours)
    }
}
public enum ForecastError: Error, LocalizedError {
    case empty, http(Int), throttled, unavailable
    public var errorDescription: String? {
        switch self {
        case .empty: "The provider returned no forecast for this location."
        case .http(let code): "Weather is temporarily unavailable (\(code)). Try again later."
        case .throttled: "The weather service is busy. Your last forecast is available; please try again later."
        case .unavailable: "No weather is available. Connect to the internet and try again."
        }
    }
}
