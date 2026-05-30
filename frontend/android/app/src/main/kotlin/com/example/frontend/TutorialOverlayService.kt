package com.example.frontend

import android.animation.ValueAnimator
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.graphics.Paint.Align
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import androidx.core.app.NotificationCompat
import org.json.JSONArray

class TutorialOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var visualOverlay: VisualOverlayView? = null
    private var navButtonView: NavButtonView? = null
    private var closeButtonView: CloseButtonView? = null
    private var agentButtonView: AgentButtonView? = null
    private var screenW = 0
    private var screenH = 0
    private var savedStepsJson = "[]"

    companion object {
        private var instance: TutorialOverlayService? = null
        private const val CHANNEL_ID = "tutorial_overlay"
        private const val NOTIFICATION_ID = 1001

        fun advanceStep() {
            instance?.handler?.post {
                instance?.visualOverlay?.advanceStepExternally()
            }
        }

        fun stop() {
            instance?.stopSelf()
        }

        fun updateTargetRect(left: Int, top: Int, right: Int, bottom: Int) {
            instance?.handler?.post {
                instance?.visualOverlay?.updateTargetRect(left, top, right, bottom)
            }
        }

        fun updateInstruction(text: String) {
            instance?.handler?.post {
                instance?.visualOverlay?.updateInstruction(text)
            }
        }

        fun takeScreenshot(): String? {
            return TutorialAccessibilityService.takeScreenshotBase64()
        }
    }

    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AI 教程引导")
            .setContentText("正在引导操作...")
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        screenW = windowManager!!.currentWindowMetrics.bounds.width()
        screenH = windowManager!!.currentWindowMetrics.bounds.height()

        val stepsJson = intent?.getStringExtra("steps") ?: "[]"

        addVisualOverlay(stepsJson)
        addCloseButton()

        return START_NOT_STICKY
    }

    private fun addVisualOverlay(json: String) {
        savedStepsJson = json
        visualOverlay = VisualOverlayView(this, json, screenW, screenH)
        visualOverlay!!.onStepChanged = { index, total ->
            navButtonView?.updateState(index, total)
        }
        visualOverlay!!.onAllStepsDone = {
            stopSelf()
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        windowManager!!.addView(visualOverlay, params)
        addNavButton()
    }

    private fun addNavButton() {
        navButtonView = NavButtonView(this) {
            visualOverlay?.advanceStep()
        }
        val dp = resources.displayMetrics.density
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        params.y = (40 * dp).toInt()
        windowManager!!.addView(navButtonView, params)
    }

    private fun addCloseButton() {
        closeButtonView = CloseButtonView(this)
        closeButtonView!!.onClick = {
            stopSelf()
        }
        val dp = resources.displayMetrics.density
        val params = WindowManager.LayoutParams(
            (44 * dp).toInt(),
            (44 * dp).toInt(),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.START
        params.x = (16 * dp).toInt()
        params.y = (16 * dp).toInt()
        windowManager!!.addView(closeButtonView, params)
    }

    private fun minimizeToAgent() {
        visualOverlay?.let { windowManager?.removeView(it) }
        visualOverlay = null
        navButtonView?.let { windowManager?.removeView(it) }
        navButtonView = null

        addAgentButton()
    }

    private fun addAgentButton() {
        if (agentButtonView != null) return
        agentButtonView = AgentButtonView(this)
        agentButtonView!!.onClick = {
            restoreFromAgent()
        }
        agentButtonView!!.startBreathing()
        val dp = resources.displayMetrics.density
        val params = WindowManager.LayoutParams(
            (52 * dp).toInt(),
            (52 * dp).toInt(),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.TOP or Gravity.END
        params.x = (16 * dp).toInt()
        params.y = (16 * dp).toInt()
        windowManager!!.addView(agentButtonView, params)
    }

    private fun restoreFromAgent() {
        agentButtonView?.stopBreathing()
        agentButtonView?.let { windowManager?.removeView(it) }
        agentButtonView = null

        addVisualOverlay(savedStepsJson)
    }

    override fun onDestroy() {
        visualOverlay?.let { windowManager?.removeView(it) }
        navButtonView?.let { windowManager?.removeView(it) }
        closeButtonView?.let { windowManager?.removeView(it) }
        agentButtonView?.let {
            it.stopBreathing()
            windowManager?.removeView(it)
        }
        visualOverlay = null
        navButtonView = null
        closeButtonView = null
        agentButtonView = null
        instance = null
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "教程引导", NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}

class VisualOverlayView(
    context: Context,
    stepsJson: String,
    screenW: Int,
    screenH: Int
) : View(context) {

    var onStepChanged: ((stepIndex: Int, stepTotal: Int) -> Unit)? = null
    var onAllStepsDone: (() -> Unit)? = null

    private val maskPaint = Paint().apply {
        color = Color.parseColor("#B3000000"); style = Paint.Style.FILL; isAntiAlias = true
    }
    private val borderPaint = Paint().apply {
        color = Color.parseColor("#FF42A5F5"); style = Paint.Style.STROKE
        strokeWidth = 5f; isAntiAlias = true
        pathEffect = DashPathEffect(floatArrayOf(14f, 10f), 0f)
    }
    private val bubblePaint = Paint().apply {
        color = Color.WHITE; style = Paint.Style.FILL; isAntiAlias = true
        setShadowLayer(10f, 0f, 3f, Color.parseColor("#50000000"))
    }
    private val textPaint = Paint().apply {
        color = Color.parseColor("#111827"); isAntiAlias = true
        textAlign = Align.LEFT; typeface = Typeface.DEFAULT_BOLD
    }
    private val badgePaint = Paint().apply {
        color = Color.parseColor("#FF42A5F5"); style = Paint.Style.FILL; isAntiAlias = true
    }
    private val badgeTextPaint = Paint().apply {
        color = Color.WHITE; textSize = 22f; isAntiAlias = true
        textAlign = Align.CENTER; typeface = Typeface.DEFAULT_BOLD
    }
    private val donePaint = Paint().apply {
        color = Color.parseColor("#FF42A5F5"); style = Paint.Style.FILL; isAntiAlias = true
    }
    private val doneTextPaint = Paint().apply {
        color = Color.WHITE; textSize = 28f; isAntiAlias = true
        textAlign = Align.CENTER; typeface = Typeface.DEFAULT_BOLD
    }
    private val backHintPaint = Paint().apply {
        color = Color.parseColor("#B0FFFFFF"); textSize = 22f; isAntiAlias = true
        textAlign = Align.CENTER; typeface = Typeface.DEFAULT_BOLD
    }

    private var steps = mutableListOf<Map<String, Any>>()
    private var currentIndex = 0
    private val screenWidth = screenW
    private val screenHeight = screenH
    private var targetRect = RectF()
    private var showComplete = false
    private var completeRect = RectF()
    private var externStepPending = false
    private var stepsJsonOriginal = stepsJson
    private var hasValidTarget = false

    init { parseSteps(stepsJson) }

    fun getStepsJson(): String = stepsJsonOriginal

    private fun parseSteps(json: String) {
        stepsJsonOriginal = json
        try {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val rect = obj.getJSONObject("rect")
                steps.add(mapOf(
                    "instruction" to obj.getString("instruction"),
                    "left" to rect.getDouble("left"),
                    "top" to rect.getDouble("top"),
                    "width" to rect.getDouble("width"),
                    "height" to rect.getDouble("height"),
                    "bubble_dir" to obj.optString("bubble_dir", "bottom")
                ))
            }
        } catch (_: Exception) {}
    }

    fun advanceStep() {
        if (showComplete) {
            onAllStepsDone?.invoke()
            return
        }
        currentIndex++; externStepPending = false; hasValidTarget = false; updateTargetRect()
    }

    private val handler = Handler(Looper.getMainLooper())
    private val resetExternPending = Runnable { externStepPending = false }

    fun updateTargetRect(left: Int, top: Int, right: Int, bottom: Int) {
        hasValidTarget = true
        targetRect = RectF(left.toFloat(), top.toFloat(), right.toFloat(), bottom.toFloat())
        invalidate()
    }

    fun updateInstruction(text: String) {
        if (currentIndex < steps.size) {
            steps[currentIndex] = steps[currentIndex].toMutableMap().apply {
                put("instruction", text)
            }
        }
    }

    fun advanceStepExternally() {
        if (showComplete) {
            onAllStepsDone?.invoke()
            return
        }
        if (externStepPending) return
        externStepPending = true
        currentIndex++; hasValidTarget = false; updateTargetRect()
        handler.removeCallbacks(resetExternPending)
        handler.postDelayed(resetExternPending, 500)
    }

    private fun updateTargetRect() {
        if (currentIndex >= steps.size) {
            showComplete = true
            val cw = (screenWidth * 0.80f); val ch = 160f
            completeRect = RectF(
                (screenWidth - cw) / 2f, (screenHeight - ch) / 2f,
                (screenWidth + cw) / 2f, (screenHeight + ch) / 2f
            )
            onStepChanged?.invoke(steps.size, steps.size); invalidate(); return
        }
        showComplete = false
        val step = steps[currentIndex]
        targetRect = RectF(
            (step["left"] as Double).toFloat() * screenWidth,
            (step["top"] as Double).toFloat() * screenHeight,
            ((step["left"] as Double) + (step["width"] as Double)).toFloat() * screenWidth,
            ((step["top"] as Double) + (step["height"] as Double)).toFloat() * screenHeight
        )
        onStepChanged?.invoke(currentIndex + 1, steps.size); invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (showComplete) {
            canvas.drawColor(Color.parseColor("#B3000000"))
            val rx = 24f
            canvas.drawRoundRect(completeRect, rx, rx, donePaint)
            canvas.drawText("教程完成", completeRect.centerX(), completeRect.centerY() - 16f, doneTextPaint)
            canvas.drawText("点击下方按钮退出", completeRect.centerX(), completeRect.centerY() + 30f, backHintPaint)
            return
        }
        if (steps.isEmpty() || currentIndex >= steps.size) return

        val step = steps[currentIndex]
        val instruction = step["instruction"] as? String ?: ""

        if (!hasValidTarget) {
            canvas.drawColor(Color.parseColor("#80000000"))
            val dp = resources.displayMetrics.density
            val instPaint = Paint().apply {
                color = Color.WHITE; textSize = 32f * dp; isAntiAlias = true
                textAlign = Align.CENTER; typeface = Typeface.DEFAULT_BOLD
                setShadowLayer(8f, 0f, 2f, Color.parseColor("#80000000"))
            }
            val lines = wrapText(instruction, instPaint, screenWidth * 0.85f)
            val lh = instPaint.fontSpacing * 1.2f
            val startY = screenHeight / 2f - (lines.size * lh) / 2f
            for ((i, line) in lines.withIndex()) {
                canvas.drawText(line, screenWidth / 2f, startY + kotlin.math.abs(instPaint.fontMetrics.ascent) + i * lh, instPaint)
            }
            return
        }

        val r = targetRect
        if (r.left > 0) canvas.drawRect(0f, 0f, r.left, screenHeight.toFloat(), maskPaint)
        if (r.right < screenWidth) canvas.drawRect(r.right, 0f, screenWidth.toFloat(), screenHeight.toFloat(), maskPaint)
        if (r.top > 0) canvas.drawRect(r.left, 0f, r.right, r.top, maskPaint)
        if (r.bottom < screenHeight) canvas.drawRect(r.left, r.bottom, r.right, screenHeight.toFloat(), maskPaint)

        val inset = 5f
        canvas.drawRoundRect(RectF(r.left - inset, r.top - inset, r.right + inset, r.bottom + inset), 14f, 14f, borderPaint)
        drawBubble(canvas, r, steps[currentIndex])

        val dp = resources.displayMetrics.density
        val bs = 36f * dp; val bx = r.right - bs / 2f; val by = r.top - bs / 2f
        canvas.drawCircle(bx, by, bs / 2f + 4f, maskPaint)
        canvas.drawCircle(bx, by, bs / 2f, badgePaint)
        canvas.drawText("${currentIndex + 1}", bx, by + 8f, badgeTextPaint)
    }

    private fun drawBubble(canvas: Canvas, r: RectF, step: Map<String, Any>) {
        val instruction = step["instruction"] as? String ?: ""
        val bubbleDir = step["bubble_dir"] as? String ?: "bottom"
        val dp = resources.displayMetrics.density
        textPaint.textSize = 26f * dp
        val lh = textPaint.fontSpacing * 1.15f
        val ph = 24f * dp; val pv = 18f * dp; val gap = 16f * dp
        val mw = (screenWidth * 0.88f)
        val lines = wrapText(instruction, textPaint, mw - ph * 2f)
        val th = lines.size * lh
        val bw = ph * 2f + (lines.maxOfOrNull { textPaint.measureText(it) } ?: mw)
        val bh = pv * 2f + th
        val bx: Float; val by: Float
        when (bubbleDir) {
            "top" -> { bx = (r.centerX() - bw / 2f).coerceIn(16f, screenWidth - bw - 16f); by = (r.top - bh - gap).coerceAtLeast(8f) }
            "bottom" -> { bx = (r.centerX() - bw / 2f).coerceIn(16f, screenWidth - bw - 16f); by = (r.bottom + gap).coerceAtMost(screenHeight - bh - 8f) }
            "left" -> { bx = (r.left - bw - gap).coerceAtLeast(8f); by = (r.centerY() - bh / 2f).coerceIn(8f, screenHeight - bh - 8f) }
            "right" -> { bx = (r.right + gap).coerceAtMost(screenWidth - bw - 8f); by = (r.centerY() - bh / 2f).coerceIn(8f, screenHeight - bh - 8f) }
            else -> { bx = (r.centerX() - bw / 2f).coerceIn(16f, screenWidth - bw - 16f); by = (r.bottom + gap).coerceAtMost(screenHeight - bh - 8f) }
        }
        canvas.drawRoundRect(RectF(bx, by, bx + bw, by + bh), 16f * dp, 16f * dp, bubblePaint)
        for ((i, line) in lines.withIndex()) {
            canvas.drawText(line, bx + ph, by + pv + kotlin.math.abs(textPaint.fontMetrics.ascent) + i * lh, textPaint)
        }
    }

    private fun wrapText(text: String, paint: Paint, maxWidth: Float): List<String> {
        if (text.isEmpty()) return emptyList()
        val result = mutableListOf<String>()
        var line = StringBuilder()
        for (ch in text) {
            val test = line.toString() + ch
            if (paint.measureText(test) > maxWidth && line.isNotEmpty()) {
                result.add(line.toString()); line = StringBuilder(ch.toString())
            } else line.append(ch)
        }
        if (line.isNotEmpty()) result.add(line.toString())
        return result
    }
}

class CloseButtonView(context: Context) : View(context) {
    var onClick: (() -> Unit)? = null

    private val bgPaint = Paint().apply {
        color = Color.parseColor("#CCFFFFFF"); style = Paint.Style.FILL; isAntiAlias = true
        setShadowLayer(8f, 0f, 2f, Color.parseColor("#40000000"))
    }
    private val xPaint = Paint().apply {
        color = Color.parseColor("#FF666666"); style = Paint.Style.STROKE
        strokeWidth = 3.5f; isAntiAlias = true; strokeCap = Paint.Cap.ROUND
    }

    init { isClickable = true }

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f; val cy = height / 2f
        val radius = width * 0.42f
        canvas.drawCircle(cx, cy, radius, bgPaint)
        val inset = radius * 0.35f
        canvas.drawLine(cx - inset, cy - inset, cx + inset, cy + inset, xPaint)
        canvas.drawLine(cx + inset, cy - inset, cx - inset, cy + inset, xPaint)
    }

    override fun performClick(): Boolean {
        super.performClick()
        onClick?.invoke()
        return true
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_DOWN) { performClick(); return true }
        return true
    }
}

