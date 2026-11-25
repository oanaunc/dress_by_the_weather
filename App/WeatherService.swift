import Foundation
import WeatherStyle

actor WeatherService {
    static let shared = WeatherService()
    private struct CacheEntry: Codable {
        let forecast: Forecast
        let expires: Date
        let lastModified: String?
    }
    private var cache: [String: CacheEntry] = [:]
    private var pending: [String: Task<Forecast, Error>] = [:]
    private var cooldown: Date = .distantPast
    private let directory: URL
    private let session: URLSession
    init() {
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Forecasts")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }
    private func coordinate(_ value: Double) -> String {
        // Truncate, rather than send GPS precision to the provider.
        String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), (value * 10_000).rounded(.towardZero) / 10_000)
    }
    func load(latitude: Double, longitude: Double) async throws -> Forecast {
        let key = coordinate(latitude) + "_" + coordinate(longitude)
        if let request = pending[key] { return try await request.value }
        let request = Task { try await fetch(latitude: latitude, longitude: longitude) }
        pending[key] = request
        defer { pending[key] = nil }
        return try await request.value
    }
    private func fetch(latitude: Double, longitude: Double) async throws -> Forecast {
        let lat = coordinate(latitude), lon = coordinate(longitude)
        let key = "\(lat)_\(lon)"
        let file = directory.appendingPathComponent(key + ".json")
        if cache[key] == nil, let data = try? Data(contentsOf: file) { cache[key] = try? JSONDecoder().decode(CacheEntry.self, from: data) }
        if let entry = cache[key], entry.expires > Date() { return entry.forecast }
        guard Date() >= cooldown else { throw ForecastError.throttled }
        var request = URLRequest(url: URL(string: "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=\(lat)&lon=\(lon)")!)
        request.setValue("DressByTheWeather/1.0 https://github.com/oanaunc/dress_by_the_weather", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let modified = cache[key]?.lastModified { request.setValue(modified, forHTTPHeaderField: "If-Modified-Since") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ForecastError.unavailable }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        // Locationforecast's product policy is stricter than generic HTTP expiry:
        // outside the Nordic region, identical requests must be 3 hours apart.
        // Use that conservative minimum everywhere, including Nordic locations.
        let expiry = max(http.value(forHTTPHeaderField: "Expires").flatMap { formatter.date(from: $0) } ?? .distantPast, Date().addingTimeInterval(3 * 3600))
        if http.statusCode == 429 {
            let retry = http.value(forHTTPHeaderField: "Retry-After")
            cooldown = retry.flatMap { Double($0) }.map { Date().addingTimeInterval($0) } ?? retry.flatMap { formatter.date(from: $0) } ?? Date().addingTimeInterval(900)
            throw ForecastError.throttled
        }
        if http.statusCode == 304, let previous = cache[key] {
            var validated = previous.forecast
            validated.fetchedAt = Date()
            let entry = CacheEntry(forecast: validated, expires: max(expiry, Date().addingTimeInterval(60)), lastModified: previous.lastModified)
            cache[key] = entry; try? JSONEncoder().encode(entry).write(to: file, options: .atomic)
            return validated
        }
        guard http.statusCode == 200 else { throw ForecastError.http(http.statusCode) }
        let forecast = try METResponse.decode(data)
        let entry = CacheEntry(forecast: forecast, expires: max(expiry, Date().addingTimeInterval(60)), lastModified: http.value(forHTTPHeaderField: "Last-Modified"))
        cache[key] = entry; try? JSONEncoder().encode(entry).write(to: file, options: .atomic)
        return forecast
    }
}
