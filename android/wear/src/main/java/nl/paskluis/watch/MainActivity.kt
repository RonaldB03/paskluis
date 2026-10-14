package nl.paskluis.watch

import android.app.Activity
import android.app.AlertDialog
import android.os.Bundle
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.view.InputDevice
import android.view.MotionEvent
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.*
import com.google.android.gms.wearable.Wearable
import org.json.JSONObject

class MainActivity : Activity() {
    private var selected: String? = null
    private var settings = false
    private var scroll: ScrollView? = null
    private var logos = emptyMap<String, Bitmap>()
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
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
        window.decorView.removeCallbacks(endScan)
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        show()
        super.onPause()
    }
    @Deprecated("Activity back support")
    override fun onBackPressed() {
        if(selected != null || settings) { selected = null; settings = false; show() }
        else super.onBackPressed()
    }
    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_SCROLL && event.isFromSource(InputDevice.SOURCE_ROTARY_ENCODER) && selected == null) {
            scroll?.smoothScrollBy(0,(-event.getAxisValue(MotionEvent.AXIS_SCROLL)*dp(38)).toInt())
            return true
        }
        return super.dispatchGenericMotionEvent(event)
    }
    private fun show() {
        val snapshot = Snapshots.read(this)
        val cards = snapshot?.optJSONArray("cards")
        val rows = if(cards == null) emptyList() else (0 until cards.length()).map { cards.getJSONObject(it) }
        val current = rows.firstOrNull { it.getString("id") == selected }
        if(current != null) {
            scroll = null
            window.attributes = window.attributes.apply { screenBrightness = 1f }
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            // Limit each scan session to 45 seconds, then restore normal screen behaviour.
            window.decorView.removeCallbacks(endScan)
            window.decorView.postDelayed(endScan,45000)
            setContentView(CodeCanvas(current))
            return
        }
        selected = null
        window.decorView.removeCallbacks(endScan)
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.attributes = window.attributes.apply { screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE }
        logos.values.forEach { it.recycle() }
        logos = WatchLogos.read(this,snapshot)
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER_HORIZONTAL
            val p = (resources.displayMetrics.widthPixels*0.12).toInt(); setPadding(p,p,p,p)
            setBackgroundColor(Color.rgb(14,18,28))
        }
        fun label(value: String, size: Float, color: Int = Color.WHITE) = TextView(this).apply {
            text = value; textSize = size; gravity = Gravity.CENTER; setTextColor(color)
            setPadding(0,dp(5),0,dp(7))
        }
        fun action(title: String, click: () -> Unit): Button = Button(this).apply {
            text = title; textSize = 14f; isAllCaps = false; setTextColor(Color.WHITE)
            minHeight = dp(52); gravity = Gravity.CENTER_VERTICAL or Gravity.START
            setPadding(dp(12),dp(8),dp(12),dp(8))
            background = GradientDrawable().apply { setColor(Color.rgb(34,41,58)); cornerRadius = dp(20).toFloat() }
            layoutParams = LinearLayout.LayoutParams(-1,-2).apply { bottomMargin = dp(6) }
            setOnClickListener { click() }
        }
        if(settings) layout.addView(label(text("Instellingen","Settings"),20f))
        else layout.addView(ImageView(this).apply {
            setImageResource(R.drawable.paskluis_logo); contentDescription = "PasKluis"
            scaleType = ImageView.ScaleType.FIT_CENTER
            layoutParams = LinearLayout.LayoutParams(dp(42),dp(42)).apply { bottomMargin = dp(10) }
        })
        if (settings) {
            layout.addView(label(text("Beheer alleen de kopieën op dit horloge.","Manage only the copies on this watch."),12f,Color.LTGRAY))
            fun confirm(reset: Boolean) {
                AlertDialog.Builder(this@MainActivity)
                    .setTitle(if(reset) text("Opnieuw koppelen?","Reconnect?") else text("Pasjes wissen?","Erase cards?"))
                    .setMessage(text("De passen op dit horloge worden gewist. Je telefoonpassen blijven bewaard.","Cards on this watch will be erased. Your phone cards are kept."))
                    .setPositiveButton(text("Wissen","Erase")) { _,_ -> Snapshots.erase(this@MainActivity,reset); settings = false; show() }
                    .setNegativeButton(text("Annuleren","Cancel"),null).show()
            }
            layout.addView(action(text("Pasjes wissen","Erase cards")) { confirm(false) })
            layout.addView(action(text("Opnieuw koppelen","Reconnect")) { confirm(true) })
            layout.addView(action(text("Terug naar passen","Back to cards")) { settings = false; show() })
        } else {
        layout.addView(label(if(rows.isEmpty()) text("Nog geen passen","No cards yet") else text("${rows.size} passen · offline beschikbaar","${rows.size} cards · available offline"),12f,Color.LTGRAY))
        if(rows.isEmpty()) layout.addView(TextView(this).apply {
            text = text("Kies pasjes op je telefoon bij Instellingen › Smartwatch.","Choose cards on your phone under Settings › Smartwatch.")
            gravity = Gravity.CENTER; setTextColor(Color.LTGRAY); textSize = 14f
            setPadding(0,dp(12),0,dp(16))
        })
        for(card in rows.sortedWith(compareByDescending<JSONObject> { it.optBoolean("favorite") }.thenBy { it.getString("name") })) {
            val name = card.getString("name")
            val button = action((if(card.optBoolean("favorite")) "★ " else "")+name) { selected = card.getString("id"); show() }
            val logo = logos[card.getString("id")]
            val icon = if (logo != null) BitmapDrawable(resources,logo) else {
                val tile = Bitmap.createBitmap(64,64,Bitmap.Config.ARGB_8888)
                Canvas(tile).apply {
                    drawColor(Color.rgb(78,88,140))
                    drawText(name.take(1).uppercase(),32f,44f,Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        color=Color.WHITE; textSize=38f; textAlign=Paint.Align.CENTER
                    })
                }
                BitmapDrawable(resources,tile)
            }
            val round = Bitmap.createBitmap(64,64,Bitmap.Config.ARGB_8888)
            Canvas(round).apply {
                drawCircle(32f,32f,32f,Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
                // Fit the entire square within the circle; never crop the brand.
                icon.setBounds(10,10,54,54); icon.draw(this)
            }
            val roundIcon = BitmapDrawable(resources,round)
            roundIcon.setBounds(0,0,dp(32),dp(32)); button.setCompoundDrawables(roundIcon,null,null,null)
            button.compoundDrawablePadding = dp(9); button.maxLines = 2
            layout.addView(button)
        }
        layout.addView(action(text("Instellingen","Settings")) { settings = true; show() })
        }
        scroll = ScrollView(this).apply { setBackgroundColor(Color.rgb(14,18,28)); isVerticalScrollBarEnabled = false; addView(layout); isFocusableInTouchMode = true }
        setContentView(scroll); scroll?.requestFocus()
    }
    private val endScan = Runnable { selected = null; show() }
    override fun onDestroy() { window.decorView.removeCallbacks(endScan); logos.values.forEach { it.recycle() }; super.onDestroy() }

    inner class CodeCanvas(private val card: JSONObject): View(this) {
        private val paint = Paint().apply { isAntiAlias = false }
        init { contentDescription = card.getString("name"); setOnClickListener { selected = null; show() } }
        override fun onDraw(canvas: Canvas) {
            canvas.drawColor(Color.WHITE)
            val w = card.getInt("width"); val h = card.getInt("height")
            val q = if(h == 1) 10 else 4
            // Fit the full quiet zone within the round display. Never interpolate modules.
            val usable = (minOf(width,height)*(if(h == 1) 0.90 else 0.70)).toInt()
            val m = minOf(usable/(w+2*q), if(h == 1) Int.MAX_VALUE else usable/(h+2*q))
            paint.color = Color.BLACK
            paint.textAlign = Paint.Align.CENTER; paint.textSize = 12*resources.displayMetrics.scaledDensity
            if(m < 1) { canvas.drawText(text("Gebruik je telefoon","Use your phone"),width/2f,height/2f,paint); return }
            val bh = if(h == 1) (height*0.34).toInt() else h*m
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
            paint.isAntiAlias = true
            canvas.drawText(name,width/2f,(height*0.16).toFloat(),paint)
            val code = card.getString("code")
            if(paint.measureText(code) <= usable) canvas.drawText(code,width/2f,(height*0.84).toFloat(),paint)
            paint.isAntiAlias = false
        }
    }
}
