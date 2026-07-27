import 'dart:io';
import 'package:flutter/material.dart';
import 'package:adb_device_manager/core/models/device_state.dart';
import 'package:adb_device_manager/core/adb/adb_device_scanner.dart';

enum QuickSettingsSubPanel {
  main,
  wifi,
  bluetooth,
  audioControls,
  mediaOutput,
}

class QuickSettingsPopover extends StatefulWidget {
  final DeviceState? deviceState;
  final VoidCallback? onLockDex;
  final VoidCallback? onShutdown;
  final VoidCallback? onRestart;
  final VoidCallback? onRestartDexApp;
  final VoidCallback? onTakeScreenshot;
  final VoidCallback? onOpenDeviceHealth;
  final VoidCallback? onOpenWirelessAdb;
  final VoidCallback? onShowSystemInfo;
  final VoidCallback? onOpenFullSettings;

  const QuickSettingsPopover({
    super.key,
    this.deviceState,
    this.onLockDex,
    this.onShutdown,
    this.onRestart,
    this.onRestartDexApp,
    this.onTakeScreenshot,
    this.onOpenDeviceHealth,
    this.onOpenWirelessAdb,
    this.onShowSystemInfo,
    this.onOpenFullSettings,
  });

  @override
  State<QuickSettingsPopover> createState() => _QuickSettingsPopoverState();
}

