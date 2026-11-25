import XCTest
@testable import WeatherStyle

final class OutfitEngineTests: XCTestCase {
    func testEveryTemperatureBoundary() {
        for (temperature, expected) in [(-16.0, 0), (-15, 1), (-5, 2), (5, 3), (10, 4), (15, 5), (20, 6), (25, 7), (30, 8), (35, 9)] {
            XCTAssertEqual(TemperatureBand(celsius: temperature).rawValue, expected)
        }
    }
    func testRainReplacesUnsuitableShoesAndOuterwear() {
        for style in FashionStyle.allCases {
            let outfit = OutfitEngine.recommend(.init(temperature: 28, precipitationMm: 2, symbol: "rain"), style: style)
            XCTAssertTrue(outfit.items.contains { $0.name == "Breathable rain shell" })
            XCTAssertFalse(outfit.items.contains { $0.name == "Sandals" })
            XCTAssertTrue(outfit.imageName?.hasPrefix("couple_rain_") == true)
        }
    }
    func testSnowAndWindSafetyOverrides() {
        let snow = OutfitEngine.recommend(.init(temperature: -8, windKmh: 45, precipitationMm: 2, symbol: "snow"), style: .elegant)
        XCTAssertTrue(snow.items.contains { $0.name == "Waterproof winter boots" })
        XCTAssertTrue(snow.bring.contains("Gloves"))
        XCTAssertEqual(Set(snow.bring).count, snow.bring.count)
        let rain = OutfitEngine.recommend(.init(temperature: 12, windKmh: 45, symbol: "rain"))
        XCTAssertFalse(rain.bring.contains("Umbrella"))
        XCTAssertTrue(rain.bring.contains("Rain hood"))
    }
    func testComfortChangesLayersInCorrectDirection() {
        let weather = Conditions(temperature: 17, windKmh: 5)
        XCTAssertLessThan(OutfitEngine.recommend(weather, comfort: 5).band.rawValue, OutfitEngine.recommend(weather, comfort: -5).band.rawValue)
    }
    func testKnownWindChillAndHeatCautions() {
        XCTAssertEqual(Conditions(temperature: 0, windKmh: 20).apparentTemperature, -5.24, accuracy: 0.1)
        XCTAssertNotNil(OutfitEngine.recommend(.init(temperature: 36)).caution)
        XCTAssertNotNil(OutfitEngine.recommend(.init(temperature: 18, symbol: "rainandthunder")).caution)
    }
    func testNoMissingForecastPeriodCrashAndSixHourAmounts() throws {
        let source = #"{"properties":{"meta":{"updated_at":"2026-11-25T12:00:00Z"},"timeseries":[{"time":"2026-11-25T13:00:00Z","data":{"instant":{"details":{"air_temperature":8,"wind_speed":5}},"next_6_hours":{"summary":{"symbol_code":"rain"},"details":{"precipitation_amount":6}}}},{"time":"2026-11-25T19:00:00Z","data":{"instant":{"details":{"air_temperature":7,"cloud_area_fraction":90}}}}]}}"#
        let forecast = try METResponse.decode(Data(source.utf8))
        XCTAssertEqual(forecast.hours.count, 2)
        XCTAssertEqual(forecast.hours[0].intervalHours, 6)
        XCTAssertEqual(forecast.hours[0].conditions.precipitationMm, 6)
        XCTAssertEqual(forecast.hours[0].conditions.windKmh, 18)
        XCTAssertEqual(forecast.hours[1].conditions.label, "Cloudy")
    }
    func testDestinationTimeZoneControlsDailyGrouping() {
        let first = ISO8601DateFormatter().date(from: "2026-11-25T23:45:00Z")!
        let forecast = Forecast(updatedAt: first, hours: [.init(date: first, conditions: .init(temperature: 10)), .init(date: first.addingTimeInterval(3600), conditions: .init(temperature: 11))])
        XCTAssertEqual(forecast.days(timeZone: TimeZone(secondsFromGMT: 0)!).count, 2)
        XCTAssertEqual(forecast.days(timeZone: TimeZone(identifier: "America/New_York")!).count, 1)
    }
    func testWholeCatalogueOfWeatherInputsHasCompleteOutfits() {
        for temperature in stride(from: -30.0, through: 45, by: 1) {
            for symbol in ["clearsky_day", "cloudy", "rain", "snow", "fog", "rainandthunder", "sleet"] {
                for style in FashionStyle.allCases {
                    let look = OutfitEngine.recommend(.init(temperature: temperature, windKmh: 28, humidity: 70, symbol: symbol), style: style)
                    XCTAssertTrue(look.items.contains { $0.category == "Bottom" })
                    XCTAssertTrue(look.items.contains { $0.category == "Footwear" })
                    XCTAssertFalse(look.items.contains { $0.name.isEmpty })
                }
            }
        }
    }
}
