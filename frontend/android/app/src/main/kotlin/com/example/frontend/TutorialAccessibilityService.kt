package com.example.frontend

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent

class TutorialAccessibilityService : AccessibilityService() {

    private var lastClassName = ""
    private var serviceStartTime = 0L
    private var lastAdvanceTime = 0L

    override fun onServiceConnected() {
        serviceStartTime = System.currentTimeMillis()
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_VIEW_CLICKED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 300
            flags = AccessibilityServiceInfo.DEFAULT
        }
        serviceInfo = info
        lastClassName = ""
        lastAdvanceTime = 0L
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (System.currentTimeMillis() - serviceStartTime < 1500) return

        val pkgName = event.packageName?.toString() ?: ""
        if (pkgName == "com.example.frontend") return

        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                val className = event.className?.toString() ?: return
                if (className.isEmpty()) return

                if (lastClassName.isNotEmpty() && lastClassName != className) {
                    doAdvance()
                }
                lastClassName = className
            }

            AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                doAdvance()
            }
        }
    }

    private fun doAdvance() {
        val now = System.currentTimeMillis()
        if (now - lastAdvanceTime < 800) return
        lastAdvanceTime = now
        TutorialOverlayService.advanceStep()
    }

    override fun onInterrupt() {}
}