class _QuickSettingsPopoverState extends State<QuickSettingsPopover> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Subpanel navigation state
  QuickSettingsSubPanel _currentPanel = QuickSettingsSubPanel.main;
  bool _isNavigatingForward = true;

  // Connection & System states
  bool _wifiEnabled = true;
  final String _wifiSsid = "GameTI WIFI";
  bool _bluetoothEnabled = true;
  final String _bluetoothStatus = "On";

  bool _isMuted = false;
  bool _isTorchOn = false;
  bool _isAirplane = false;
  bool _isMobileDataOn = true;
  bool _isAutoRotateOn = true;
  bool _isDndOn = false;
  bool _isDarkMode = true;
  bool _isNightLightOn = false;
  bool _isLocationOn = true;

  // Volume & Brightness Sliders
  double _mediaVolume = 0.75;
  double _callVolume = 0.85;
  double _ringVolume = 0.80;
  double _alarmVolume = 0.65;
  double _brightness = 0.80;
  double _appVolume = 0.70;

  // Media Output Choice
  String _selectedMediaOutput = "Android (system)";

  // Bluetooth scanning state & paired devices list
  bool _isScanningBluetooth = false;

  final List<Map<String, dynamic>> _bluetoothDevices = [
    {
      'name': 'oraimo FreePods lite',
      'status': 'Paired',
      'icon': Icons.headphones_rounded,
      'type': 'headset',
      'connected': true,
    },
    {
      'name': 'W54336869000841',
      'status': 'Paired',
      'icon': Icons.bluetooth_rounded,
      'type': 'device',
      'connected': false,
    },
    {
      'name': 'oraimo FreePods lite',
      'status': 'Paired',
      'icon': Icons.headphones_rounded,
      'type': 'headset',
      'connected': false,
    },
    {
      'name': '联想 thinkplus-XT92',
      'status': 'Paired',
      'icon': Icons.headphones_rounded,
      'type': 'headset',
      'connected': false,
    },
    {
      'name': 'MX Keys',
      'status': 'Paired',
      'icon': Icons.keyboard_rounded,
      'type': 'keyboard',
      'connected': false,
    },
    {
      'name': 'BT SPEAKER',
      'status': 'Paired',
      'icon': Icons.speaker_rounded,
      'type': 'speaker',
      'connected': false,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateTo(QuickSettingsSubPanel panel) {
    setState(() {
      _isNavigatingForward = true;
      _currentPanel = panel;
    });
  }

  void _navigateBack() {
    setState(() {
      _isNavigatingForward = false;
      _currentPanel = QuickSettingsSubPanel.main;
    });
  }

  Future<void> _toggleTorch() async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    setState(() => _isTorchOn = !_isTorchOn);
    await Process.run(adbPath, [
      'shell',
      'cmd',
      'status_bar',
      _isTorchOn ? 'turn-on-flashlight' : 'turn-off-flashlight'
    ]);
  }

  Future<void> _toggleMute() async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    setState(() => _isMuted = !_isMuted);
    await Process.run(adbPath, ['shell', 'input', 'keyevent', '164']);
  }

  Future<void> _setBrightness(double value) async {
    setState(() => _brightness = value);
    final adbPath = await AdbDeviceScanner.getAdbPath();
    final bValue = (value * 255).toInt();
    await Process.run(adbPath,
        ['shell', 'settings', 'put', 'system', 'screen_brightness', '$bValue']);
  }

  Future<void> _setStreamVolume(int streamType, double value) async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    final volInt = (value * 15).toInt();
    await Process.run(
        adbPath, ['shell', 'cmd', 'audio', 'set-stream-volume', '$streamType', '$volInt']);
  }

  Future<void> _toggleDnd() async {
    setState(() => _isDndOn = !_isDndOn);
    final adbPath = await AdbDeviceScanner.getAdbPath();
    await Process.run(adbPath,
        ['shell', 'cmd', 'notification', 'set_dnd', _isDndOn ? 'on' : 'off']);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 370,
      constraints: const BoxConstraints(maxHeight: 620),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1528).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 36,
            spreadRadius: 6,
          )
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isIncomingMain =
              child.key == const ValueKey(QuickSettingsSubPanel.main);
          final offsetBegin = isIncomingMain
              ? const Offset(-1.0, 0.0)
              : const Offset(1.0, 0.0);
          return SlideTransition(
            position: Tween<Offset>(
              begin: _isNavigatingForward ? offsetBegin : -offsetBegin,
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: _buildCurrentPanelWidget(),
      ),
    );
  }

  Widget _buildCurrentPanelWidget() {
    switch (_currentPanel) {
      case QuickSettingsSubPanel.wifi:
        return _buildWifiPanel(key: const ValueKey(QuickSettingsSubPanel.wifi));
      case QuickSettingsSubPanel.bluetooth:
        return _buildBluetoothPanel(key: const ValueKey(QuickSettingsSubPanel.bluetooth));
      case QuickSettingsSubPanel.audioControls:
        return _buildAudioControlsPanel(key: const ValueKey(QuickSettingsSubPanel.audioControls));
      case QuickSettingsSubPanel.mediaOutput:
        return _buildMediaOutputPanel(key: const ValueKey(QuickSettingsSubPanel.mediaOutput));
      case QuickSettingsSubPanel.main:
        return _buildMainPanel(key: const ValueKey(QuickSettingsSubPanel.main));
    }
  }

  // ==========================================
  // 1. MAIN QUICK SETTINGS PANEL
  // ==========================================
  Widget _buildMainPanel({required Key key}) {
    return SingleChildScrollView(
      key: key,
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Route Info Header
          ValueListenableBuilder<String>(
            valueListenable:
                widget.deviceState?.deviceIp ?? ValueNotifier('USB Device'),
            builder: (_, ip, __) {
              final isWireless = ip.contains(':') ||
                  RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(ip);
              final String connLabel =
                  isWireless ? "Wireless ADB ($ip)" : "USB DEX Connection";
              final IconData connIcon =
                  isWireless ? Icons.wifi_tethering : Icons.usb;

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF00BFA5).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(connIcon, color: const Color(0xFF00BFA5), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        connLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00BFA5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "Active",
                      style: TextStyle(
                          color: Color(0xFF00BFA5),
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.settings_suggest_rounded,
                          color: Colors.white70, size: 18),
                      tooltip: "Dex Settings Window",
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: widget.onOpenFullSettings,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Top Row: Wi-Fi & Bluetooth Split Pills with Subpanel Arrows
          Row(
            children: [
              // Wi-Fi Pill
              Expanded(
                child: _buildSplitPill(
                  icon: Icons.wifi_rounded,
                  title: "Wi-Fi",
                  subtitle: _wifiEnabled ? _wifiSsid : "Off",
                  isActive: _wifiEnabled,
                  onMainTap: () => setState(() => _wifiEnabled = !_wifiEnabled),
                  onArrowTap: () => _navigateTo(QuickSettingsSubPanel.wifi),
                ),
              ),
              const SizedBox(width: 10),
              // Bluetooth Pill
              Expanded(
                child: _buildSplitPill(
                  icon: Icons.bluetooth_rounded,
                  title: "Bluetooth",
                  subtitle: _bluetoothEnabled ? _bluetoothStatus : "Off",
                  isActive: _bluetoothEnabled,
                  onMainTap: () =>
                      setState(() => _bluetoothEnabled = !_bluetoothEnabled),
                  onArrowTap: () => _navigateTo(QuickSettingsSubPanel.bluetooth),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Paginated Quick Toggle Grid
          SizedBox(
            height: 165,
            child: PageView(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              children: [
                // Page 1: Core Controls
                _buildPageGrid([
                  _buildToggleItem(
                    icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    label: "Mute",
                    isActive: _isMuted,
                    onTap: _toggleMute,
                  ),
                  _buildToggleItem(
                    icon: Icons.signal_cellular_alt_rounded,
                    label: "Mobile data",
                    isActive: _isMobileDataOn,
                    onTap: () =>
                        setState(() => _isMobileDataOn = !_isMobileDataOn),
                  ),
                  _buildToggleItem(
                    icon: Icons.airplanemode_active_rounded,
                    label: "Airplane",
                    isActive: _isAirplane,
                    onTap: () => setState(() => _isAirplane = !_isAirplane),
                  ),
                  _buildToggleItem(
                    icon: Icons.screen_rotation_rounded,
                    label: "Rotate",
                    isActive: _isAutoRotateOn,
                    onTap: () =>
                        setState(() => _isAutoRotateOn = !_isAutoRotateOn),
                  ),
                  _buildToggleItem(
                    icon: Icons.location_on_rounded,
                    label: "Location",
                    isActive: _isLocationOn,
                    onTap: () =>
                        setState(() => _isLocationOn = !_isLocationOn),
                  ),
                  _buildToggleItem(
                    icon: Icons.flashlight_on_rounded,
                    label: "Torch",
                    isActive: _isTorchOn,
                    onTap: _toggleTorch,
                  ),
                  _buildToggleItem(
                    icon: Icons.lock_rounded,
                    label: "Lock",
                    isActive: false,
                    onTap: widget.onLockDex ?? () {},
                  ),
                ]),

                // Page 2: System Utilities
                _buildPageGrid([
                  _buildToggleItem(
                    icon: Icons.screenshot_monitor_rounded,
                    label: "Screenshot",
                    isActive: false,
                    onTap: widget.onTakeScreenshot ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.do_not_disturb_on_rounded,
                    label: "DND",
                    isActive: _isDndOn,
                    onTap: _toggleDnd,
                  ),
                  _buildToggleItem(
                    icon: _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    label: _isDarkMode ? "Dark Mode" : "Light Mode",
                    isActive: _isDarkMode,
                    onTap: () => setState(() => _isDarkMode = !_isDarkMode),
                  ),
                  _buildToggleItem(
                    icon: Icons.remove_red_eye_rounded,
                    label: "Night Light",
                    isActive: _isNightLightOn,
                    onTap: () =>
                        setState(() => _isNightLightOn = !_isNightLightOn),
                  ),
                  _buildToggleItem(
                    icon: Icons.monitor_heart_rounded,
                    label: "Health",
                    isActive: false,
                    onTap: widget.onOpenDeviceHealth ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.adb_rounded,
                    label: "Wireless ADB",
                    isActive: false,
                    onTap: widget.onOpenWirelessAdb ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.info_outline_rounded,
                    label: "Sys Info",
                    isActive: false,
                    onTap: widget.onShowSystemInfo ?? () {},
                  ),
                ]),

                // Page 3: Power Session
                _buildPageGrid([
                  _buildToggleItem(
                    icon: Icons.power_settings_new_rounded,
                    label: "Shutdown",
                    isActive: false,
                    onTap: widget.onShutdown ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.restart_alt_rounded,
                    label: "Reboot Device",
                    isActive: false,
                    onTap: widget.onRestart ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.refresh_rounded,
                    label: "Restart App",
                    isActive: false,
                    onTap: widget.onRestartDexApp ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.bedtime_rounded,
                    label: "Sleep",
                    isActive: false,
                    onTap: () => AdbDeviceScanner.getAdbPath().then((adb) =>
                        Process.run(adb, ['shell', 'input', 'keyevent', '26'])),
                  ),
                ]),
              ],
            ),
          ),

          // Page Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              final isActive = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF00BFA5) : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Audio Volume Slider Pill Card with Subpanel Chevron Arrow
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PillSlider(
                    value: _mediaVolume,
                    icon: _isMuted ? Icons.volume_off_rounded : Icons.music_note_rounded,
                    onChanged: (v) {
                      setState(() => _mediaVolume = v);
                      _setStreamVolume(3, v);
                    },
                  ),
                ),
                InkWell(
                  onTap: () => _navigateTo(QuickSettingsSubPanel.audioControls),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.chevron_right_rounded,
                        color: Colors.white70, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Display Brightness Slider Pill Card
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PillSlider(
                    value: _brightness,
                    icon: Icons.brightness_6_rounded,
                    onChanged: _setBrightness,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.wb_sunny_rounded,
                      color: Colors.white38, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Media Output Tile with Subpanel Chevron Arrow
          InkWell(
            onTap: () => _navigateTo(QuickSettingsSubPanel.mediaOutput),
            borderRadius: BorderRadius.circular(26),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.disc_full_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Media output",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Footer Restriction Note
          const Center(
            child: Text(
              "Some controls may be restricted by Android",
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Split Pill Widget for Wi-Fi and Bluetooth
  Widget _buildSplitPill({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onMainTap,
    required VoidCallback onArrowTap,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(27),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onMainTap,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(27),
                bottomLeft: Radius.circular(27),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isActive ? const Color(0xFF1E1528) : Colors.white70,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isActive ? Colors.white70 : Colors.white38,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            color: Colors.white24,
          ),
          InkWell(
            onTap: onArrowTap,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(27),
              bottomRight: Radius.circular(27),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. MEDIA OUTPUT SUBPANEL
  // ==========================================
  Widget _buildMediaOutputPanel({required Key key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subpanel Header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 24),
              onPressed: _navigateBack,
            ),
            const SizedBox(width: 4),
            const Text(
              "Media output",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Device Option 1: Android (system)
        _buildMediaDeviceTile(
          title: "Android (system)",
          isSelected: _selectedMediaOutput == "Android (system)",
          onTap: () => setState(() => _selectedMediaOutput = "Android (system)"),
        ),
        const SizedBox(height: 10),

        // Device Option 2: Android Dex
        _buildMediaDeviceTile(
          title: "Android Dex",
          isSelected: _selectedMediaOutput == "Android Dex",
          onTap: () => setState(() => _selectedMediaOutput = "Android Dex"),
        ),
        const SizedBox(height: 20),

        // Section: App Audio
        const Text(
          "App Audio",
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),

        // Active App Audio Card (Samsung Music style)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.music_note_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Samsung Music",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 18),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 24),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: _PillSlider(
                  value: _appVolume,
                  icon: Icons.volume_up_rounded,
                  onChanged: (v) => setState(() => _appVolume = v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Footer Restriction Note
        const Center(
          child: Text(
            "Some controls may be restricted by Android",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaDeviceTile({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? const Color(0xFF3B82F6) : Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. BLUETOOTH DEVICES SUBPANEL
  // ==========================================
  Widget _buildBluetoothPanel({required Key key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subpanel Header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 24),
              onPressed: _navigateBack,
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                "Bluetooth Devices",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),

            // Scan Action Button
            InkWell(
              onTap: () {
                setState(() => _isScanningBluetooth = true);
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => _isScanningBluetooth = false);
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    if (_isScanningBluetooth)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    else
                      const Icon(Icons.search_rounded,
                          color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      "Scan",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white70, size: 18),
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Section Label
        const Text(
          "PAIRED DEVICES",
          style: TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        // Scrollable Paired Devices List
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: _bluetoothDevices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final dev = _bluetoothDevices[index];
              return Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(dev['icon'] as IconData,
                          color: Colors.white70, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dev['name'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            dev['status'] as String,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.power_input_rounded,
                          color: Colors.white38, size: 16),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded,
                          color: Colors.white38, size: 16),
                      onPressed: () {},
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 4. AUDIO CONTROLS SUBPANEL
  // ==========================================
  Widget _buildAudioControlsPanel({required Key key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subpanel Header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 24),
              onPressed: _navigateBack,
            ),
            const SizedBox(width: 4),
            const Text(
              "Audio Controls",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Slider 1: Media / Music Volume
        _buildVolumePillCard(
          icon: Icons.music_note_rounded,
          value: _mediaVolume,
          onChanged: (v) {
            setState(() => _mediaVolume = v);
            _setStreamVolume(3, v);
          },
        ),
        const SizedBox(height: 12),

        // Slider 2: Call Volume
        _buildVolumePillCard(
          icon: Icons.phone_rounded,
          value: _callVolume,
          onChanged: (v) {
            setState(() => _callVolume = v);
            _setStreamVolume(0, v);
          },
        ),
        const SizedBox(height: 12),

        // Slider 3: Ringtone Volume
        _buildVolumePillCard(
          icon: Icons.notifications_rounded,
          value: _ringVolume,
          onChanged: (v) {
            setState(() => _ringVolume = v);
            _setStreamVolume(2, v);
          },
        ),
        const SizedBox(height: 12),

        // Slider 4: Alarm Volume
        _buildVolumePillCard(
          icon: Icons.alarm_rounded,
          value: _alarmVolume,
          onChanged: (v) {
            setState(() => _alarmVolume = v);
            _setStreamVolume(4, v);
          },
        ),
        const SizedBox(height: 24),

        // Footer Restriction Note
        const Center(
          child: Text(
            "Some controls may be restricted by Android",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVolumePillCard({
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(26),
      ),
      child: _PillSlider(
        value: value,
        icon: icon,
        onChanged: onChanged,
      ),
    );
  }

  // ==========================================
  // 5. WI-FI SUBPANEL
  // ==========================================
  Widget _buildWifiPanel({required Key key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subpanel Header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white, size: 24),
              onPressed: _navigateBack,
            ),
            const SizedBox(width: 4),
            const Text(
              "Wi-Fi & Wireless",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Main Wi-Fi Switch Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF00BFA5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_rounded,
                    color: Colors.black, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Wi-Fi Network",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _wifiEnabled ? "Connected to $_wifiSsid" : "Disconnected",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _wifiEnabled,
                activeTrackColor: const Color(0xFF00BFA5),
                onChanged: (v) => setState(() => _wifiEnabled = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Section Label
        const Text(
          "CONNECTED NETWORK",
          style: TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        // Connected Network Details Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_lock_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _wifiSsid,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Text(
                      "5GHz • Strong Signal • IP 192.168.1.100",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded,
                    color: Colors.white54, size: 18),
                onPressed: () {},
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Footer Restriction Note
        const Center(
          child: Text(
            "Some controls may be restricted by Android",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // Grid builder for paginated quick toggles
  Widget _buildPageGrid(List<Widget> children) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: children,
    );
  }

  // Toggle item for circular quick toggles
  Widget _buildToggleItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? const Color(0xFF1E1528) : Colors.white70,
              size: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CUSTOM PILL SLIDER WIDGET (Android One UI Style)
// ==========================================
class _PillSlider extends StatelessWidget {
  final double value;
  final IconData icon;
  final ValueChanged<double> onChanged;

  const _PillSlider({
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final clampedValue = value.clamp(0.0, 1.0);
        final fillWidth = (totalWidth * clampedValue).clamp(44.0, totalWidth);

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final dx = details.localPosition.dx;
            final newValue = (dx / totalWidth).clamp(0.0, 1.0);
            onChanged(newValue);
          },
          onTapDown: (details) {
            final dx = details.localPosition.dx;
            final newValue = (dx / totalWidth).clamp(0.0, 1.0);
            onChanged(newValue);
          },
          child: Stack(
            children: [
              // Background Track
              Container(
                width: totalWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
              ),

              // Filled Active Track (Smooth White Fill)
              AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                width: fillWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
              ),

              // Floating Icon inside Pill
              Positioned(
                left: 6,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Icon(
                    icon,
                    color: clampedValue > 0.15 ? const Color(0xFF1E1528) : Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
