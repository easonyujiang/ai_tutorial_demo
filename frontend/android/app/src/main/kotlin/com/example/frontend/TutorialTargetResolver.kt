package com.example.frontend

import android.content.Context
import android.content.Intent
import android.provider.Settings

object TutorialTargetResolver {

    fun resolveIntent(
        context: Context,
        targetPackage: String?,
        targetActivity: String?
    ): Intent {
        if (!targetPackage.isNullOrBlank()) {
            return buildAppIntent(context, targetPackage, targetActivity)
        }

        return buildSettingsIntent()
    }

    private fun buildAppIntent(
        context: Context,
        packageName: String,
        activityClassName: String?
    ): Intent {
        return if (!activityClassName.isNullOrBlank()) {
            Intent().apply {
                setClassName(packageName, activityClassName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        } else {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                launchIntent
            } else {
                Intent().apply {
                    setClassName(packageName, "${packageName}.MainActivity")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }
        }
    }

    private fun buildSettingsIntent(): Intent {
        return Intent(Settings.ACTION_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }

    fun buildHomeIntent(): Intent {
        return Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
    }
}
