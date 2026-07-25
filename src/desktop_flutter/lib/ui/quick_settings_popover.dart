import 'dart:io';
import 'package:flutter/material.dart';
import '../services/adb_device_scanner.dart';

class QuickSettingsPopover extends StatefulWidget {
  const QuickSettingsPopover({super.key});

  @override
  State<QuickSettingsPopover> createState() => _QuickSettingsPopoverState();
}

class _QuickSettingsPopoverState extends State<QuickSettingsPopover> {
  bool _isMuted = false;
  bool _isTorchOn = false;
  bool _isAirplane = false;
  double _volume = 0.7;

  Future<void> _toggleTorch() async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    setState(() => _isTorchOn = !_isTorchOn);
    await Process.run(adbPath, ['shell', 'cmd', 'status_bar', _isTorchOn ? 'turn-on-flashlight' : 'turn-off-flashlight']);
  }

  Future<void> _toggleMute() async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    setState(() => _isMuted = !_isMuted);
    await Process.run(adbPath, ['shell', 'input', 'keyevent', '164']); // KEYCODE_VOLUME_MUTE
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wi-Fi & Bluetooth Pills
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            Text("Wi-Fi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text("GameT1 WiFi", style: TextStyle(color: Colors.grey, fontSize: 10), maxLines: 1),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            Text("Bluetooth", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text("On", style: TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Toggles Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildToggleItem(
                icon: _isMuted ? Icons.volume_off : Icons.volume_up,
                label: "Mute",
                isActive: _isMuted,
                onTap: _toggleMute,
              ),
              _buildToggleItem(
                icon: Icons.signal_cellular_alt,
                label: "Mobile data",
                isActive: true,
                onTap: () {},
              ),
              _buildToggleItem(
                icon: Icons.airplanemode_active,
                label: "Airplane",
                isActive: _isAirplane,
                onTap: () => setState(() => _isAirplane = !_isAirplane),
              ),
              _buildToggleItem(
                icon: Icons.flash_on,
                label: "Torch",
                isActive: _isTorchOn,
                onTap: _toggleTorch,
              ),
              _buildToggleItem(
                icon: Icons.screen_rotation,
                label: "Rotate",
                isActive: true,
                onTap: () {},
              ),
              _buildToggleItem(
                icon: Icons.location_on,
                label: "Location",
                isActive: true,
                onTap: () {},
              ),
              _buildToggleItem(
                icon: Icons.lock,
                label: "Lock",
                isActive: false,
                onTap: () => AdbDeviceScanner.getAdbPath().then((adb) => Process.run(adb, ['shell', 'input', 'keyevent', '26'])),
              ),
              _buildToggleItem(
                icon: Icons.phonelink,
                label: "Mirroring",
                isActive: true,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Volume Slider
          Row(
            children: [
              const Icon(Icons.volume_down, color: Colors.grey, size: 18),
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
        ],
      ),
    );
  }

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
              color: isActive
                  ? const Color(0xFF00BFA5)
                  : const Color(0xFF1E293B),
              shape: BoxShape.circle,
              border: Border.all(
                  color: isActive
                      ? const Color(0xFF00BFA5)
                      : Colors.white10),
            ),
            child: Icon(icon,
                color: isActive ? Colors.black : Colors.white70, size: 18),
          ),
          const SizedBox(height: 2),
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
