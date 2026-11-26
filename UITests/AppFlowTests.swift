import XCTest
import StoreKitTest

final class AppFlowTests: XCTestCase {
    // Records an explanatory App Review walkthrough. Sample mode avoids presenting
    // a recording's weather as a current forecast; Pro preview exists only in Debug.
    @MainActor func testReviewerWalkthrough() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--preview", "--uitesting-reset"]; app.launch()
        XCTAssertTrue(app.buttons["todayOutfit"].waitForExistence(timeout: 15))
        func chapter(_ name: String) { print("REVIEW_CHAPTER: \(Date().timeIntervalSince1970): \(name)"); Thread.sleep(forTimeInterval: 3) }
        chapter("Free worldwide weather and daily outfit advice")
        app.buttons["todayOutfit"].tap(); chapter("Clothing checklist and why this outfit works")
        app.swipeUp(); Thread.sleep(forTimeInterval: 2); app.buttons["Done"].tap()
        app.buttons["Forecast"].firstMatch.tap(); chapter("Hourly and daily forecasts")
        app.buttons["Planner"].firstMatch.tap(); chapter("Basic travel packing stays free")
        openStudio(app)
        let buy = app.buttons["buyPro"]; reveal(buy, in: app)
        chapter("Optional Pro: one purchase, no subscription; restore anytime")
        app.terminate(); app.launchArguments = ["--preview", "--uitesting-reset", "--pro-preview"]; app.launch(); openStudio(app)
        chapter("Pro: your personal style studio")
        let wardrobe = app.buttons["personalWardrobe"]; reveal(wardrobe, in: app); wardrobe.tap()
        app.buttons["addGarment"].tap()
        let name = app.textFields["garmentName"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Cream linen shirt")
        app.buttons["saveGarment"].tap(); chapter("Private wardrobe with local photos and weather matching")
        app.navigationBars.buttons.firstMatch.tap()
        let week = app.buttons["weeklyPlanner"]; reveal(week, in: app); week.tap()
        let saveDay = app.buttons["savePlannedDay"].firstMatch; reveal(saveDay, in: app); saveDay.tap(); chapter("Plan occasions and looks for the week")
        app.navigationBars.buttons.firstMatch.tap()
        let capsule = app.buttons["capsulePlanner"]; reveal(capsule, in: app); capsule.tap()
        app.buttons["newCapsule"].tap(); chapter("Choose a destination, dates and occasion")
        app.buttons["createCapsule"].tap(); XCTAssertTrue(app.buttons["newCapsule"].waitForExistence(timeout: 15))
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Bucharest' AND label CONTAINS 'days'")).firstMatch
        reveal(saved, in: app); saved.tap(); chapter("Reuse suitable pieces in a travel capsule")
        app.navigationBars.buttons.firstMatch.tap(); app.navigationBars.buttons.firstMatch.tap()
        let library = app.buttons["editorialLibrary"]; reveal(library, in: app); library.tap(); chapter("214 fashion photographs and eight styling guides")
        let office = app.buttons.matching(NSPredicate(format: "label CONTAINS 'The modern office'")).firstMatch
        XCTAssertTrue(office.waitForExistence(timeout: 5)); office.tap(); chapter("Original editorial guides with weather-aware inspiration")
        app.swipeUp(); Thread.sleep(forTimeInterval: 3)
        print("REVIEW_VIDEO_END: \(Date().timeIntervalSince1970)")
    }
    @MainActor func testProPurchaseCancellationRestoreAndRefund() async throws {
        continueAfterFailure = false
        let session = try SKTestSession(configurationFileNamed: "DressPro")
        session.resetToDefaultState(); session.disableDialogs = true; session.clearTransactions()
        let app = XCUIApplication(); app.launchArguments = ["--preview", "--uitesting-reset"]; app.launch()
        openStudio(app)
        let buy = app.buttons["buyPro"]
        XCTAssertTrue(buy.waitForExistence(timeout: 15)); reveal(buy, in: app)
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: buy)], timeout: 15)
        XCTAssertTrue(buy.label.contains("19.99") || buy.label.contains("19,99"))
        capture(app, "Pro-Paywall")
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        buy.tap()
        await fulfillment(of: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: buy)], timeout: 10)
        XCTAssertFalse(app.buttons["weeklyPlanner"].exists)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        buy.tap()
        XCTAssertTrue(app.buttons["weeklyPlanner"].waitForExistence(timeout: 15))
        capture(app, "Pro-Studio")
        app.terminate(); app.launch(); openStudio(app)
        XCTAssertTrue(app.buttons["weeklyPlanner"].waitForExistence(timeout: 15), "Verified StoreKit entitlement survives relaunch and local preference reset")
        app.navigationBars.buttons.firstMatch.tap(); app.buttons["You"].firstMatch.tap()
        let restore = app.buttons["Restore Pro Purchase"]; reveal(restore, in: app); restore.tap()
        XCTAssertTrue(app.staticTexts["Your Pro purchase is restored."].waitForExistence(timeout: 15))
        app.buttons["settingsPro"].tap()
        XCTAssertTrue(app.buttons["weeklyPlanner"].waitForExistence(timeout: 10))
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        XCTAssertTrue(app.buttons["buyPro"].waitForExistence(timeout: 15), "Refund must revoke access")
        session.clearTransactions()
    }
    @MainActor func testProWardrobeWeekCapsuleAndLibrary() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--preview", "--uitesting-reset", "--pro-preview"]; app.launch()
        openStudio(app)
        let wardrobe = app.buttons["personalWardrobe"]; reveal(wardrobe, in: app); wardrobe.tap()
        app.buttons["addGarment"].tap()
        let name = app.textFields["garmentName"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText("Cream linen shirt")
        app.buttons["saveGarment"].tap()
        let savedPiece = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cream linen shirt'")).firstMatch
        reveal(savedPiece, in: app); XCTAssertTrue(savedPiece.exists)
        capture(app, "Pro-Wardrobe")
        app.navigationBars.buttons.firstMatch.tap()
        let week = app.buttons["weeklyPlanner"]; reveal(week, in: app); week.tap()
        let saveDay = app.buttons["savePlannedDay"].firstMatch; reveal(saveDay, in: app); saveDay.tap()
        let savedDay = app.buttons.matching(NSPredicate(format: "identifier == 'savePlannedDay' AND label CONTAINS 'Day saved'")).firstMatch
        XCTAssertTrue(savedDay.waitForExistence(timeout: 5))
        capture(app, "Pro-Week")
        app.navigationBars.buttons.firstMatch.tap()
        let capsule = app.buttons["capsulePlanner"]; reveal(capsule, in: app); capsule.tap()
        app.buttons["newCapsule"].tap(); app.buttons["createCapsule"].tap()
        XCTAssertTrue(app.buttons["newCapsule"].waitForExistence(timeout: 15))
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Bucharest' AND label CONTAINS 'days'")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); reveal(saved, in: app); saved.tap()
        XCTAssertTrue(app.staticTexts["The capsule"].waitForExistence(timeout: 5)); capture(app, "Pro-Capsule")
        app.navigationBars.buttons.firstMatch.tap(); app.navigationBars.buttons.firstMatch.tap()
        let library = app.buttons["editorialLibrary"]; reveal(library, in: app); library.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'The modern office'")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "Pro-Lookbook")
        app.terminate(); app.launchArguments = ["--preview", "--pro-preview"]; app.launch(); openStudio(app)
        let reopened = app.buttons["personalWardrobe"]; reveal(reopened, in: app); reopened.tap()
        let persisted = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cream linen shirt'")).firstMatch
        reveal(persisted, in: app); XCTAssertTrue(persisted.exists, "Wardrobe persists on device")
    }
    @MainActor private func openStudio(_ app: XCUIApplication) {
        app.buttons["Looks"].firstMatch.tap()
        let studio = app.buttons["openProStudio"]; XCTAssertTrue(studio.waitForExistence(timeout: 10)); reveal(studio, in: app); studio.tap()
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 { if element.isHittable { return }; app.swipeUp() }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ title: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = title; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testStoreScreenshots() throws {
        let app = XCUIApplication(); app.launchArguments = ["--preview", "--uitesting-reset"]; app.launch()
        XCTAssertTrue(app.buttons["todayOutfit"].waitForExistence(timeout: 15))
        func capture(_ name: String) {
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "Store-\(name)"; shot.lifetime = .keepAlways; add(shot)
        }
        capture("Today")
        for tab in ["Forecast", "Looks", "Planner", "You"] {
            app.buttons[tab].firstMatch.tap()
            if tab == "Planner" { XCTAssertTrue(app.buttons["newTrip"].waitForExistence(timeout: 5)) }
            capture(tab)
        }
    }
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