class AgentButtonView(context: Context) : View(context) {
    var onClick: (() -> Unit)? = null

    private val bgPaint = Paint().apply {
        color = Color.parseColor("#FF42A5F5"); style = Paint.Style.FILL; isAntiAlias = true
        setShadowLayer(16f, 0f, 4f, Color.parseColor("#8042A5F5"))
    }
    private val textPaint = Paint().apply {
        color = Color.WHITE; textSize = 28f * context.resources.displayMetrics.density
        isAntiAlias = true; textAlign = Align.CENTER; typeface = Typeface.DEFAULT_BOLD
    }
    private var breathAnimator: ValueAnimator? = null
    private var breathAlpha = 1f

    init { isClickable = true }

    fun startBreathing() {
        breathAnimator = ValueAnimator.ofFloat(1f, 0.55f).apply {
            duration = 1200; repeatMode = ValueAnimator.REVERSE; repeatCount = ValueAnimator.INFINITE
            interpolator = DecelerateInterpolator()
            addUpdateListener { breathAlpha = it.animatedValue as Float; invalidate() }
            start()
        }
    }

    fun stopBreathing() {
        breathAnimator?.cancel(); breathAnimator = null
        breathAlpha = 1f
    }

    override fun onDraw(canvas: Canvas) {
        val cx = width / 2f; val cy = height / 2f
        val radius = width * 0.46f
        val ringPaint = Paint().apply {
            style = Paint.Style.STROKE; strokeWidth = 3f; isAntiAlias = true
            color = Color.argb((255 * breathAlpha).toInt(), 0x42, 0xA5, 0xF5)
        }
        canvas.drawCircle(cx, cy, radius, bgPaint)
        canvas.drawCircle(cx, cy, radius + 6f, ringPaint)
        val dp = resources.displayMetrics.density
        canvas.drawText("a", cx, cy + 10f * dp, textPaint)
    }

