package com.oanarinaldi.dressbytheweather

import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Runs against the separately installed, signed and R8-optimized production APK. */
@RunWith(AndroidJUnit4::class)
class ReleaseSmokeTests {
    @Test fun publicPreviewWorksWithoutGrantingPaidEntitlement() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        val device=UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        context.startActivity(Intent().setClassName("com.oanarinaldi.dressbytheweather","com.oanarinaldi.dressbytheweather.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        fun tap(text:String) {
            fun find()=(device.findObject(By.text(text))?:device.findObject(By.desc(text)))?.takeIf {
                val bounds=it.visibleBounds
                bounds.height()>20 && bounds.width()>20 && bounds.centerY() in 90..device.displayHeight-100
            }
            device.wait(Until.hasObject(By.pkg("com.oanarinaldi.dressbytheweather")),10000)
            var item=find()
            if(item==null)repeat(6){if(item==null){device.swipe(device.displayWidth/2,device.displayHeight*3/4,device.displayWidth/2,device.displayHeight/3,30);device.waitForIdle();item=find()}}
            if(item==null){device.dumpWindowHierarchy(File(context.getExternalFilesDir(null),"release-failure.xml"));device.takeScreenshot(File(context.getExternalFilesDir(null),"release-failure.png"))}
            assertNotNull("Visible release control: $text",item)
            device.waitForIdle();Thread.sleep(400)
            var target=item!!
            while(!target.isClickable && target.parent!=null)target=target.parent
            target.click();Thread.sleep(500);device.waitForIdle()
        }
        tap("Explore the sample edition")
        device.takeScreenshot(File(context.getExternalFilesDir(null),"release-after-onboarding.png"))
        assertTrue("Sample onboarding completed",device.wait(Until.hasObject(By.desc("Looks")),15000)||device.wait(Until.hasObject(By.text("Looks")),15000))
        tap("Looks");tap("A little more personal.");tap("Preview the sample Studio")
        assertTrue(device.wait(Until.hasObject(By.text("Sample Studio · changes are temporary")),10000))
        tap("Your wardrobe");tap("Add a piece")
        val input=device.wait(Until.findObject(By.clazz("android.widget.EditText")),10000);assertNotNull(input);input!!.text="Release demo piece"
        tap("Save piece");assertTrue(device.wait(Until.hasObject(By.text("Release demo piece")),10000))
        tap("Exit preview");assertTrue(device.wait(Until.hasObject(By.text("One purchase. Your own style studio.")),10000))
        tap("Preview the sample Studio");tap("Your wardrobe");assertFalse(device.hasObject(By.text("Release demo piece")));tap("Exit preview")
    }
}
