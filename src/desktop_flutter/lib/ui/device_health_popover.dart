import 'dart:io';
import 'package:flutter/material.dart';
import '../services/adb_device_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DevicePermissionItem {
  final String title;
  final String description;
  final bool isGranted;

  DevicePermissionItem({
    required this.title,
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

      final list = [
        DevicePermissionItem(
            title: "Bluetooth Connect",
            description: "",
            isGranted: hasBtConnect),
        DevicePermissionItem(
            title: "Bluetooth Scan", description: "", isGranted: hasBtScan),
        DevicePermissionItem(
            title: "Call Phone", description: "", isGranted: hasPhone),
        DevicePermissionItem(
            title: "Notification Listener",
            description: "",
            isGranted: hasNotif),
        DevicePermissionItem(
            title: "Read Call Log", description: "", isGranted: hasCallLog),
        DevicePermissionItem(
            title: "Read Contacts", description: "", isGranted: hasContacts),
        DevicePermissionItem(
            title: "Read Phone State",
            description: "",
            isGranted: hasPhoneState),
        DevicePermissionItem(
            title: "Write Contacts",
            description: "",
            isGranted: hasWriteContacts),
        DevicePermissionItem(
            title: "Battery Optimization", description: "", isGranted: true),
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

  Future<void> _autoGrantPermissions() async {
    setState(() => _isAutoGranting = true);
    final adbPath = await AdbDeviceScanner.getAdbPath();
    const pkg = 'com.androiddex.companion';

    final runtimePerms = [
      'android.permission.READ_CONTACTS',
      'android.permission.WRITE_CONTACTS',
      'android.permission.READ_CALL_LOG',
      'android.permission.CALL_PHONE',
      'android.permission.READ_PHONE_STATE',
      'android.permission.READ_SMS',
      'android.permission.SEND_SMS',
      'android.permission.BLUETOOTH_CONNECT',
      'android.permission.BLUETOOTH_SCAN',
    ];

    for (final perm in runtimePerms) {
      try {
        await Process.run(adbPath, ['shell', 'pm', 'grant', pkg, perm]);
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Auto-granted runtime permissions over ADB!"),
          backgroundColor: Color(0xFF00BFA5),
        ),
      );
      await _fetchPermissionStatus();
      setState(() => _isAutoGranting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missingCount = _permissions.where((p) => !p.isGranted).length;

    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            spreadRadius: 4,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.orangeAccent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Device Health",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    Text(
                      missingCount > 0
                          ? "$missingCount permissions are missing"
                          : "All permissions granted ✓",
                      style: TextStyle(
                          color: missingCount > 0
                              ? Colors.white60
                              : const Color(0xFF00BFA5),
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 18),
                  onPressed: widget.onClose,
                ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Permissions List
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF00BFA5)),
                  ),
                )
              : Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: _permissions.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              Icon(
                                item.isGranted
                                    ? Icons.check_rounded
                                    : Icons.close_rounded,
                                color: item.isGranted
                                    ? const Color(0xFF10B981)
                                    : Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.isGranted
                                      ? Colors.transparent
                                      : Colors.redAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.isGranted ? "" : "MISSING",
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isAutoGranting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_rounded,
                      color: Colors.white, size: 16),
              label: Text(
                _isAutoGranting
                    ? "Granting over ADB..."
                    : "Auto-Grant Permissions",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              onPressed: _isAutoGranting ? null : _autoGrantPermissions,
            ),
          ),
        ],
      ),
    );
  }
}
