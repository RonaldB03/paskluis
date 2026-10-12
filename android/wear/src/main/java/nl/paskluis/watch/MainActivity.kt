package nl.paskluis.watch

import android.app.Activity
import android.app.AlertDialog
import android.os.Bundle
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.*
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject

class MainActivity : Activity() {
    private var selected: String? = null
    private fun text(nl: String,en: String) = if(Snapshots.read(this)?.optString("language") == "en") en else nl
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        show()
    }
    override fun onResume() {
        super.onResume()
        Snapshots.onChanged = { runOnUiThread { show() } }
        Wearable.getDataClient(this).dataItems.addOnSuccessListener { items ->
            items.use { for(item in it) Snapshots.receive(this,item) }; show()
        }
        show()
    }
    override fun onPause() {
        Snapshots.onChanged = null
        // Codes must disappear when the device sleeps / ambient mode takes over.
        selected = null
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        show()
        super.onPause()
    }
    @Deprecated("Activity back support")
    override fun onBackPressed() { if(selected != null) { selected = null; show() } else super.onBackPressed() }
    private fun show() {
        val snapshot = Snapshots.read(this)
        val cards = snapshot?.optJSONArray("cards")
        val rows = if(cards == null) emptyList() else (0 until cards.length()).map { cards.getJSONObject(it) }
        val current = rows.firstOrNull { it.getString("id") == selected }
        if(current != null) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            // Limit each scan session to 45 seconds, then restore normal screen behaviour.
            window.decorView.removeCallbacks(endScan)
            window.decorView.postDelayed(endScan,45000)
            setContentView(CodeCanvas(current))
            return
        }
        selected = null
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER_HORIZONTAL
            val p = (resources.displayMetrics.widthPixels*0.13).toInt(); setPadding(p,p,p,p)
        }
        layout.addView(TextView(this).apply { text = "PasKluis"; textSize = 22f; gravity = Gravity.CENTER })
        if(rows.isEmpty()) layout.addView(TextView(this).apply {
            text = text("Kies pasjes op je telefoon bij Instellingen › Smartwatch.","Choose cards on your phone under Settings › Smartwatch.")
            gravity = Gravity.CENTER
        })
        for(card in rows) layout.addView(Button(this).apply {
            text = (if(card.optBoolean("favorite")) "★ " else "")+card.getString("name")
            isAllCaps = false; setOnClickListener { selected = card.getString("id"); show() }
        })
        layout.addView(Button(this).apply {
            text = text("Pasjes wissen","Erase cards"); isAllCaps = false
            setOnClickListener { Snapshots.erase(this@MainActivity); show() }
        })
        layout.addView(Button(this).apply {
            text = text("Opnieuw koppelen","Reconnect"); isAllCaps = false
            setOnClickListener { AlertDialog.Builder(this@MainActivity)
                .setMessage(text("Wis alle pasjes en koppel opnieuw?","Erase all cards and reconnect?"))
                .setPositiveButton("OK") { _,_ -> Snapshots.erase(this@MainActivity,true); show() }
                .setNegativeButton(text("Annuleren","Cancel"),null).show() }
        })
        setContentView(ScrollView(this).apply { addView(layout) })
    }
    private val endScan = Runnable { selected = null; show() }
    override fun onDestroy() { window.decorView.removeCallbacks(endScan); super.onDestroy() }

    inner class CodeCanvas(private val card: JSONObject): View(this) {
        private val paint = Paint().apply { isAntiAlias = false }
        init { contentDescription = card.getString("name"); setOnClickListener { selected = null; show() } }
        override fun onDraw(canvas: Canvas) {
            canvas.drawColor(Color.WHITE)
            val w = card.getInt("width"); val h = card.getInt("height")
            val q = if(h == 1) 10 else 4
            val usable = (minOf(width,height)*0.78).toInt()
            val m = minOf(usable/(w+2*q), if(h == 1) Int.MAX_VALUE else usable/(h+2*q))
            paint.color = Color.BLACK
            paint.textAlign = Paint.Align.CENTER; paint.textSize = 12*resources.displayMetrics.scaledDensity
            if(m < 1) { canvas.drawText(text("Gebruik je telefoon","Use your phone"),width/2f,height/2f,paint); return }
            val bh = if(h == 1) (height*0.30).toInt() else h*m
            val x0 = (width-w*m)/2; val y0 = (height-bh)/2
            val bits = card.getString("bits")
            for(y in 0 until h) for(x in 0 until w) {
                val i = y*w+x
                if(bits[i/4].digitToInt(16) and (1 shl (3-i%4)) != 0) {
                    val cellH = if(h == 1) bh else m
                    canvas.drawRect((x0+x*m).toFloat(),(y0+y*cellH).toFloat(),(x0+(x+1)*m).toFloat(),(y0+(y+1)*cellH).toFloat(),paint)
                }
            }
            val name = android.text.TextUtils.ellipsize(card.getString("name"),android.text.TextPaint(paint),usable.toFloat(),android.text.TextUtils.TruncateAt.END).toString()
            canvas.drawText(name,width/2f,(height*0.12).toFloat(),paint)
            val code = card.getString("code")
            if(paint.measureText(code) <= usable) canvas.drawText(code,width/2f,(height*0.9).toFloat(),paint)
        }
    }
}
