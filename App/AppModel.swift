import SwiftUI
import CoreLocation
import MapKit
import WidgetKit
import UserNotifications
import WeatherStyle

struct SavedCity: Codable, Identifiable, Equatable, Sendable {
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String
    var id: String { "\(latitude),\(longitude)" }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    static let bucharest = SavedCity(name: "Bucharest", latitude: 44.4268, longitude: 26.1025, timeZoneID: "Europe/Bucharest")
    static let suggestions: [SavedCity] = [.bucharest, .init(name: "Paris", latitude: 48.8566, longitude: 2.3522, timeZoneID: "Europe/Paris"), .init(name: "London", latitude: 51.5074, longitude: -0.1278, timeZoneID: "Europe/London"), .init(name: "New York", latitude: 40.7128, longitude: -74.0060, timeZoneID: "America/New_York"), .init(name: "Tokyo", latitude: 35.6762, longitude: 139.6503, timeZoneID: "Asia/Tokyo")]
}
struct SavedLook: Codable, Identifiable {
    let id: UUID
    let date: Date
    let conditions: Conditions
    let style: FashionStyle
    let comfort: Double
    let city: String
}
struct PackingTrip: Codable, Identifiable {
    let id: UUID
    let city: SavedCity
    let start: Date
    let end: Date
    let items: [String]
    var checked: Set<String>
}
struct PlannedOutfit: Codable, Identifiable {
    var id: String
    var date: Date
    var cityID: String
    var style: FashionStyle
    var variant: Int
}
struct SavedCapsule: Codable, Identifiable {
    var id: UUID
    var city: SavedCity
    var start: Date
    var end: Date
    var plan: CapsulePlan
    var checked: Set<String>
}

