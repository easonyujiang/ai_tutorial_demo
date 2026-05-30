package com.example.frontend

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.frontend/overlay"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startOverlay" -> {
                        val stepsJson = call.argument<String>("steps") ?: "[]"
                        val targetPackage = call.argument<String>("targetPackage")
                        val targetActivity = call.argument<String>("targetActivity")

                        val intent = TutorialTargetResolver.resolveIntent(
                            this, targetPackage, targetActivity
                        )
                        startActivity(intent)

                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            val serviceIntent = Intent(this, TutorialOverlayService::class.java)
                            serviceIntent.putExtra("steps", stepsJson)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(serviceIntent)
                            } else {
                                startService(serviceIntent)
                            }
                            result.success(true)
                        }, 800)
                    }

                    "stopOverlay" -> {
                        TutorialOverlayService.stop()
                        result.success(true)
                    }

                    "canDrawOverlays" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                Settings.canDrawOverlays(this)
                            } else {
                                true
                            }
                        )
                    }

                    "requestOverlayPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            !Settings.canDrawOverlays(this)
                        ) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(true)
                    }

                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(true)
                    }

                    "takeScreenshot" -> {
                        val base64 = TutorialOverlayService.takeScreenshot()
                        if (base64 != null) {
                            result.success(base64)
                        } else {
                            result.error("UNSUPPORTED", "Screenshot requires Android 14+", null)
                        }
                    }

                    "findNodeByText" -> {
                        val targetText = call.argument<String>("targetText") ?: ""
                        val rect = TutorialAccessibilityService.findNodeByText(targetText)
                        if (rect != null) {
                            result.success(mapOf(
                                "left" to rect.left,
                                "top" to rect.top,
                                "right" to rect.right,
                                "bottom" to rect.bottom,
                            ))
                        } else {
                            result.success(null)
                        }
                    }

                    "findNodeByDescription" -> {
                        val targetDesc = call.argument<String>("targetDesc") ?: ""
                        val rect = TutorialAccessibilityService.findNodeByDescription(targetDesc)
                        if (rect != null) {
                            result.success(mapOf(
                                "left" to rect.left,
                                "top" to rect.top,
                                "right" to rect.right,
                                "bottom" to rect.bottom,
                            ))
                        } else {
                            result.success(null)
                        }
                    }

                    "updateTargetRect" -> {
                        val left = call.argument<Int>("left") ?: 0
                        val top = call.argument<Int>("top") ?: 0
                        val right = call.argument<Int>("right") ?: 0
                        val bottom = call.argument<Int>("bottom") ?: 0
                        TutorialOverlayService.updateTargetRect(left, top, right, bottom)
                        result.success(true)
                    }

                    "updateInstruction" -> {
                        val text = call.argument<String>("text") ?: ""
                        TutorialOverlayService.updateInstruction(text)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = "$packageName/.TutorialAccessibilityService"
        val serviceNameFull = "$packageName/$packageName.TutorialAccessibilityService"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val parts = enabledServices.split(":")
        return parts.any { it == serviceName || it == serviceNameFull }
    }
}
