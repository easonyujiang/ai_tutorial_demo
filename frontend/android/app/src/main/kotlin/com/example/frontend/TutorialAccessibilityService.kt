package com.example.frontend

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.graphics.Bitmap
import android.graphics.Rect
import android.os.Build
import android.util.Base64
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.io.ByteArrayOutputStream

class TutorialAccessibilityService : AccessibilityService() {

    private var serviceStartTime = 0L
    private var lastAdvanceTime = 0L

    companion object {
        private var instance: TutorialAccessibilityService? = null

        fun findNodeByText(targetText: String): Rect? {
            android.util.Log.d("A11y", "findNodeByText called: '$targetText'")
            val result = instance?.findTextOnScreen(targetText)
            android.util.Log.d("A11y", "findNodeByText result: $result")
            return result
        }

        fun findNodeByDescription(targetDesc: String): Rect? {
            android.util.Log.d("A11y", "findNodeByDesc called: '$targetDesc'")
            val result = instance?.findDescriptionOnScreen(targetDesc)
            android.util.Log.d("A11y", "findNodeByDesc result: $result")
            return result
        }

        fun takeScreenshotBase64(): String? {
            return instance?.captureScreenBase64()
        }
    }

    override fun onServiceConnected() {
        instance = this
        serviceStartTime = System.currentTimeMillis()
        android.util.Log.d("A11y", "onServiceConnected, configuring...")
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_VIEW_CLICKED or
                    AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 300
            flags = AccessibilityServiceInfo.DEFAULT or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        }
        serviceInfo = info
        lastAdvanceTime = 0L
        android.util.Log.d("A11y", "onServiceConnected done")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (System.currentTimeMillis() - serviceStartTime < 1500) return

        val pkgName = event.packageName?.toString() ?: ""
        if (pkgName == "com.example.frontend") return

        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                doAdvance()
            }
        }
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    private fun doAdvance() {
        val now = System.currentTimeMillis()
        if (now - lastAdvanceTime < 800) return
        lastAdvanceTime = now
        TutorialOverlayService.advanceStep()
    }

    private fun findTextOnScreen(targetText: String): Rect? {
        if (targetText.isBlank()) return null
        val roots = mutableListOf<AccessibilityNodeInfo>()
        rootInActiveWindow?.let { roots.add(it) }
        if (roots.isEmpty() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            windows?.forEach { roots.add(it.root) }
        }
        for (root in roots) {
            val nodes = root.findAccessibilityNodeInfosByText(targetText)
            for (node in nodes) {
                if (node.text?.toString()?.contains(targetText, ignoreCase = true) == true) {
                    val rect = Rect()
                    node.getBoundsInScreen(rect)
                    if (rect.width() > 0 && rect.height() > 0) {
                        node.recycle()
                        return rect
                    }
                }
                node.recycle()
            }
            root.recycle()
        }
        return null
    }

    private fun findDescriptionOnScreen(targetDesc: String): Rect? {
        if (targetDesc.isBlank()) return null
        val roots = mutableListOf<AccessibilityNodeInfo>()
        rootInActiveWindow?.let { roots.add(it) }
        if (roots.isEmpty() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            windows?.forEach { roots.add(it.root) }
        }
        for (root in roots) {
            val result = findNodeByDesc(root, targetDesc)
            root.recycle()
            if (result != null) return result
        }
        return null
    }

    private fun findNodeByDesc(node: AccessibilityNodeInfo, desc: String): Rect? {
        val contentDesc = node.contentDescription?.toString() ?: ""
        if (contentDesc.contains(desc, ignoreCase = true)) {
            val rect = Rect()
            node.getBoundsInScreen(rect)
            if (rect.width() > 0 && rect.height() > 0) {
                return rect
            }
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findNodeByDesc(child, desc)
            if (result != null) {
                child.recycle()
                return result
            }
            child.recycle()
        }
        return null
    }

    private fun captureScreenBase64(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return null
        }
        return try {
            val latch = java.util.concurrent.CountDownLatch(1)
            var bitmap: Bitmap? = null
            val executor = java.util.concurrent.Executors.newSingleThreadExecutor()
            takeScreenshot(display!!.displayId, executor, object : TakeScreenshotCallback {
                override fun onSuccess(result: ScreenshotResult) {
                    try {
                        val hwb = result.hardwareBuffer
                        bitmap = Bitmap.wrapHardwareBuffer(hwb, result.colorSpace)
                        hwb.close()
                    } catch (_: Exception) {
                    }
                    latch.countDown()
                }
                override fun onFailure(errorCode: Int) {
                    latch.countDown()
                }
            })
            latch.await(3, java.util.concurrent.TimeUnit.SECONDS)
            executor.shutdownNow()
            if (bitmap == null) return null
            val stream = ByteArrayOutputStream()
            bitmap!!.compress(Bitmap.CompressFormat.JPEG, 80, stream)
            bitmap!!.recycle()
            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        } catch (_: Exception) {
            null
        }
    }

    override fun onInterrupt() {}
}
