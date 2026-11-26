package com.oanarinaldi.dressbytheweather

import android.content.Intent
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.UiDevice
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.semantics.SemanticsActions
import org.junit.*
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class AppFlowTests {
    @get:Rule val ui=createEmptyComposeRule()
    private lateinit var scenario:ActivityScenario<MainActivity>
    private val context get()=InstrumentationRegistry.getInstrumentation().targetContext
    private fun launch(pro:Boolean=false,reset:Boolean=true) {
        scenario=ActivityScenario.launch(Intent(context,MainActivity::class.java).putExtra("sample",true).putExtra("proPreview",pro).putExtra("reset",reset))
        ui.waitUntil(15000){ui.onAllNodesWithText("Bucharest").fetchSemanticsNodes().isNotEmpty()}
    }
    @After fun close(){if(::scenario.isInitialized)scenario.close()}
    private fun tap(text:String) {val node=ui.onNodeWithText(text);runCatching{node.performScrollTo()};node.performClick();ui.waitForIdle()}
    private fun back(){UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).pressBack();ui.waitForIdle()}
    private fun shot(name:String){ui.waitForIdle();Thread.sleep(600);val dir=File(context.getExternalFilesDir(null),"review").apply{mkdirs()};UiDevice.getInstance(InstrumentationRegistry.getInstrumentation()).takeScreenshot(File(dir,"$name.png")).also { Assert.assertTrue("Screenshot $name",it) }}
    @Test fun freeWeatherSaveSettingsAndScreenshots() {
        launch();shot("01-Today")
        ui.onNodeWithContentDescription("View today’s outfit").performScrollTo().performClick()
        tap("Save this look");ui.onNodeWithText("Saved to your looks").assertExists();tap("Done")
        tap("Forecast");ui.onNodeWithText("Forecast your\nwardrobe.").assertExists();shot("02-Forecast")
        tap("Looks");ui.onNodeWithText("The looks edit.").assertExists();shot("03-Looks")
        tap("Saved looks");ui.onNodeWithText("Bucharest · Everyday",substring=true,ignoreCase=true).assertExists()
        tap("Planner");ui.onNodeWithText("Plan a new trip").assertExists();shot("04-Planner")
        tap("You");ui.onNodeWithText("Temperature comfort").assertExists();shot("05-You")
        ui.onNodeWithText("Fahrenheit (°F)").performScrollTo()
        // Native switch has a toggle action and remains independent of the Pro gate.
        ui.onAllNodes(isToggleable())[0].performClick()
        tap("Today");ui.onAllNodesWithText("82°")[0].assertExists()
    }
    @Test fun proWardrobeWeekCapsuleAndEditorialPersistence() {
        launch(true);tap("Looks");tap("Open your personal Studio");ui.onNodeWithText("The personal\nstyle studio.").assertExists();shot("06-Pro-Studio")
        tap("Your wardrobe");tap("Add a piece")
        ui.onNodeWithText("Name, e.g. cream linen shirt").performTextInput("Cream linen shirt");tap("Save piece")
        ui.onNodeWithText("Cream linen shirt").assertExists();shot("07-Pro-Wardrobe")
        back();tap("Dress the week");ui.onAllNodesWithText("Save this day")[0].performScrollTo().performClick();ui.onNodeWithText("Day saved").assertExists();shot("08-Pro-Week")
        back();tap("The travel capsule");tap("Build a capsule");tap("Create my capsule")
        ui.waitUntil(15000){ui.onAllNodesWithText("Bucharest").fetchSemanticsNodes().isNotEmpty()};tap("Bucharest");ui.onNodeWithText("The capsule").assertExists();shot("09-Pro-Capsule")
        back();back();tap("The editorial library");ui.onNodeWithText("The modern office").assertExists();shot("10-Pro-Library")
        tap("The modern office");ui.onNodeWithText("Start with a column").assertExists();back()
        tap("All photographs");ui.onNodeWithText("214 editorial photographs · inspiration, not a live forecast").assertExists();shot("11-Pro-Collection")
        scenario.close();launch(true,false);tap("Looks");tap("Open your personal Studio");tap("Your wardrobe");ui.onNodeWithText("Cream linen shirt").assertExists()
    }
    @Test fun freePackingAndProGateWithoutPurchase() {
        launch();tap("Planner");tap("Plan a new trip");tap("Choose a destination");tap("Bucharest");tap("Create my packing list")
        ui.waitUntil(45000){ui.onAllNodesWithText("Plan a new trip").fetchSemanticsNodes().isNotEmpty()};ui.onNodeWithText("Bucharest").performScrollTo().performSemanticsAction(SemanticsActions.OnClick){it()};ui.onNodeWithText("Pack thoughtfully").assertExists();shot("12-Free-Packing")
        back();tap("Looks");tap("A little more personal.");ui.onNodeWithText("One purchase. Your own style studio.").assertExists();ui.waitUntil(20000){ui.onAllNodesWithText("Price unavailable").fetchSemanticsNodes().isNotEmpty()};ui.onNodeWithText("Price unavailable").performScrollTo().assertIsNotEnabled();shot("13-Pro-Paywall")
        ui.onNodeWithText("The personal\nstyle studio.").assertDoesNotExist()
        tap("Preview the sample Studio");ui.onNodeWithText("Sample Studio · changes are temporary").assertExists();tap("Your wardrobe");tap("Add a piece");ui.onNodeWithText("Name, e.g. cream linen shirt").performTextInput("Temporary demo shirt");tap("Save piece");ui.onNodeWithText("Temporary demo shirt").assertExists();tap("Exit preview");ui.onNodeWithText("One purchase. Your own style studio.").assertExists();tap("Preview the sample Studio");tap("Your wardrobe");ui.onNodeWithText("Temporary demo shirt").assertDoesNotExist();tap("Exit preview")
    }
    @Test fun worldwideSearchAndLiveForecast() {
        launch();ui.onNodeWithContentDescription("Choose location").performClick()
        ui.onNode(hasSetTextAction()).performTextInput("Sydney Australia")
        ui.waitUntil(30000){ui.onAllNodes(hasText("Sydney",substring=true) and hasClickAction() and !hasSetTextAction()).fetchSemanticsNodes().isNotEmpty()}
        ui.onAllNodes(hasText("Sydney",substring=true) and hasClickAction() and !hasSetTextAction())[0].performClick()
        ui.waitUntil(45000){ui.onAllNodesWithText("Sample forecast · not live weather",substring=true).fetchSemanticsNodes().isEmpty() && ui.onAllNodesWithText("Feels like",substring=true).fetchSemanticsNodes().isNotEmpty()}
        ui.onNodeWithText("Sydney",substring=true).assertExists();shot("14-Live-Sydney")
    }
}
