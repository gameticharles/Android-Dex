package com.shrey.adbdevicemanager.server

import android.app.WallpaperManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import java.io.ByteArrayOutputStream

/**
 * Performance Fix #4: Binary Image Stream Endpoints (Kotlin)
 * Eliminates 33% Base64 encoding overhead + CPU decode step.
 */
class ImageRoute(private val context: Context) {

    fun getDeviceWallpaperBytes(quality: Int = 80): ByteArray {
        val wallpaperDrawable = WallpaperManager.getInstance(context).drawable
        if (wallpaperDrawable is BitmapDrawable) {
            val bitmap = wallpaperDrawable.bitmap
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.WEBP_LOSSY, quality, stream)
            return stream.toByteArray()
        }
        return ByteArray(0)
    }
}