@MainActor @Observable final class AppModel: NSObject, @preconcurrency CLLocationManagerDelegate {
    var forecast: Forecast?
    var city: SavedCity = .bucharest { didSet { save(city, "city") } }
    var cities: [SavedCity] = [.bucharest] { didSet { save(cities, "cities") } }
    var style: FashionStyle = .casual { didSet { save(style, "style") } }
    var comfort: Double = 0 { didSet { UserDefaults.standard.set(comfort, forKey: "comfort") } }
    var fahrenheit = false { didSet { UserDefaults.standard.set(fahrenheit, forKey: "fahrenheit"); writeWidget() } }
    var completedOnboarding = false { didSet { UserDefaults.standard.set(completedOnboarding, forKey: "onboarded") } }
    var savedLooks: [SavedLook] = [] { didSet { save(savedLooks, "looks") } }
    var trips: [PackingTrip] = [] { didSet { save(trips, "trips") } }
    var wardrobe: [Garment] = [] { didSet { save(wardrobe, "wardrobe") } }
    var weeklyPlans: [PlannedOutfit] = [] { didSet { save(weeklyPlans, "weeklyPlans") } }
    var capsules: [SavedCapsule] = [] { didSet { save(capsules, "capsules") } }
    var editorialFavorites: Set<String> = [] { didSet { save(editorialFavorites, "editorialFavorites") } }
    var loading = false
    var error: String?
    var notificationMessage: String?
    var locating = false
    var searchResults: [SavedCity] = []
    var searchError: String?
    var searching = false
    private let locationManager = CLLocationManager()
    private var searchGeneration = 0
    private var loadGeneration = 0
    override init() {
        super.init()
        if ProcessInfo.processInfo.arguments.contains("--uitesting-reset"), let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        city = read("city") ?? .bucharest; cities = read("cities") ?? [.bucharest]
        style = read("style") ?? .casual; savedLooks = read("looks") ?? []; trips = read("trips") ?? []
        wardrobe = read("wardrobe") ?? []; weeklyPlans = read("weeklyPlans") ?? []; capsules = read("capsules") ?? []
        editorialFavorites = read("editorialFavorites") ?? []
        comfort = UserDefaults.standard.double(forKey: "comfort")
        fahrenheit = UserDefaults.standard.bool(forKey: "fahrenheit")
        completedOnboarding = UserDefaults.standard.bool(forKey: "onboarded")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        if ProcessInfo.processInfo.arguments.contains("--preview") {
            forecast = .preview(); completedOnboarding = true
        }
    }
    private func read<T: Decodable>(_ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
    private func save<T: Encodable>(_ object: T, _ key: String) {
        if let data = try? JSONEncoder().encode(object) { UserDefaults.standard.set(data, forKey: key) }
    }
    func temperature(_ c: Double) -> String { "\(Int((fahrenheit ? c * 9 / 5 + 32 : c).rounded()))°" }
    var current: Conditions? { forecast?.current()?.conditions }
    var days: [ForecastDay] { forecast?.days(timeZone: city.timeZone) ?? [] }
    var recommendation: Outfit? { current.map { OutfitEngine.recommend($0, style: style, comfort: comfort) } }
    var upcoming: [ForecastHour] { forecast?.hours.filter { $0.date >= Date().addingTimeInterval(-3600) } ?? [] }
    func time(_ date: Date, format: String = "ha") -> String {
        let formatter = DateFormatter(); formatter.timeZone = city.timeZone; formatter.dateFormat = format
        return formatter.string(from: date)
    }
    func refresh() async {
        loadGeneration += 1
        let generation = loadGeneration, selectedCity = city
        loading = true; error = nil
        do {
            let loaded = try await WeatherService.shared.load(latitude: selectedCity.latitude, longitude: selectedCity.longitude)
            guard generation == loadGeneration else { return }
            forecast = loaded
            writeWidget()
        } catch {
            guard generation == loadGeneration else { return }
            self.error = error.localizedDescription
        }
        if generation == loadGeneration { loading = false }
    }
    func select(_ selectedCity: SavedCity) async {
        city = selectedCity; forecast = nil
        if !cities.contains(where: { $0.id == selectedCity.id }) { cities.append(selectedCity) }
        await refresh()
    }
    func showPreview() { loadGeneration += 1; loading = false; forecast = .preview(); error = nil }
    func saveLook(_ conditions: Conditions, style: FashionStyle, comfortOverride: Double? = nil) {
        savedLooks.insert(.init(id: UUID(), date: Date(), conditions: conditions, style: style, comfort: comfortOverride ?? comfort, city: city.name), at: 0)
    }
    func feedback(_ amount: Double) { comfort = min(5, max(-5, comfort + amount)) }
    func requestLocation() {
        error = nil
        let status = locationManager.authorizationStatus
        if status == .notDetermined { locating = true; locationManager.requestWhenInUseAuthorization() }
        else if status == .authorizedWhenInUse || status == .authorizedAlways { locating = true; locationManager.requestLocation() }
        else { error = "Location access is off. You can choose a city or enable access in iOS Settings." }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if locating && (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways) { manager.requestLocation() }
        else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted { locating = false; error = "Choose a city to get weather without location access." }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { locating = false; return }
        Task {
            let request = MKReverseGeocodingRequest(location: location)
            let place = try? await request?.mapItems.first
            let selected = SavedCity(name: place?.addressRepresentations?.cityName ?? "Current location", latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, timeZoneID: place?.timeZone?.identifier ?? TimeZone.current.identifier)
            locating = false; completedOnboarding = true; await select(selected)
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { locating = false; self.error = "Your location couldn’t be found. Choose a city instead." }
    func search(_ query: String) async {
        searchGeneration += 1; let generation = searchGeneration
        searchError = nil
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { searchResults = []; searching = false; return }
        searching = true
        do {
            let request = MKLocalSearch.Request(); request.naturalLanguageQuery = query; request.resultTypes = .address
            let response = try await MKLocalSearch(request: request).start()
            guard generation == searchGeneration else { return }
            searchResults = response.mapItems.prefix(8).map { item in
                SavedCity(name: item.name ?? query, latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude, timeZoneID: item.timeZone?.identifier ?? TimeZone.current.identifier)
            }
            if searchResults.isEmpty { searchError = "No locations found. Try a city and country." }
        } catch { if generation == searchGeneration { searchError = "Search is unavailable. Try a saved city." } }
        if generation == searchGeneration { searching = false }
    }
    func makeTrip(city: SavedCity, start: Date, end: Date) async throws {
        let tripForecast = try await WeatherService.shared.load(latitude: city.latitude, longitude: city.longitude)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = city.timeZone
        let selected = tripForecast.days(timeZone: city.timeZone).filter { calendar.startOfDay(for: $0.date) >= calendar.startOfDay(for: start) && calendar.startOfDay(for: $0.date) <= calendar.startOfDay(for: end) }
        guard let last = selected.last, calendar.isDate(last.date, inSameDayAs: end) else { throw TripError.outsideForecast }
        var items = Set<String>()
        for day in selected {
            // Use the coldest and warmest periods so the list covers both.
            let examples = [day.hours.min { $0.conditions.temperature < $1.conditions.temperature }, day.hours.max { $0.conditions.temperature < $1.conditions.temperature }, day.hours.first { $0.conditions.isRain || $0.conditions.isSnow }].compactMap { $0 }
            for hour in examples {
                let look = OutfitEngine.recommend(hour.conditions, style: style, comfort: comfort)
                items.formUnion(look.items.map(\.name)); items.formUnion(look.bring)
            }
        }
        trips.insert(.init(id: UUID(), city: city, start: start, end: end, items: items.sorted(), checked: []), at: 0)
    }
    func togglePacking(_ item: String, tripID: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        if trips[index].checked.contains(item) { trips[index].checked.remove(item) } else { trips[index].checked.insert(item) }
    }
    func plannedOutfit(for date: Date) -> PlannedOutfit? {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = city.timeZone
        return weeklyPlans.first { $0.cityID == city.id && calendar.isDate($0.date, inSameDayAs: date) }
    }
    func planOutfit(date: Date, style: FashionStyle, variant: Int) {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = city.timeZone
        let day = calendar.startOfDay(for: date), key = city.id + "-" + String(day.timeIntervalSince1970)
        weeklyPlans.removeAll { $0.id == key }
        weeklyPlans.append(PlannedOutfit(id: key, date: day, cityID: city.id, style: style, variant: variant))
    }
    func clearPlan(date: Date) {
        guard let plan = plannedOutfit(for: date) else { return }
        weeklyPlans.removeAll { $0.id == plan.id }
    }
    static var wardrobePhotoDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "WardrobePhotos", directoryHint: .isDirectory)
    }
    func saveGarment(_ garment: Garment, photoData: Data?) throws {
        var garment = garment
        guard !garment.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let photoData, let image = UIImage(data: photoData) {
            let scale = min(1, 1024 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let compressed = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.82)
            if let compressed {
                try FileManager.default.createDirectory(at: Self.wardrobePhotoDirectory, withIntermediateDirectories: true)
                let filename = garment.id.uuidString + ".jpg"
                try compressed.write(to: Self.wardrobePhotoDirectory.appending(path: filename), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                garment.photoFilename = filename
            }
        }
        if let index = wardrobe.firstIndex(where: { $0.id == garment.id }) { wardrobe[index] = garment }
        else { wardrobe.insert(garment, at: 0) }
    }
    func removeGarment(_ garment: Garment) {
        wardrobe.removeAll { $0.id == garment.id }
        if let filename = garment.photoFilename { try? FileManager.default.removeItem(at: Self.wardrobePhotoDirectory.appending(path: filename)) }
    }
    func makeCapsule(city: SavedCity, start: Date, end: Date, occasion: FashionStyle) async throws {
        let forecast: Forecast
        if self.city.id == city.id, let current = self.forecast, current.isPreview { forecast = current }
        else { forecast = try await WeatherService.shared.load(latitude: city.latitude, longitude: city.longitude) }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = city.timeZone
        let days = forecast.days(timeZone: city.timeZone).filter { calendar.startOfDay(for: $0.date) >= calendar.startOfDay(for: start) && calendar.startOfDay(for: $0.date) <= calendar.startOfDay(for: end) }
        guard let last = days.last, calendar.isDate(last.date, inSameDayAs: end) else { throw TripError.outsideForecast }
        let plan = CapsulePlanner.make(days: days, style: occasion, comfort: comfort, garments: wardrobe)
        capsules.insert(SavedCapsule(id: UUID(), city: city, start: start, end: end, plan: plan, checked: []), at: 0)
    }
    func toggleCapsule(_ item: String, capsuleID: UUID) {
        guard let index = capsules.firstIndex(where: { $0.id == capsuleID }) else { return }
        if capsules[index].checked.contains(item) { capsules[index].checked.remove(item) } else { capsules[index].checked.insert(item) }
    }
    func clearStudioData() throws {
        if FileManager.default.fileExists(atPath: Self.wardrobePhotoDirectory.path) { try FileManager.default.removeItem(at: Self.wardrobePhotoDirectory) }
        wardrobe = []; weeklyPlans = []; capsules = []; editorialFavorites = []
    }
    func scheduleReminder(hour: Int) async {
        do {
            let center = UNUserNotificationCenter.current()
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { notificationMessage = "Notifications are off. Enable them in iOS Settings to receive reminders."; return }
            let content = UNMutableNotificationContent(); content.title = "Your forecast. Your outfit."
            content.body = "Open Dress by the Weather for today’s fresh forecast and what to wear."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "morning-outfit", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true))
            try await center.add(request)
            notificationMessage = "Your daily reminder is set for \(hour):00. Open the app for fresh weather."
        } catch { notificationMessage = "The reminder couldn’t be scheduled. Please try again." }
    }
    func disableReminder() { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning-outfit"]); notificationMessage = "Daily reminder turned off." }
    private func writeWidget() {
        guard let current, let forecast, !forecast.isPreview else { return }
        let defaults = UserDefaults(suiteName: "group.com.oanarinaldi.dressbytheweather")
        defaults?.set(city.name, forKey: "city")
        defaults?.set(temperature(current.temperature), forKey: "temperature")
        defaults?.set(current.icon, forKey: "symbol")
        defaults?.set(OutfitEngine.recommend(current, style: style, comfort: comfort).items.first?.name, forKey: "tip")
        defaults?.set(forecast.updatedAt, forKey: "updated")
        defaults?.set(forecast.fetchedAt.addingTimeInterval(3 * 3600), forKey: "validUntil")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
enum TripError: LocalizedError { case outsideForecast; var errorDescription: String? { "Choose dates within the next 8 days. Packing lists use actual forecasts, so later trips aren’t available yet." } }
