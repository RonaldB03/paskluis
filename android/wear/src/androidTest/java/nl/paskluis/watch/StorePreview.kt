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
            val cards = JSONArray().put(fixtures.getJSONObject(0).put("name", "Voorbeeldpas"))
                .put(fixtures.getJSONObject(8).put("name", "Voorbeeld QR"))
            val snapshot = JSONObject().put("schema", 1).put("owner", "emulator-preview")
                .put("revision", 1).put("language", "nl").put("cards", cards)
            WatchVault(targetContext, "cards").write(snapshot.toString())
            check(Snapshots.read(targetContext)?.getJSONArray("cards")?.length() == 2)
            val activity = startActivitySync(Intent(targetContext, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            waitForIdleSync()
            Thread.sleep(1500)
            capture(activity, "wear-passes.png")
            runOnMainSync { findButton(activity.window.decorView, "Voorbeeld QR")!!.performClick() }
            waitForIdleSync()
            capture(activity, "wear-qr.png")
            runOnMainSync { Snapshots.erase(targetContext); activity.finish() }
            check(Snapshots.read(targetContext)?.getJSONArray("cards")?.length() == 0)
            finish(Activity.RESULT_OK, Bundle().apply { putString("stream", "Wear preview and encrypted storage/erase checks passed\n") })
        } catch (failure: Throwable) {
            finish(Activity.RESULT_CANCELED, Bundle().apply { putString("stream", failure.stackTraceToString()) })
        }
    }
    private fun findButton(view: View, label: String): Button? {
        if (view is Button && view.text.toString().contains(label)) return view
        if (view is ViewGroup) for (i in 0 until view.childCount) findButton(view.getChildAt(i), label)?.let { return it }
        return null
    }
    private fun capture(activity: Activity, name: String) {
        runOnMainSync {
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
}
