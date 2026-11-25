import XCTest

final class AppFlowTests: XCTestCase {
    @MainActor func testPreviewSaveAndPreferences() throws {
        let app = XCUIApplication(); app.launchArguments = ["--preview"]; app.launch()
        XCTAssertTrue(app.otherElements["previewBanner"].waitForExistence(timeout: 10) || app.staticTexts["Sample forecast · not live weather"].waitForExistence(timeout: 5))
        app.buttons["todayOutfit"].tap()
        let save = app.buttons["saveLook"]
        app.swipeUp(); app.swipeUp()
        if !save.isHittable { app.swipeUp() }
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
}
