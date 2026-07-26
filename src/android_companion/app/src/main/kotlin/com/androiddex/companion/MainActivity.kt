package com.androiddex.companion

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Typeface
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.OpenableColumns
import android.provider.Settings
import android.text.format.Formatter
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.androiddex.companion.server.CompanionServerService
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MainActivity : AppCompatActivity() {

    private var currentScreen = "home" // "home", "permissions", "presentation", "trackpad", "media"
    private lateinit var mainContainer: LinearLayout
    private lateinit var tvStatus: TextView
    private lateinit var tvIpAddress: TextView
    private lateinit var prefs: SharedPreferences

    private var currentThemeMode = "system" // "system", "dark", "light"

    // File picker launcher
    private val pickFileLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri?.let { uploadFileToDesktop(it) }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        prefs = getSharedPreferences("dex_companion_prefs", Context.MODE_PRIVATE)
        currentThemeMode = prefs.getString("theme_mode", "system") ?: "system"

        mainContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        setContentView(mainContainer)
        startCompanionService()
        applyThemeAndRefreshUI()
    }

    private fun startCompanionService() {
        val intent = Intent(this, CompanionServerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun isDarkModeActive(): Boolean {
        return when (currentThemeMode) {
            "dark" -> true
            "light" -> false
            else -> {
                val currentNightMode = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
                currentNightMode == Configuration.UI_MODE_NIGHT_YES
            }
        }
    }

    private fun applyThemeAndRefreshUI() {
        val isDark = isDarkModeActive()
        val bgColor = if (isDark) 0xFF0F172A.toInt() else 0xFFFBF9F7.toInt()
        mainContainer.setBackgroundColor(bgColor)

        when (currentScreen) {
            "permissions" -> showPermissionsScreen()
            "presentation" -> showPresentationRemoteScreen()
            "trackpad" -> showTrackpadScreen()
            "media" -> showMediaControlScreen()
            else -> showHomeScreen()
        }
    }

    private fun showHomeScreen() {
        currentScreen = "home"
        mainContainer.removeAllViews()

        val isDark = isDarkModeActive()
        val textPrimary = if (isDark) 0xFFF8FAFC.toInt() else 0xFF1E1B18.toInt()
        val textSecondary = if (isDark) 0xFF94A3B8.toInt() else 0xFF78716C.toInt()
        val cardBg = if (isDark) 0xFF1E293B.toInt() else 0xFFFFFFFF.toInt()
        val iconBgColor = if (isDark) 0xFF334155.toInt() else 0xFFF3F0EC.toInt()
        val statusBgColor = if (isDark) 0xFF1E293B.toInt() else 0xFFF3F0EC.toInt()

        val scrollView = ScrollView(this).apply { isFillViewport = true }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(56, 120, 56, 56)
        }

        // Header Title
        val title = TextView(this).apply {
            text = "AndroidDex Companion"
            textSize = 26f
            setTextColor(textPrimary)
            setTypeface(null, Typeface.BOLD)
        }

        val subtitle = TextView(this).apply {
            text = "Wireless Control Suite & Desktop Sync"
            textSize = 14f
            setTextColor(textSecondary)
            setPadding(0, 4, 0, 48)
        }

        // Action Cards Container
        val cardsLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        // 1. Send Files Card
        val sendFileCard = createActionCard(
            title = "Send Files to Computer",
            subtitle = "Upload photos & files directly to PC Downloads",
            iconRes = android.R.drawable.ic_menu_upload,
            cardBg = cardBg,
            iconBgColor = iconBgColor,
            textPrimary = textPrimary,
            textSecondary = textSecondary
        ) {
            pickFileLauncher.launch("*/*")
        }

        // 2. Presentation Remote Card
        val presentationCard = createActionCard(
            title = "Presentation Remote",
            subtitle = "Control slides (Next/Prev, F5, Blank screen)",
            iconRes = android.R.drawable.ic_menu_slideshow,
            cardBg = cardBg,
            iconBgColor = iconBgColor,
            textPrimary = textPrimary,
            textSecondary = textSecondary
        ) {
            showPresentationRemoteScreen()
        }

        // 3. Trackpad & Input Remote Card
        val trackpadCard = createActionCard(
            title = "Remote Trackpad & Keyboard",
            subtitle = "Touchpad cursor movement, click, scroll & typing",
            iconRes = android.R.drawable.ic_menu_compass,
            cardBg = cardBg,
            iconBgColor = iconBgColor,
            textPrimary = textPrimary,
            textSecondary = textSecondary
        ) {
            showTrackpadScreen()
        }

        // 4. Computer Media & Power Control Card
        val mediaCard = createActionCard(
            title = "Computer Control Center",
            subtitle = "Volume controls, media playback & PC screen lock",
            iconRes = android.R.drawable.ic_media_play,
            cardBg = cardBg,
            iconBgColor = iconBgColor,
            textPrimary = textPrimary,
            textSecondary = textSecondary
        ) {
            showMediaControlScreen()
        }

        // 5. Theme Card
        val themeCard = createActionCard(
            title = "Appearance Theme",
            subtitle = "Mode: ${currentThemeMode.replaceFirstChar { it.uppercase() }}",
            iconRes = android.R.drawable.ic_menu_preferences,
            cardBg = cardBg,
            iconBgColor = iconBgColor,
            textPrimary = textPrimary,
            textSecondary = textSecondary
        ) {
            showThemeSelectorDialog()
        }

        // 6. Permissions Card
        val permissionsCard = createActionCard(
            title = "Manage Permissions",
            subtitle = "Configure background service permissions",
            iconRes = android.R.drawable.ic_lock_lock,
            cardBg = cardBg,
            iconBgColor = iconBgColor,
            textPrimary = textPrimary,
            textSecondary = textSecondary
        ) {
            showPermissionsScreen()
        }

        cardsLayout.addView(sendFileCard)
        cardsLayout.addView(createSpacer(16))
        cardsLayout.addView(presentationCard)
        cardsLayout.addView(createSpacer(16))
        cardsLayout.addView(trackpadCard)
        cardsLayout.addView(createSpacer(16))
        cardsLayout.addView(mediaCard)
        cardsLayout.addView(createSpacer(16))
        cardsLayout.addView(themeCard)
        cardsLayout.addView(createSpacer(16))
        cardsLayout.addView(permissionsCard)

        // Network Status Info
        val statusCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(40, 32, 40, 32)
            background = createRoundedDrawable(statusBgColor, 32f)
        }

        tvStatus = TextView(this).apply {
            text = "Status: Wireless Service Active (Port 8080)"
            textSize = 12f
            setTextColor(0xFF10B981.toInt())
            setTypeface(null, Typeface.BOLD)
        }

        tvIpAddress = TextView(this).apply {
            text = getDeviceIpAddress()
            textSize = 12f
            setTextColor(textSecondary)
            setPadding(0, 4, 0, 0)
        }

        statusCard.addView(tvStatus)
        statusCard.addView(tvIpAddress)

        // Footer
        val footer = TextView(this).apply {
            text = "Made with ❤️ by AndroidDex • v1.0.0"
            textSize = 12f
            setTextColor(textSecondary)
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(0, 60, 0, 40)
        }

        content.addView(title)
        content.addView(subtitle)
        content.addView(cardsLayout)
        content.addView(createSpacer(32))
        content.addView(statusCard)
        content.addView(footer)

        scrollView.addView(content)
        mainContainer.addView(scrollView)
    }

    // --- FEATURE 1: Send File to Computer ---
    private fun uploadFileToDesktop(uri: Uri) {
        val fileName = getFileNameFromUri(uri) ?: "upload_${System.currentTimeMillis()}"
        Toast.makeText(this, "Sending $fileName to PC Downloads...", Toast.LENGTH_SHORT).show()

        thread {
            try {
                val inputStream: InputStream? = contentResolver.openInputStream(uri)
                val bytes = inputStream?.readBytes() ?: return@thread

                val savedPcIp = prefs.getString("pc_host_ip", null)
                val candidateIps = mutableListOf<String>()
                if (!savedPcIp.isNullOrEmpty()) candidateIps.add(savedPcIp)

                try {
                    val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
                    @Suppress("DEPRECATION")
                    val gatewayIp = Formatter.formatIpAddress(wifiManager.dhcpInfo.gateway)
                    if (gatewayIp.isNotEmpty() && gatewayIp != "0.0.0.0" && !candidateIps.contains(gatewayIp)) {
                        candidateIps.add(gatewayIp)
                    }
                } catch (e: Exception) {}
                if (!candidateIps.contains("127.0.0.1")) candidateIps.add("127.0.0.1")

                val ports = intArrayOf(8080, 4567, 38947)
                var success = false

                for (host in candidateIps) {
                    for (port in ports) {
                        try {
                            val url = URL("http://$host:$port/remote/upload_file")
                            val conn = url.openConnection() as HttpURLConnection
                            conn.requestMethod = "POST"
                            conn.doOutput = true
                            conn.connectTimeout = 3000
                            conn.readTimeout = 5000
                            conn.setRequestProperty("x-file-name", fileName)
                            conn.setRequestProperty("Content-Type", "application/octet-stream")

                            conn.outputStream.use { os ->
                                os.write(bytes)
                            }

                            if (conn.responseCode == 200) {
                                success = true
                                break
                            }
                        } catch (e: Exception) {}
                    }
                    if (success) break
                }

                runOnUiThread {
                    if (success) {
                        Toast.makeText(this, "$fileName sent to PC Downloads! ✓", Toast.LENGTH_LONG).show()
                    } else {
                        Toast.makeText(this, "Failed to send file. Ensure Dex Desktop is open.", Toast.LENGTH_LONG).show()
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    Toast.makeText(this, "Error sending file: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun getFileNameFromUri(uri: Uri): String? {
        var result: String? = null
        if (uri.scheme == "content") {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx != -1) result = cursor.getString(idx)
                }
            }
        }
        if (result == null) {
            result = uri.path
            val cut = result?.lastIndexOf('/') ?: -1
            if (cut != -1) result = result?.substring(cut + 1)
        }
        return result
    }

    // --- FEATURE 2: Presentation Remote Screen ---
    private fun showPresentationRemoteScreen() {
        currentScreen = "presentation"
        mainContainer.removeAllViews()

        val isDark = isDarkModeActive()
        val textPrimary = if (isDark) 0xFFF8FAFC.toInt() else 0xFF1E1B18.toInt()
        val cardBg = if (isDark) 0xFF1E293B.toInt() else 0xFFFFFFFF.toInt()

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 64, 48, 48)
        }

        // Header Navigation
        val navHeader = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, 48)
        }

        val backBtn = TextView(this).apply {
            text = "← Back"
            textSize = 16f
            setTextColor(0xFF00BFA5.toInt())
            setTypeface(null, Typeface.BOLD)
            setOnClickListener { showHomeScreen() }
        }

        val headerTitle = TextView(this).apply {
            text = "Presentation Remote"
            textSize = 20f
            setTextColor(textPrimary)
            setTypeface(null, Typeface.BOLD)
            setPadding(32, 0, 0, 0)
        }

        navHeader.addView(backBtn)
        navHeader.addView(headerTitle)

        // Giant Next Slide Button
        val nextBtn = Button(this).apply {
            text = "NEXT SLIDE ➔"
            textSize = 20f
            setTextColor(0xFFFFFFFF.toInt())
            setTypeface(null, Typeface.BOLD)
            background = createRoundedDrawable(0xFF10B981.toInt(), 32f)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 2f
            ).apply { setMargins(0, 0, 0, 24) }
            setOnClickListener { sendRemoteCommand("/remote/presentation", JSONObject().put("action", "next")) }
        }

        // Previous Slide Button
        val prevBtn = Button(this).apply {
            text = "⬅ PREVIOUS SLIDE"
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            setTypeface(null, Typeface.BOLD)
            background = createRoundedDrawable(cardBg, 32f)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f
            ).apply { setMargins(0, 0, 0, 24) }
            setOnClickListener { sendRemoteCommand("/remote/presentation", JSONObject().put("action", "prev")) }
        }

        // Controls Row: Start F5 & Blank Screen B
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        }

        val startBtn = Button(this).apply {
            text = "▶ Start (F5)"
            textSize = 14f
            setTextColor(0xFFFFFFFF.toInt())
            background = createRoundedDrawable(0xFF3B82F6.toInt(), 24f)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(0, 0, 12, 0) }
            setOnClickListener { sendRemoteCommand("/remote/presentation", JSONObject().put("action", "start")) }
        }

        val blankBtn = Button(this).apply {
            text = "⬛ Blank (B)"
            textSize = 14f
            setTextColor(0xFFFFFFFF.toInt())
            background = createRoundedDrawable(0xFF64748B.toInt(), 24f)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(12, 0, 0, 0) }
            setOnClickListener { sendRemoteCommand("/remote/presentation", JSONObject().put("action", "blank")) }
        }

        row.addView(startBtn)
        row.addView(blankBtn)

        content.addView(navHeader)
        content.addView(nextBtn)
        content.addView(prevBtn)
        content.addView(row)

        mainContainer.addView(content)
    }

    // --- FEATURE 3: Trackpad & Remote Input Screen ---
    private fun showTrackpadScreen() {
        currentScreen = "trackpad"
        mainContainer.removeAllViews()

        val isDark = isDarkModeActive()
        val textPrimary = if (isDark) 0xFFF8FAFC.toInt() else 0xFF1E1B18.toInt()
        val cardBg = if (isDark) 0xFF1E293B.toInt() else 0xFFE2E8F0.toInt()

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 64, 48, 48)
        }

        // Nav Header
        val navHeader = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, 32)
        }

        val backBtn = TextView(this).apply {
            text = "← Back"
            textSize = 16f
            setTextColor(0xFF00BFA5.toInt())
            setTypeface(null, Typeface.BOLD)
            setOnClickListener { showHomeScreen() }
        }

        val headerTitle = TextView(this).apply {
            text = "Remote Trackpad"
            textSize = 20f
            setTextColor(textPrimary)
            setTypeface(null, Typeface.BOLD)
            setPadding(32, 0, 0, 0)
        }

        navHeader.addView(backBtn)
        navHeader.addView(headerTitle)

        // Soft Keyboard Input Bar
        val keyLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 0, 0, 24)
        }

        val etInput = EditText(this).apply {
            hint = "Type text to send to PC..."
            textSize = 14f
            setTextColor(textPrimary)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }

        val sendBtn = Button(this).apply {
            text = "Send"
            textSize = 13f
            setOnClickListener {
                val txt = etInput.text.toString()
                if (txt.isNotEmpty()) {
                    sendRemoteCommand("/remote/input", JSONObject().put("type", "type").put("text", txt))
                    etInput.text.clear()
                }
            }
        }

        keyLayout.addView(etInput)
        keyLayout.addView(sendBtn)

        // Touchpad Area
        var lastX = 0f
        var lastY = 0f

        val touchpad = View(this).apply {
            background = createRoundedDrawable(cardBg, 32f)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f)

            setOnTouchListener { _, event ->
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        lastX = event.x
                        lastY = event.y
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.x - lastX) * 1.5f
                        val dy = (event.y - lastY) * 1.5f
                        lastX = event.x
                        lastY = event.y

                        if (Math.abs(dx) > 1 || Math.abs(dy) > 1) {
                            sendRemoteCommand("/remote/input", JSONObject().put("type", "move").put("dx", dx.toInt()).put("dy", dy.toInt()))
                        }
                    }
                    MotionEvent.ACTION_UP -> {
                        if (event.eventTime - event.downTime < 200) {
                            // Tap -> Left Click
                            sendRemoteCommand("/remote/input", JSONObject().put("type", "click"))
                        }
                    }
                }
                true
            }
        }

        // Left & Right Click Bar
        val clickRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, 24, 0, 0)
        }

        val leftClickBtn = Button(this).apply {
            text = "Left Click"
            background = createRoundedDrawable(0xFF10B981.toInt(), 20f)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(0, 0, 8, 0) }
            setOnClickListener { sendRemoteCommand("/remote/input", JSONObject().put("type", "click")) }
        }

        val rightClickBtn = Button(this).apply {
            text = "Right Click"
            background = createRoundedDrawable(0xFF64748B.toInt(), 20f)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(8, 0, 0, 0) }
            setOnClickListener { sendRemoteCommand("/remote/input", JSONObject().put("type", "rclick")) }
        }

        clickRow.addView(leftClickBtn)
        clickRow.addView(rightClickBtn)

        content.addView(navHeader)
        content.addView(keyLayout)
        content.addView(touchpad)
        content.addView(clickRow)

        mainContainer.addView(content)
    }

    // --- FEATURE 4: Computer Media & Power Control Screen ---
    private fun showMediaControlScreen() {
        currentScreen = "media"
        mainContainer.removeAllViews()

        val isDark = isDarkModeActive()
        val textPrimary = if (isDark) 0xFFF8FAFC.toInt() else 0xFF1E1B18.toInt()
        val cardBg = if (isDark) 0xFF1E293B.toInt() else 0xFFFFFFFF.toInt()

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 64, 48, 48)
        }

        // Nav Header
        val navHeader = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, 48)
        }

        val backBtn = TextView(this).apply {
            text = "← Back"
            textSize = 16f
            setTextColor(0xFF00BFA5.toInt())
            setTypeface(null, Typeface.BOLD)
            setOnClickListener { showHomeScreen() }
        }

        val headerTitle = TextView(this).apply {
            text = "Computer Control Center"
            textSize = 20f
            setTextColor(textPrimary)
            setTypeface(null, Typeface.BOLD)
            setPadding(32, 0, 0, 0)
        }

        navHeader.addView(backBtn)
        navHeader.addView(headerTitle)

        // Volume Controls Group
        val volTitle = TextView(this).apply {
            text = "PC VOLUME CONTROLS"
            textSize = 12f
            setTextColor(0xFF00BFA5.toInt())
            setTypeface(null, Typeface.BOLD)
            setPadding(0, 0, 0, 16)
        }

        val volRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }

        val volUpBtn = Button(this).apply {
            text = "🔊 Volume Up"
            background = createRoundedDrawable(0xFF10B981.toInt(), 20f)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(0, 0, 8, 0) }
            setOnClickListener { sendRemoteCommand("/remote/media", JSONObject().put("action", "vol_up")) }
        }

        val volDownBtn = Button(this).apply {
            text = "🔉 Volume Down"
            background = createRoundedDrawable(0xFF3B82F6.toInt(), 20f)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(4, 0, 4, 0) }
            setOnClickListener { sendRemoteCommand("/remote/media", JSONObject().put("action", "vol_down")) }
        }

        val volMuteBtn = Button(this).apply {
            text = "🔇 Mute"
            background = createRoundedDrawable(0xFF64748B.toInt(), 20f)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(8, 0, 0, 0) }
            setOnClickListener { sendRemoteCommand("/remote/media", JSONObject().put("action", "vol_mute")) }
        }

        volRow.addView(volUpBtn)
        volRow.addView(volDownBtn)
        volRow.addView(volMuteBtn)

        // Media Playback Controls
        val mediaTitle = TextView(this).apply {
            text = "PC PLAYBACK CONTROLS"
            textSize = 12f
            setTextColor(0xFF00BFA5.toInt())
            setTypeface(null, Typeface.BOLD)
            setPadding(0, 48, 0, 16)
        }

        val mediaRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }

        val prevTrackBtn = Button(this).apply {
            text = "⏮ Prev"
            background = createRoundedDrawable(cardBg, 20f)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(0, 0, 8, 0) }
            setOnClickListener { sendRemoteCommand("/remote/media", JSONObject().put("action", "prev")) }
        }

        val playPauseBtn = Button(this).apply {
            text = "⏯ Play/Pause"
            background = createRoundedDrawable(0xFF10B981.toInt(), 20f)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(4, 0, 4, 0) }
            setOnClickListener { sendRemoteCommand("/remote/media", JSONObject().put("action", "play_pause")) }
        }

        val nextTrackBtn = Button(this).apply {
            text = "⏭ Next"
            background = createRoundedDrawable(cardBg, 20f)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f).apply { setMargins(8, 0, 0, 0) }
            setOnClickListener { sendRemoteCommand("/remote/media", JSONObject().put("action", "next")) }
        }

        mediaRow.addView(prevTrackBtn)
        mediaRow.addView(playPauseBtn)
        mediaRow.addView(nextTrackBtn)

        // Power / Lock Screen
        val lockBtn = Button(this).apply {
            text = "🔒 Lock PC Screen"
            textSize = 16f
            setTextColor(0xFFFFFFFF.toInt())
            background = createRoundedDrawable(0xFFEF4444.toInt(), 24f)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { setMargins(0, 64, 0, 0) }
            setOnClickListener { sendRemoteCommand("/remote/media", JSONObject().put("action", "lock")) }
        }

        content.addView(navHeader)
        content.addView(volTitle)
        content.addView(volRow)
        content.addView(mediaTitle)
        content.addView(mediaRow)
        content.addView(lockBtn)

        mainContainer.addView(content)
    }

    private fun sendRemoteCommand(endpoint: String, json: JSONObject) {
        thread {
            val savedPcIp = prefs.getString("pc_host_ip", null)
            val candidateIps = mutableListOf<String>()

            if (!savedPcIp.isNullOrEmpty()) candidateIps.add(savedPcIp)

            try {
                val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                val gatewayIp = Formatter.formatIpAddress(wifiManager.dhcpInfo.gateway)
                if (gatewayIp.isNotEmpty() && gatewayIp != "0.0.0.0" && !candidateIps.contains(gatewayIp)) {
                    candidateIps.add(gatewayIp)
                }
            } catch (e: Exception) {}

            if (!candidateIps.contains("127.0.0.1")) candidateIps.add("127.0.0.1")

            val ports = intArrayOf(8080, 4567, 38947)

            for (host in candidateIps) {
                for (port in ports) {
                    try {
                        val url = URL("http://$host:$port$endpoint")
                        val conn = url.openConnection() as HttpURLConnection
                        conn.requestMethod = "POST"
                        conn.doOutput = true
                        conn.connectTimeout = 800
                        conn.readTimeout = 800
                        conn.setRequestProperty("Content-Type", "application/json")

                        conn.outputStream.use { os ->
                            os.write(json.toString().toByteArray(Charsets.UTF_8))
                        }

                        if (conn.responseCode == 200) return@thread
                    } catch (e: Exception) {}
                }
            }
        }
    }

    private fun showThemeSelectorDialog() {
        val modes = arrayOf("System Default", "Dark Mode", "Light Mode")
        val currentIdx = when (currentThemeMode) {
            "dark" -> 1
            "light" -> 2
            else -> 0
        }

        AlertDialog.Builder(this)
            .setTitle("Select Appearance Theme")
            .setSingleChoiceItems(modes, currentIdx) { dialog, which ->
                currentThemeMode = when (which) {
                    1 -> "dark"
                    2 -> "light"
                    else -> "system"
                }
                prefs.edit().putString("theme_mode", currentThemeMode).apply()
                dialog.dismiss()
                applyThemeAndRefreshUI()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun createActionCard(
        title: String,
        subtitle: String,
        iconRes: Int,
        cardBg: Int,
        iconBgColor: Int,
        textPrimary: Int,
        textSecondary: Int,
        onClick: () -> Unit
    ): View {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(40, 36, 40, 36)
            background = createRoundedDrawable(cardBg, 32f)
            elevation = 2f
            setOnClickListener { onClick() }
        }

        val iconBg = ImageView(this).apply {
            setImageResource(iconRes)
            setPadding(24, 24, 24, 24)
            background = createRoundedDrawable(iconBgColor, 24f)
            layoutParams = LinearLayout.LayoutParams(96, 96)
        }

        val textLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(32, 0, 0, 0)
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }

        val titleTv = TextView(this).apply {
            text = title
            textSize = 15f
            setTextColor(textPrimary)
            setTypeface(null, Typeface.BOLD)
        }

        val subtitleTv = TextView(this).apply {
            text = subtitle
            textSize = 12f
            setTextColor(textSecondary)
            setPadding(0, 4, 0, 0)
        }

        textLayout.addView(titleTv)
        textLayout.addView(subtitleTv)

        val arrow = TextView(this).apply {
            text = "→"
            textSize = 20f
            setTextColor(textSecondary)
        }

        card.addView(iconBg)
        card.addView(textLayout)
        card.addView(arrow)

        return card
    }

    private fun showPermissionsScreen() {
        currentScreen = "permissions"
        mainContainer.removeAllViews()

        val isDark = isDarkModeActive()
        val textPrimary = if (isDark) 0xFFF8FAFC.toInt() else 0xFF1E1B18.toInt()
        val textSecondary = if (isDark) 0xFF94A3B8.toInt() else 0xFF78716C.toInt()
        val cardBg = if (isDark) 0xFF1E293B.toInt() else 0xFFFFFFFF.toInt()

        val scrollView = ScrollView(this).apply { isFillViewport = true }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 80, 48, 48)
        }

        // Header Navigation Bar
        val navHeader = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, 64)
        }

        val backBtn = TextView(this).apply {
            text = "← Back"
            textSize = 16f
            setTextColor(0xFF00BFA5.toInt())
            setTypeface(null, Typeface.BOLD)
            setOnClickListener { showHomeScreen() }
        }

        val headerTitle = TextView(this).apply {
            text = "Companion Permissions"
            textSize = 20f
            setTextColor(textPrimary)
            setTypeface(null, Typeface.BOLD)
            setPadding(32, 0, 0, 0)
        }

        navHeader.addView(backBtn)
        navHeader.addView(headerTitle)

        content.addView(navHeader)

        val perms = checkAllPermissions()
        for (p in perms) {
            val itemCard = createPermissionItemCard(p, !p.isGranted, cardBg, textPrimary, textSecondary)
            content.addView(itemCard)
            content.addView(createSpacer(16))
        }

        scrollView.addView(content)
        mainContainer.addView(scrollView)
    }

    private fun createPermissionItemCard(
        perm: PermissionModel,
        isRequired: Boolean,
        cardBg: Int,
        textPrimary: Int,
        textSecondary: Int
    ): View {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(40, 32, 40, 32)
            background = createRoundedDrawable(cardBg, 32f)
            elevation = 2f
        }

        val textLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }

        val titleTv = TextView(this).apply {
            text = perm.title
            textSize = 14f
            setTextColor(textPrimary)
            setTypeface(null, Typeface.BOLD)
        }

        val descTv = TextView(this).apply {
            text = perm.desc
            textSize = 11f
            setTextColor(textSecondary)
            setPadding(0, 4, 0, 0)
        }

        textLayout.addView(titleTv)
        textLayout.addView(descTv)

        val actionBtn = TextView(this).apply {
            if (isRequired) {
                text = "→"
                textSize = 18f
                setTextColor(0xFFFFFFFF.toInt())
                gravity = Gravity.CENTER
                setPadding(28, 14, 28, 14)
                background = createRoundedDrawable(0xFF1E1B18.toInt(), 20f)
                setOnClickListener {
                    perm.onRequest(this@MainActivity)
                }
            } else {
                text = "✓"
                textSize = 16f
                setTextColor(0xFF10B981.toInt())
                gravity = Gravity.CENTER
                setPadding(24, 14, 24, 14)
                background = createRoundedDrawable(0xFF064E3B.toInt(), 20f)
            }
        }

        card.addView(textLayout)
        card.addView(actionBtn)

        return card
    }

    private fun checkAllPermissions(): List<PermissionModel> {
        val list = mutableListOf(
            PermissionModel("Notification Access", "Required to sync Notifications and Media playback", isNotificationListenerEnabled()) {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
            },
            PermissionModel("Read Contacts", "Required to access contacts stored on the device", checkPerm(Manifest.permission.READ_CONTACTS)) {
                ActivityCompat.requestPermissions(it, arrayOf(Manifest.permission.READ_CONTACTS), 101)
            },
            PermissionModel("Write Contacts", "Required to add, edit or delete contacts", checkPerm(Manifest.permission.WRITE_CONTACTS)) {
                ActivityCompat.requestPermissions(it, arrayOf(Manifest.permission.WRITE_CONTACTS), 102)
            },
            PermissionModel("Read Call Log", "Required to read call history from the device", checkPerm(Manifest.permission.READ_CALL_LOG)) {
                ActivityCompat.requestPermissions(it, arrayOf(Manifest.permission.READ_CALL_LOG), 103)
            },
            PermissionModel("Make Calls", "Required to programmatically place phone calls", checkPerm(Manifest.permission.CALL_PHONE)) {
                ActivityCompat.requestPermissions(it, arrayOf(Manifest.permission.CALL_PHONE), 104)
            },
            PermissionModel("Battery Optimization", "Required to keep service alive in background", isBatteryOptimizationDisabled()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                }
            }
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            list.add(PermissionModel("Bluetooth Connect", "Required to monitor connected Bluetooth devices", checkPerm(Manifest.permission.BLUETOOTH_CONNECT)) {
                ActivityCompat.requestPermissions(it, arrayOf(Manifest.permission.BLUETOOTH_CONNECT), 105)
            })
            list.add(PermissionModel("Bluetooth Scan", "Required to discover nearby Bluetooth devices", checkPerm(Manifest.permission.BLUETOOTH_SCAN)) {
                ActivityCompat.requestPermissions(it, arrayOf(Manifest.permission.BLUETOOTH_SCAN), 106)
            })
        }

        return list
    }

    private fun checkPerm(perm: String) =
        ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED

    private fun isNotificationListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(packageName)
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(PowerManager::class.java)
            pm?.isIgnoringBatteryOptimizations(packageName) ?: false
        } else true
    }

    private fun getDeviceIpAddress(): String {
        return try {
            val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            val ip = Formatter.formatIpAddress(wifiManager.connectionInfo.ipAddress)
            "Device IP: $ip:8080"
        } catch (_: Exception) {
            "Device IP: 127.0.0.1:8080"
        }
    }

    private fun createRoundedDrawable(bgColor: Int, radius: Float): android.graphics.drawable.GradientDrawable {
        return android.graphics.drawable.GradientDrawable().apply {
            setColor(bgColor)
            cornerRadius = radius
        }
    }

    private fun createSpacer(heightPx: Int): View {
        return View(this).apply {
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, heightPx)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (currentScreen != "home") {
            showHomeScreen()
        } else {
            @Suppress("DEPRECATION")
            super.onBackPressed()
        }
    }

    data class PermissionModel(
        val title: String,
        val desc: String,
        val isGranted: Boolean,
        val onRequest: (AppCompatActivity) -> Unit
    )
}
