package nl.paskluis.watch

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** Emulator-only instrumentation: real UI, synthetic cards, no release hooks. */
class StorePreview : Instrumentation() {
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    override fun onStart() {
        try {
            val fixtures = JSONArray(context.assets.open("watch-fixtures.json").bufferedReader().use { it.readText() })
            val cards = JSONArray().put(fixtures.getJSONObject(0).put("name", "Albert Heijn").put("favorite",true))
                .put(fixtures.getJSONObject(fixtures.length()-1).put("name", "Voorbeeld QR").put("category","qr"))
                .put(JSONObject(fixtures.getJSONObject(0).toString()).put("id","gift").put("name","Cadeau test").put("category","gift"))
            for ((index,name) in listOf("Gall & Gall","Sligro","Makro","HEMA").withIndex()) cards.put(JSONObject(cards.getJSONObject(0).toString()).put("id","extra-$index").put("name",name).put("favorite",false))
            val snapshot = JSONObject().put("schema", 1).put("owner", "emulator-preview")
                .put("revision", 1).put("language", "nl").put("cards", cards)
            WatchVault(targetContext, "cards").write(snapshot.toString())
            val originalLogo = context.assets.open("albert_heijn.png").use { android.graphics.BitmapFactory.decodeStream(it) }
            val logo = Bitmap.createScaledBitmap(originalLogo,48,48,true)
            val png = java.io.ByteArrayOutputStream().apply { logo.compress(Bitmap.CompressFormat.PNG,100,this) }.toByteArray()
            val logoPayload = JSONObject().put(cards.getJSONObject(0).getString("id"),android.util.Base64.encodeToString(png,android.util.Base64.NO_WRAP))
            WatchLogos.store(targetContext,snapshot,logoPayload.toString())
            val restored = WatchLogos.read(targetContext,snapshot)
            check(restored.size == 1); restored.values.forEach { it.recycle() }
            val otherOwner = JSONObject(snapshot.toString()).put("owner","other-preview")
            check(WatchLogos.read(targetContext,otherOwner).isEmpty())
            targetContext.getSharedPreferences("watch-state",0).edit().putLong("receivedAt",System.currentTimeMillis()).commit()
            check(Snapshots.read(targetContext)?.getJSONArray("cards")?.length() == 7)
            val activity = startActivitySync(Intent(targetContext, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            waitForIdleSync()
            Thread.sleep(1500)
            var labels = ""
            runOnMainSync {
                labels = visibleLabels(activity.window.decorView)
                val header = findBrand(activity.window.decorView)!!
                val mark = Bitmap.createBitmap(header.width,header.height,Bitmap.Config.ARGB_8888)
                header.draw(Canvas(mark))
                check(android.graphics.Color.alpha(mark.getPixel(1,1)) == 0) { "PasKluis header must have transparent round corners" }
                check(android.graphics.Color.alpha(mark.getPixel(mark.width/2,mark.height/2)) > 0)
                mark.recycle()
            }
            check(!labels.contains("offline beschikbaar")) { labels }
            check(!labels.contains("Laatst ontvangen")) { labels }
            capture(activity, "wear-passes.png")
            var scrolledY = 0
            var scrollDimensions = ""
            runOnMainSync {
                val scroller = findScroll(activity.window.decorView)!!
                scroller.isSmoothScrollingEnabled = false
                scroller.scrollTo(0, scroller.getChildAt(0).height)
                scrolledY = scroller.scrollY
                scrollDimensions = "viewport=${scroller.height}, content=${scroller.getChildAt(0).height}"
                captureOnMain(activity, "wear-scroll.png")
                scroller.scrollTo(0, 0)
            }
            check(scrolledY > 0) { "Multiple cards must scroll: $scrollDimensions" }
            waitForIdleSync()
            runOnMainSync {
                findButton(activity.window.decorView, "Albert Heijn")!!.performClick()
                check(activity.window.attributes.screenBrightness == 1f) { "Scan brightness: ${activity.window.attributes.screenBrightness}" }
            }
            waitForIdleSync()
            capture(activity,"wear-barcode.png")
            runOnMainSync {
                val time=android.os.SystemClock.uptimeMillis()
                val w=activity.resources.displayMetrics.widthPixels.toFloat()
                val h=activity.resources.displayMetrics.heightPixels.toFloat()
                val down=android.view.MotionEvent.obtain(time,time,android.view.MotionEvent.ACTION_DOWN,w*.8f,h*.5f,0)
                val up=android.view.MotionEvent.obtain(time,time+300,android.view.MotionEvent.ACTION_UP,w*.2f,h*.5f,0)
                activity.dispatchTouchEvent(down); activity.dispatchTouchEvent(up); down.recycle(); up.recycle()
                check(findCode(activity.window.decorView)?.contentDescription == "Gall & Gall") { "Swipe must select the next loyalty card" }
            }
            capture(activity,"wear-swiped-code.png")
            runOnMainSync {
                activity.onBackPressed()
                check(activity.window.attributes.screenBrightness == WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE) { "Restored brightness: ${activity.window.attributes.screenBrightness}" }
            }
            waitForIdleSync()
            runOnMainSync { findButton(activity.window.decorView, "QR")!!.performClick() }
            waitForIdleSync()
            capture(activity, "wear-qr-list.png")
            runOnMainSync { findButton(activity.window.decorView, "Voorbeeld QR")!!.performClick() }
            waitForIdleSync()
            capture(activity, "wear-qr.png")
            runOnMainSync { activity.onBackPressed() }
            waitForIdleSync()
            runOnMainSync { findButton(activity.window.decorView,"🎁")!!.performClick() }
            waitForIdleSync()
            capture(activity,"wear-gift-list.png")
            runOnMainSync { findButton(activity.window.decorView,"Cadeau test")!!.performClick() }
            waitForIdleSync()
            capture(activity,"wear-gift.png")
            runOnMainSync { activity.onBackPressed() }
            waitForIdleSync()
            runOnMainSync { findButton(activity.window.decorView,"Instellingen")!!.performClick() }
            waitForIdleSync()
            capture(activity,"wear-settings.png")
            runOnMainSync { Snapshots.erase(targetContext); activity.finish() }
            check(Snapshots.read(targetContext)?.getJSONArray("cards")?.length() == 0)
            check(WatchLogos.read(targetContext,snapshot).isEmpty())
            finish(Activity.RESULT_OK, Bundle().apply { putString("stream", "Wear preview and encrypted storage/erase checks passed\n") })
        } catch (failure: Throwable) {
            finish(Activity.RESULT_CANCELED, Bundle().apply { putString("stream", failure.stackTraceToString()) })
        }
    }
    private fun visibleLabels(view: View): String {
        var result = if(view is android.widget.TextView) view.text.toString() else ""
        if(view is ViewGroup) for(i in 0 until view.childCount) result += " " + visibleLabels(view.getChildAt(i))
        return result
    }
    private fun findBrand(view: View): View? {
        if(view is android.widget.ImageView && view.contentDescription == "PasKluis") return view
        if(view is ViewGroup) for(i in 0 until view.childCount) findBrand(view.getChildAt(i))?.let { return it }
        return null
    }
    private fun findScroll(view: View): android.widget.ScrollView? {
        if(view is android.widget.ScrollView) return view
        if(view is ViewGroup) for(i in 0 until view.childCount) findScroll(view.getChildAt(i))?.let { return it }
        return null
    }
    private fun findButton(view: View, label: String): Button? {
        if (view is Button && view.text.toString().contains(label)) return view
        if (view is ViewGroup) for (i in 0 until view.childCount) findButton(view.getChildAt(i), label)?.let { return it }
        return null
    }
    private fun findCode(view: View): View? {
        if(view is MainActivity.CodeCanvas) return view
        if(view is ViewGroup) for(i in 0 until view.childCount) { findCode(view.getChildAt(i))?.let { return it } }
        return null
    }
    private fun capture(activity: Activity, name: String) {
        runOnMainSync { captureOnMain(activity, name) }
    }
    private fun captureOnMain(activity: Activity, name: String) {
            check(activity.window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0)
            val view = activity.window.decorView
            check(view.width > 0 && view.height > 0)
            val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
            view.draw(Canvas(bitmap))
            val folder = File(targetContext.filesDir, "store-preview").apply { mkdirs() }
            File(folder, name).outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            bitmap.recycle()
    }
}