    override fun performClick(): Boolean {
        super.performClick()
        onClick?.invoke()
        return true
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_DOWN) { performClick(); return true }
        return true
    }
}

class NavButtonView(context: Context, private val onClick: () -> Unit) : View(context) {
    private val paint = Paint().apply {
        color = Color.parseColor("#FFF97316"); style = Paint.Style.FILL; isAntiAlias = true
        setShadowLayer(16f, 0f, 6f, Color.parseColor("#B0F97316"))
    }
    private val strokePaint = Paint().apply {
        color = Color.WHITE; style = Paint.Style.STROKE; strokeWidth = 3f; isAntiAlias = true
    }
    private val textPaint = Paint().apply {
        color = Color.WHITE; textSize = 34f * context.resources.displayMetrics.density
        isAntiAlias = true; textAlign = Align.CENTER; typeface = Typeface.DEFAULT_BOLD
        setShadowLayer(4f, 0f, 2f, Color.parseColor("#80000000"))
    }
    private var label = "1/1 下一步 ▶"
    init { isClickable = true }
    fun updateState(stepIndex: Int, stepTotal: Int) {
        label = if (stepIndex >= stepTotal) {
            "完成 ✓"
        } else {
            "$stepIndex/$stepTotal 下一步 ▶"
        }
        requestLayout(); invalidate()
    }
    override fun onMeasure(wms: Int, hms: Int) {
        val dp = resources.displayMetrics.density
        val tw = textPaint.measureText(label) + (72 * dp)
        setMeasuredDimension(tw.toInt(), (56 * dp).toInt())
    }
    override fun onDraw(canvas: Canvas) {
        val dp = resources.displayMetrics.density
        val cx = width / 2f; val cy = height / 2f; val rx = 28f * dp
        val bw = textPaint.measureText(label) + (72 * dp)
        val bw2 = bw / 2f; val h = (56 * dp).toFloat()
        canvas.drawRoundRect(cx - bw2, cy - h / 2f, cx + bw2, cy + h / 2f, rx, rx, paint)
        canvas.drawRoundRect(cx - bw2, cy - h / 2f, cx + bw2, cy + h / 2f, rx, rx, strokePaint)
        canvas.drawText(label, cx, cy + 12f * dp, textPaint)
    }
    override fun performClick(): Boolean { super.performClick(); onClick(); return true }
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_DOWN) { performClick(); return true }; return true
    }
}
