import 'dart:io';
import 'package:flutter/material.dart';
import 'package:adb_device_manager/core/adb/adb_device_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DevicePermissionItem {
  final String title;
  final String permString;
  final String description;
  bool isGranted;

  DevicePermissionItem({
    required this.title,
    required this.permString,
    required this.description,
    required this.isGranted,
  });
}

class DeviceHealthPopover extends StatefulWidget {
  final VoidCallback? onClose;
  const DeviceHealthPopover({super.key, this.onClose});

  @override
  State<DeviceHealthPopover> createState() => _DeviceHealthPopoverState();
}

class _DeviceHealthPopoverState extends State<DeviceHealthPopover> {
  List<DevicePermissionItem> _permissions = [];
  bool _isLoading = true;
  bool _isAutoGranting = false;
  int _batteryLevel = 85;
  bool _isCharging = false;
  final String _adbTransport = "USB ADB";

  @override
  void initState() {
    super.initState();
    _fetchPermissionStatus();
  }

  Future<void> _fetchPermissionStatus() async {
    setState(() => _isLoading = true);
    try {
      final res = await http
          .get(Uri.parse('http://127.0.0.1:8080/permissions'))
          .timeout(const Duration(seconds: 2));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['permissions'] as List? ?? []).map((item) {
          return DevicePermissionItem(
            title: item['title'] ?? '',
            permString: item['perm'] ?? '',
            description: item['description'] ?? '',
            isGranted: item['is_granted'] == true,
          );
        }).toList();

        if (mounted) {
          setState(() {
            _permissions = list;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback: Check permission grants directly over ADB if HTTP endpoint is unavailable
    await _checkPermissionsViaAdb();
  }

  Future<void> _checkPermissionsViaAdb() async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      final result = await Process.run(adbPath,
          ['shell', 'dumpsys', 'package', 'com.androiddex.companion']);
      final stdout = result.stdout.toString();

      final hasContacts =
          stdout.contains('android.permission.READ_CONTACTS: granted=true');
      final hasCallLog =
          stdout.contains('android.permission.READ_CALL_LOG: granted=true');
      final hasPhone =
          stdout.contains('android.permission.CALL_PHONE: granted=true');
      final hasBtConnect =
          stdout.contains('android.permission.BLUETOOTH_CONNECT: granted=true');
      final hasBtScan =
          stdout.contains('android.permission.BLUETOOTH_SCAN: granted=true');
      final hasPhoneState =
          stdout.contains('android.permission.READ_PHONE_STATE: granted=true');
      final hasWriteContacts =
          stdout.contains('android.permission.WRITE_CONTACTS: granted=true');

      final notifResult = await Process.run(adbPath, [
        'shell',
        'settings',
        'get',
        'secure',
        'enabled_notification_listeners'
      ]);
      final hasNotif =
          notifResult.stdout.toString().contains('com.androiddex.companion');

      // Check battery level via ADB
      try {
        final battRes = await Process.run(adbPath, ['shell', 'dumpsys', 'battery']);
        final battOutput = battRes.stdout.toString();
        final levelMatch = RegExp(r'level:\s*(\d+)').firstMatch(battOutput);
        final statusMatch = RegExp(r'status:\s*(\d+)').firstMatch(battOutput);
        if (levelMatch != null) {
          _batteryLevel = int.tryParse(levelMatch.group(1)!) ?? 85;
        }
        if (statusMatch != null) {
          _isCharging = (int.tryParse(statusMatch.group(1)!) ?? 0) == 2;
        }
      } catch (_) {}

      final list = [
        DevicePermissionItem(
          title: "Bluetooth Connect",
          permString: "android.permission.BLUETOOTH_CONNECT",
          description: "Allows audio streaming & device connectivity",
          isGranted: hasBtConnect,
        ),
        DevicePermissionItem(
          title: "Bluetooth Scan",
          permString: "android.permission.BLUETOOTH_SCAN",
          description: "Scans for nearby wireless Dex peripherals",
          isGranted: hasBtScan,
        ),
        DevicePermissionItem(
          title: "Call Phone",
          permString: "android.permission.CALL_PHONE",
          description: "Initiates calls directly from desktop",
          isGranted: hasPhone,
        ),
        DevicePermissionItem(
          title: "Notification Listener",
          permString: "android.permission.BIND_NOTIFICATION_LISTENER_SERVICE",
          description: "Streams phone notifications to desktop taskbar",
          isGranted: hasNotif,
        ),
        DevicePermissionItem(
          title: "Read Call Log",
          permString: "android.permission.READ_CALL_LOG",
          description: "Displays recent call history in Phone app",
          isGranted: hasCallLog,
        ),
        DevicePermissionItem(
          title: "Read Contacts",
          permString: "android.permission.READ_CONTACTS",
          description: "Syncs phone contact list with desktop",
          isGranted: hasContacts,
        ),
        DevicePermissionItem(
          title: "Read Phone State",
          permString: "android.permission.READ_PHONE_STATE",
          description: "Detects incoming calls & network connectivity",
          isGranted: hasPhoneState,
        ),
        DevicePermissionItem(
          title: "Write Contacts",
          permString: "android.permission.WRITE_CONTACTS",
          description: "Allows adding & editing contacts from desktop",
          isGranted: hasWriteContacts,
        ),
      ];

      if (mounted) {
        setState(() {
          _permissions = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _togglePermission(DevicePermissionItem item, bool value) async {
    setState(() => item.isGranted = value);
    final adbPath = await AdbDeviceScanner.getAdbPath();
    const pkg = 'com.androiddex.companion';

    try {
      if (item.permString.contains('BIND_NOTIFICATION_LISTENER_SERVICE')) {
        final action = value ? 'enable' : 'disable';
        await Process.run(adbPath, [
          'shell',
          'cmd',
          'notification',
          'allow_listener',
          '$pkg/.service.DexNotificationListenerService',
          action
        ]);
      } else {
        final cmd = value ? 'grant' : 'revoke';
        await Process.run(adbPath, ['shell', 'pm', cmd, pkg, item.permString]);
      }
    } catch (e) {
      debugPrint("Error toggling permission: $e");
    }
  }

  Future<void> _autoGrantPermissions() async {
    setState(() => _isAutoGranting = true);
    final adbPath = await AdbDeviceScanner.getAdbPath();
    const pkg = 'com.androiddex.companion';

    for (final perm in _permissions) {
      if (!perm.isGranted) {
        try {
          if (perm.permString.contains('BIND_NOTIFICATION_LISTENER_SERVICE')) {
            await Process.run(adbPath, [
              'shell',
              'cmd',
              'notification',
              'allow_listener',
              '$pkg/.service.DexNotificationListenerService'
            ]);
          } else {
            await Process.run(
                adbPath, ['shell', 'pm', 'grant', pkg, perm.permString]);
          }
        } catch (_) {}
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));
    await _checkPermissionsViaAdb();

    if (mounted) {
      setState(() => _isAutoGranting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int total = _permissions.length;
    final int granted = _permissions.where((p) => p.isGranted).length;
    final double healthPercent = total == 0 ? 1.0 : (granted / total);

    final Color healthColor = healthPercent >= 0.85
        ? const Color(0xFF00BFA5)
        : (healthPercent >= 0.5 ? Colors.amberAccent : Colors.redAccent);

    return Container(
      width: 370,
      constraints: const BoxConstraints(maxHeight: 580),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: healthColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.monitor_heart_rounded,
                    color: healthColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Device Diagnostics",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white70, size: 18),
                onPressed: _fetchPermissionStatus,
              ),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 18),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Health Score Ring & Stats Summary Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                // Health Gauge Ring
                SizedBox(
                  width: 54,
                  height: 54,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: healthPercent,
                        strokeWidth: 5,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                      ),
                      Text(
                        "${(healthPercent * 100).toInt()}%",
                        style: TextStyle(
                          color: healthColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Device Metrics Summary
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$granted of $total Permissions Granted",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _isCharging
                                ? Icons.battery_charging_full_rounded
                                : Icons.battery_std_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$_batteryLevel%",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.usb_rounded,
                              color: Color(0xFF00BFA5), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _adbTransport,
                            style: const TextStyle(
                                color: Color(0xFF00BFA5), fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Auto Grant All Permissions Action Banner
          InkWell(
            onTap: _isAutoGranting ? null : _autoGrantPermissions,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isAutoGranting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  else
                    const Icon(Icons.auto_fix_high_rounded,
                        color: Colors.black, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    "Auto-Grant All Permissions",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Section Label
          const Text(
            "COMPANION PERMISSIONS",
            style: TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          // Interactive Permissions List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF00BFA5)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _permissions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _permissions[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: item.isGranted
                                    ? const Color(0xFF00BFA5).withValues(alpha: 0.2)
                                    : Colors.white10,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.isGranted
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: item.isGranted
                                    ? const Color(0xFF00BFA5)
                                    : Colors.redAccent,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (item.description.isNotEmpty)
                                    Text(
                                      item.description,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 9,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Switch(
                              value: item.isGranted,
                              activeTrackColor: const Color(0xFF00BFA5),
                              onChanged: (v) => _togglePermission(item, v),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
