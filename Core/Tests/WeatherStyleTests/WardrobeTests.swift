import XCTest
@testable import WeatherStyle

final class WardrobeTests: XCTestCase {
    func testWetWeatherNeverMatchesUnprotectedFootwearOrCoat() {
        let weather = Conditions(temperature: 12, precipitationMm: 2, symbol: "rain")
        let look = OutfitEngine.recommend(weather)
        let garments = [Garment(name: "Suede shoes", category: .footwear, minimumTemperature: -20, maximumTemperature: 40), Garment(name: "Wool coat", category: .outerwear, minimumTemperature: -20, maximumTemperature: 40), Garment(name: "Rain boots", category: .footwear, minimumTemperature: -20, maximumTemperature: 40, waterResistant: true)]
        let matches = WardrobeMatcher.match(look, weather: weather, garments: garments)
        XCTAssertEqual(matches.first { $0.suggested.category == "Footwear" }?.garment?.name, "Rain boots")
        XCTAssertNil(matches.first { $0.suggested.category == "Outerwear" }?.garment)
    }
    func testLaundryWrongOccasionAndWrongComfortRangeAreExcluded() {
        let weather = Conditions(temperature: 18)
        let look = OutfitEngine.recommend(weather, style: .business)
        let garments = [Garment(name: "Laundry", category: .top, minimumTemperature: -20, maximumTemperature: 40, available: false), Garment(name: "Too warm", category: .top, minimumTemperature: -20, maximumTemperature: 0), Garment(name: "Gym tee", category: .top, minimumTemperature: -20, maximumTemperature: 40, occasions: [.sport]), Garment(name: "Office shirt", category: .top, minimumTemperature: 5, maximumTemperature: 30, occasions: [.business])]
        XCTAssertEqual(WardrobeMatcher.match(look, weather: weather, garments: garments).first { $0.suggested.category == "Top" }?.name, "Office shirt")
    }
    func testCapsuleReusesOneSuitableOwnedPieceAcrossDays() {
        let shirt = Garment(name: "My linen shirt", category: .top, minimumTemperature: 15, maximumTemperature: 35)
        let hours = (0..<7).map { ForecastHour(date: Date(timeIntervalSince1970: Double($0) * 86400), conditions: Conditions(temperature: 24)) }
        let days = hours.map { ForecastDay(date: $0.date, hours: [$0]) }
        let plan = CapsulePlanner.make(days: days, style: .casual, comfort: 0, garments: [shirt])
        let owned = plan.pieces.filter { $0.garmentID == shirt.id }
        XCTAssertEqual(owned.count, 1)
        XCTAssertEqual(owned.first?.daysUsed, 7)
        XCTAssertEqual(plan.days.count, 7)
        XCTAssertEqual(plan.ownedCount, 1)
    }
    func testCapsuleCoversColdWarmWetAndWindyPeriods() {
        let samples = [Conditions(temperature: 0), Conditions(temperature: 28), Conditions(temperature: 15, windKmh: 40, precipitationMm: 3, symbol: "rain")]
        let hours = samples.enumerated().map { ForecastHour(date: Date(timeIntervalSince1970: Double($0.offset) * 3600), conditions: $0.element) }
        let plan = CapsulePlanner.make(days: [ForecastDay(date: hours[0].date, hours: hours)], style: .casual, comfort: 0, garments: [])
        XCTAssertTrue(plan.pieces.contains { $0.name == "Water-resistant closed shoes" })
        XCTAssertTrue(plan.pieces.contains { $0.name == "Lined ankle boots" })
        XCTAssertTrue(plan.pieces.contains { $0.name == "Airy linen shirt" })
        XCTAssertTrue(plan.bring.contains("Windproof outer layer"))
        XCTAssertTrue(plan.bring.contains("Rain hood"))
        XCTAssertTrue(plan.pieces.allSatisfy { $0.daysUsed == 1 })
    }
    func testEmptyForecastMakesNoInventedCapsule() {
        let plan = CapsulePlanner.make(days: [], style: .casual, comfort: 0, garments: [])
        XCTAssertTrue(plan.days.isEmpty); XCTAssertTrue(plan.pieces.isEmpty); XCTAssertTrue(plan.bring.isEmpty)
    }
}
