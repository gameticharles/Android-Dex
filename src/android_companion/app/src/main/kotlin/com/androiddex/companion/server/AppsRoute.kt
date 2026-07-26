package com.androiddex.companion.server

import android.content.Context
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
 * Installed Applications Query & Icon Extractor Route
 */
class AppsRoute(private val context: Context) {

    fun getInstalledAppsJson(): String {
        val array = JSONArray()
        try {
            val pm = context.packageManager
            val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)

            for (appInfo in packages) {
                // Filter user / 3rd party apps or launchers
                if ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0 ||
                    pm.getLaunchIntentForPackage(appInfo.packageName) != null) {

                    val label = pm.getApplicationLabel(appInfo).toString()
                    val pkg = appInfo.packageName

                    val item = JSONObject().apply {
                        put("package_name", pkg)
                        put("label", label)
                    }
                    array.put(item)
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
        val bitmap = Bitmap.createBitmap(
            drawable.intrinsicWidth.coerceAtLeast(1),
            drawable.intrinsicHeight.coerceAtLeast(1),
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}
