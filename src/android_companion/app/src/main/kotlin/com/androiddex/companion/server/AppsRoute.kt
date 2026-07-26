package com.androiddex.companion.server

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream

/**
 * Real-Time Installed Applications Query & Authentic Icon Extractor Route
 */
class AppsRoute(private val context: Context) {

    fun getInstalledAppsJson(): String {
        val array = JSONArray()
        try {
            val pm = context.packageManager
            val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val launcherApps = pm.queryIntentActivities(mainIntent, 0)
            val addedPackages = HashSet<String>()

            // 1. Process launcher activities with authentic display labels
            for (resolveInfo in launcherApps) {
                val pkg = resolveInfo.activityInfo.packageName
                val label = resolveInfo.loadLabel(pm).toString()

                if (pkg.isNotEmpty() && label.isNotEmpty() && addedPackages.add(pkg)) {
                    val item = JSONObject().apply {
                        put("package_name", pkg)
                        put("label", label)
                    }
                    array.put(item)
                }
            }

            // 2. Process remaining user & 3rd party apps
            val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
            for (appInfo in packages) {
                val pkg = appInfo.packageName
                if (!addedPackages.contains(pkg) &&
                    ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0 ||
                     pm.getLaunchIntentForPackage(pkg) != null)) {

                    val label = pm.getApplicationLabel(appInfo).toString()
                    if (addedPackages.add(pkg)) {
                        val item = JSONObject().apply {
                            put("package_name", pkg)
                            put("label", label)
                        }
                        array.put(item)
                    }
                }
            }
        } catch (_: Exception) {}

        return JSONObject().put("status", "success").put("apps", array).toString()
    }

    fun getAppIconPngBytes(packageName: String): ByteArray? {
        return try {
            val pm = context.packageManager
            val drawable = pm.getApplicationIcon(packageName)
            val bitmap = drawableToBitmap(drawable)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (_: Exception) {
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        val width = drawable.intrinsicWidth.coerceAtLeast(96)
        val height = drawable.intrinsicHeight.coerceAtLeast(96)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}
