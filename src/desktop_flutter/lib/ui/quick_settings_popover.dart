import 'dart:io';
import 'package:flutter/material.dart';
import '../models/device_state.dart';
import '../services/adb_device_scanner.dart';

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

  bool _isMuted = false;
  bool _isTorchOn = false;
  bool _isAirplane = false;
  bool _isMobileDataOn = true;
  bool _isAutoRotateOn = true;
  bool _isMirroringOn = true;
  bool _isDndOn = false;
  bool _isDarkMode = true;
  bool _isNightLightOn = false;
  bool _isLocationOn = true;

  double _volume = 0.7;
  double _brightness = 0.8;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  Future<void> _toggleDnd() async {
    setState(() => _isDndOn = !_isDndOn);
    final adbPath = await AdbDeviceScanner.getAdbPath();
    await Process.run(adbPath,
        ['shell', 'cmd', 'notification', 'set_dnd', _isDndOn ? 'on' : 'off']);
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 4,
          )
        ],
      ),
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
                  color: const Color(0xFF1E293B),
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

          // Wi-Fi & Bluetooth Pills
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi, color: Color(0xFF00BFA5), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Wi-Fi",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11)),
                            Text("Connected",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 10),
                                maxLines: 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bluetooth, color: Colors.blueAccent, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Bluetooth",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11)),
                            Text("Active",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Paginated PageView Container
          SizedBox(
            height: 165,
            child: PageView(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              children: [
                // Page 1: Connectivity & Core Toggles
                _buildPageGrid([
                  _buildToggleItem(
                    icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                    label: "Mute",
                    tooltip: "Toggle Audio Mute",
                    isActive: _isMuted,
                    onTap: _toggleMute,
                  ),
                  _buildToggleItem(
                    icon: Icons.signal_cellular_alt,
                    label: "Mobile data",
                    tooltip: "Toggle Mobile Data",
                    isActive: _isMobileDataOn,
                    onTap: () =>
                        setState(() => _isMobileDataOn = !_isMobileDataOn),
                  ),
                  _buildToggleItem(
                    icon: Icons.airplanemode_active,
                    label: "Airplane",
                    tooltip: "Toggle Airplane Mode",
                    isActive: _isAirplane,
                    onTap: () => setState(() => _isAirplane = !_isAirplane),
                  ),
                  _buildToggleItem(
                    icon: Icons.flash_on,
                    label: "Torch",
                    tooltip: "Toggle Flashlight",
                    isActive: _isTorchOn,
                    onTap: _toggleTorch,
                  ),
                  _buildToggleItem(
                    icon: Icons.screen_rotation,
                    label: "Rotate",
                    tooltip: "Toggle Auto Rotation",
                    isActive: _isAutoRotateOn,
                    onTap: () =>
                        setState(() => _isAutoRotateOn = !_isAutoRotateOn),
                  ),
                  _buildToggleItem(
                    icon: Icons.location_on,
                    label: "Location",
                    tooltip: "Toggle Location Services",
                    isActive: _isLocationOn,
                    onTap: () => setState(() => _isLocationOn = !_isLocationOn),
                  ),
                  _buildToggleItem(
                    icon: Icons.phonelink,
                    label: "Mirroring",
                    tooltip: "Toggle Screen Mirroring",
                    isActive: _isMirroringOn,
                    onTap: () =>
                        setState(() => _isMirroringOn = !_isMirroringOn),
                  ),
                  _buildToggleItem(
                    icon: Icons.lock_clock,
                    label: "Lock DEX",
                    tooltip: "Lock DEX Desktop Session",
                    isActive: false,
                    onTap: widget.onLockDex ?? () {},
                  ),
                ]),

                // Page 2: System Utilities & Tools
                _buildPageGrid([
                  _buildToggleItem(
                    icon: Icons.screenshot_monitor,
                    label: "Screenshot",
                    tooltip: "Take Android Screen Capture",
                    isActive: false,
                    onTap: widget.onTakeScreenshot ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.do_not_disturb_on,
                    label: "DND",
                    tooltip: "Toggle Do Not Disturb Mode",
                    isActive: _isDndOn,
                    onTap: _toggleDnd,
                  ),
                  _buildToggleItem(
                    icon: _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    label: _isDarkMode ? "Dark Mode" : "Light Mode",
                    tooltip: "Toggle Theme Mode",
                    isActive: _isDarkMode,
                    onTap: () => setState(() => _isDarkMode = !_isDarkMode),
                  ),
                  _buildToggleItem(
                    icon: Icons.remove_red_eye,
                    label: "Night Light",
                    tooltip: "Toggle Blue Light Filter",
                    isActive: _isNightLightOn,
                    onTap: () =>
                        setState(() => _isNightLightOn = !_isNightLightOn),
                  ),
                  _buildToggleItem(
                    icon: Icons.monitor_heart,
                    label: "Health",
                    tooltip: "Check Device Health & Permissions",
                    isActive: false,
                    onTap: widget.onOpenDeviceHealth ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.adb,
                    label: "Wireless ADB",
                    tooltip: "Configure Wireless ADB Connection",
                    isActive: false,
                    onTap: widget.onOpenWirelessAdb ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.info_outline,
                    label: "Sys Info",
                    tooltip: "View Hardware & System Info",
                    isActive: false,
                    onTap: widget.onShowSystemInfo ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.lock,
                    label: "Screen Lock",
                    tooltip: "Lock Screen",
                    isActive: false,
                    onTap: widget.onLockDex ?? () {},
                  ),
                ]),

                // Page 3: Power & Session Controls
                _buildPageGrid([
                  _buildToggleItem(
                    icon: Icons.power_settings_new,
                    label: "Shutdown",
                    tooltip: "Power Off Connected Android Device",
                    isActive: false,
                    activeColor: Colors.redAccent,
                    onTap: widget.onShutdown ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.restart_alt,
                    label: "Reboot Device",
                    tooltip: "Reboot Connected Android Device",
                    isActive: false,
                    activeColor: Colors.orangeAccent,
                    onTap: widget.onRestart ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.refresh_rounded,
                    label: "Restart App",
                    tooltip: "Restart DEX Desktop Application",
                    isActive: false,
                    activeColor: Colors.cyanAccent,
                    onTap: widget.onRestartDexApp ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.lock_outlined,
                    label: "Lock DEX",
                    tooltip: "Lock DEX Desktop Session",
                    isActive: false,
                    activeColor: const Color(0xFF00BFA5),
                    onTap: widget.onLockDex ?? () {},
                  ),
                  _buildToggleItem(
                    icon: Icons.bedtime,
                    label: "Sleep",
                    tooltip: "Put Display to Sleep",
                    isActive: false,
                    onTap: () => AdbDeviceScanner.getAdbPath().then((adb) =>
                        Process.run(adb, ['shell', 'input', 'keyevent', '26'])),
                  ),
                  _buildToggleItem(
                    icon: Icons.sync,
                    label: "Reset ADB",
                    tooltip: "Restart ADB Server Daemon",
                    isActive: false,
                    onTap: () async {
                      final adb = await AdbDeviceScanner.getAdbPath();
                      await Process.run(adb, ['kill-server']);
                      await Process.run(adb, ['start-server']);
                    },
                  ),
                  _buildToggleItem(
                    icon: Icons.settings_suggest_rounded,
                    label: "Settings",
                    tooltip: "Dex Settings Window",
                    isActive: false,
                    onTap: widget.onOpenFullSettings ??
                        widget.onShowSystemInfo ??
                        () {},
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Pagination Navigation & Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: Colors.white70, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed:
                    _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final isActive = _currentPage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          isActive ? const Color(0xFF00BFA5) : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: Colors.white70, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed:
                    _currentPage < 2 ? () => _goToPage(_currentPage + 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Volume Slider
          Row(
            children: [
              Icon(
                _isMuted || _volume == 0 ? Icons.volume_off : Icons.volume_down,
                color: Colors.grey,
                size: 18,
              ),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 4,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: Color(0xFF00BFA5),
                    inactiveTrackColor: Colors.white10,
                    thumbColor: Color(0xFF00BFA5),
                  ),
                  child: Slider(
                    value: _volume,
                    onChanged: (v) => setState(() => _volume = v),
                  ),
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.grey, size: 18),
            ],
          ),

          // Brightness Slider
          Row(
            children: [
              const Icon(Icons.brightness_low, color: Colors.grey, size: 18),
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 4,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: Colors.amberAccent,
                    inactiveTrackColor: Colors.white10,
                    thumbColor: Colors.amberAccent,
                  ),
                  child: Slider(
                    value: _brightness,
                    onChanged: _setBrightness,
                  ),
                ),
              ),
              const Icon(Icons.brightness_high, color: Colors.grey, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageGrid(List<Widget> children) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: children,
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    String? tooltip,
    Color activeColor = const Color(0xFF00BFA5),
  }) {
    return Tooltip(
      message: tooltip ?? label,
      child: InkWell(
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
                color: isActive ? activeColor : const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? activeColor : Colors.white10,
                ),
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.black : Colors.white70,
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
      ),
    );
  }
}
