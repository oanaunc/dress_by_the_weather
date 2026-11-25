import XCTest

final class AppFlowTests: XCTestCase {
    @MainActor func testPreviewSaveAndPreferences() throws {
        let app = XCUIApplication(); app.launchArguments = ["--preview", "--uitesting-reset"]; app.launch()
        XCTAssertTrue(app.otherElements["previewBanner"].waitForExistence(timeout: 10) || app.staticTexts["Sample forecast · not live weather"].waitForExistence(timeout: 5))
        app.buttons["todayOutfit"].tap()
        let save = app.buttons["saveLook"]
        for _ in 0..<7 { if save.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 5)); save.tap()
        XCTAssertTrue(app.buttons["Saved to your looks"].exists)
        app.buttons["Done"].tap()
        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.staticTexts["Temperature comfort"].waitForExistence(timeout: 5))
        app.switches["Fahrenheit (°F)"].tap()
        app.tabBars.buttons["Forecast"].tap()
        XCTAssertTrue(app.staticTexts["Forecast your\nwardrobe."].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Forecast"; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testWorldwideSearchAndDestinationPacking() throws {
        let app = XCUIApplication(); app.launchArguments = ["--preview", "--uitesting-reset"]; app.launch()
        app.buttons["chooseLocation"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Sydney Australia")
        let sydney = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Sydney'")).firstMatch
        XCTAssertTrue(sydney.waitForExistence(timeout: 25)); sydney.tap()
        XCTAssertTrue(app.buttons["chooseLocation"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["chooseLocation"].label.contains("Sydney"))
        app.tabBars.buttons["Planner"].tap(); app.buttons["newTrip"].tap()
        app.buttons["Choose a destination"].tap()
        let destination = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Sydney'")).firstMatch
        XCTAssertTrue(destination.waitForExistence(timeout: 5)); destination.tap()
        app.buttons["Create my packing list"].tap()
        XCTAssertTrue(app.buttons["newTrip"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'packed'")).firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Destination packing"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
