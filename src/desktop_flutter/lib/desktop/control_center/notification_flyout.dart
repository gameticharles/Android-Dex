import 'dart:io';
import 'package:flutter/material.dart';
import 'package:adb_device_manager/core/models/device_state.dart';
import 'package:adb_device_manager/core/adb/adb_device_scanner.dart';
import 'package:adb_device_manager/features/app_mirror/services/app_launcher_service.dart';
import 'package:adb_device_manager/core/adb/real_adb_sync_service.dart';
import 'package:adb_device_manager/desktop/taskbar/smart_app_icon_widget.dart';
import 'package:adb_device_manager/desktop/control_center/device_health_popover.dart';

class NotificationFlyoutItem {
  final String category;
  final String title;
  final String body;
  final String? actionText;
  final IconData icon;
  final Color iconColor;

  NotificationFlyoutItem({
    required this.category,
    required this.title,
    required this.body,
    this.actionText,
    required this.icon,
    required this.iconColor,
  });
}

class NotificationFlyout extends StatefulWidget {
  final DeviceState? deviceState;
  final VoidCallback? onClose;

  const NotificationFlyout({super.key, this.deviceState, this.onClose});

  @override
  State<NotificationFlyout> createState() => _NotificationFlyoutState();
}

class _NotificationFlyoutState extends State<NotificationFlyout> {
  final Set<String> _dismissedKeys = {};
  final Set<String> _mutedApps = {};
  int _selectedTab = 0; // 0 = Live Notifications, 1 = Device Health
  String _activeFilterCategory = "All";

  String? _replyingNotifId;
  final TextEditingController _replyController = TextEditingController();

  final List<String> _cannedReplies = const [
    "On my way! 🏃‍♂️",
    "Thanks! 👍",
    "Call you later 📞",
    "Got it 👌",
  ];

  String _getNotifKey(RealNotificationItem n) =>
      "${n.packageName}_${n.title}_${n.body}";

  Future<void> _dismissNotificationOnDevice(RealNotificationItem item) async {
    setState(() => _dismissedKeys.add(_getNotifKey(item)));
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      await Future.wait([
        Process.run(adbPath, [
          'shell',
          'am',
          'startservice',
          '-n',
          'com.androiddex.companion/.service.DexNotificationListenerService',
          '--es',
          'action',
          'cancel',
          '--es',
          'pkg',
          item.packageName
        ]),
        Process.run(adbPath, [
          'shell',
          'am',
          'broadcast',
          '-a',
          'com.androiddex.companion.CANCEL_PACKAGE',
          '--es',
          'pkg',
          item.packageName
        ]),
        Process.run(adbPath,
            ['shell', 'cmd', 'notification', 'cancel', item.packageName]),
      ]);
    } catch (e) {
      debugPrint("Dismiss notification ADB error: $e");
    }
  }

  Future<void> _clearAllNotificationsOnDevice(
      List<RealNotificationItem> activeNotifs) async {
    setState(() {
      for (final n in activeNotifs) {
        _dismissedKeys.add(_getNotifKey(n));
      }
    });
    if (widget.deviceState != null) {
      widget.deviceState!.notifications.value = [];
    }
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      await Future.wait([
        Process.run(adbPath, [
          'shell',
          'am',
          'startservice',
          '-n',
          'com.androiddex.companion/.service.DexNotificationListenerService',
          '--es',
          'action',
          'cancel_all'
        ]),
        Process.run(adbPath, [
          'shell',
          'am',
          'broadcast',
          '-a',
          'com.androiddex.companion.CANCEL_ALL'
        ]),
        Process.run(adbPath, ['shell', 'cmd', 'notification', 'cancel_all']),
      ]);
    } catch (e) {
      debugPrint("Cancel all ADB error: $e");
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Widget _buildAppIconWidget(String pkg) {
    return SmartAppIconWidget(
      packageName: pkg,
      size: 22,
      borderRadius: 11,
    );
  }

  Future<void> _handleNotificationAction(
      RealNotificationItem item, String actText) async {
    final lowerAct = actText.toLowerCase();

    if (lowerAct.contains('reply') ||
        lowerAct.contains('message') ||
        lowerAct.contains('send')) {
      setState(() {
        if (_replyingNotifId == item.id) {
          _replyingNotifId = null;
        } else {
          _replyingNotifId = item.id;
          _replyController.clear();
        }
      });
      return;
    }

    if (lowerAct.contains('mark as read') || lowerAct.contains('dismiss')) {
      _dismissNotificationOnDevice(item);
      return;
    }

    AppLauncherService.launchApp(item.packageName);
  }

  Future<void> _sendDirectReply(
      RealNotificationItem item, String replyText) async {
    if (replyText.trim().isEmpty) return;
    final text = replyText.trim();
    setState(() => _replyingNotifId = null);

    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      await Process.run(adbPath, [
        'shell',
        'am',
        'startservice',
        '-n',
        'com.androiddex.companion/.service.DexNotificationListenerService',
        '--es',
        'action',
        'reply',
        '--es',
        'pkg',
        item.packageName,
        '--es',
        'message',
        text
      ]);
    } catch (e) {
      debugPrint("Direct reply error: $e");
    }
  }

  bool _matchesCategoryFilter(RealNotificationItem item) {
    if (_mutedApps.contains(item.packageName)) return false;
    if (_activeFilterCategory == "All") return true;

    final pkg = item.packageName.toLowerCase();
    final title = item.title.toLowerCase();

    if (_activeFilterCategory == "Messages") {
      return pkg.contains('whatsapp') ||
          pkg.contains('sms') ||
          pkg.contains('telecel') ||
          pkg.contains('messaging') ||
          pkg.contains('telegram');
    }
    if (_activeFilterCategory == "Calls") {
      return pkg.contains('phone') ||
          pkg.contains('dialer') ||
          title.contains('call');
    }
    if (_activeFilterCategory == "System") {
      return pkg.contains('android') || pkg.contains('system');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      constraints: const BoxConstraints(maxHeight: 600),
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
          // Header Row with Tab Toggle & Close Button
          Row(
            children: [
              _buildTabButton(
                  0, "Live Notifications", Icons.notifications_rounded),
              const SizedBox(width: 8),
              _buildTabButton(1, "Health", Icons.monitor_heart_rounded),
              const Spacer(),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white70, size: 18),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Render Selected Tab View
          Expanded(
            child: _selectedTab == 1
                ? DeviceHealthPopover(onClose: widget.onClose)
                : _buildNotificationsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00BFA5) : Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? Colors.black : Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return ValueListenableBuilder<List<RealNotificationItem>>(
      valueListenable: widget.deviceState?.notifications ??
          ValueNotifier<List<RealNotificationItem>>([]),
      builder: (context, notifs, _) {
        final activeNotifs = notifs
            .where((n) =>
                !_dismissedKeys.contains(_getNotifKey(n)) &&
                _matchesCategoryFilter(n))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Chips Bar & Clear All Action
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: const ["All", "Messages", "Calls", "System"]
                          .map((cat) => _buildFilterChip(cat))
                          .toList(),
                    ),
                  ),
                ),
                if (activeNotifs.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        _clearAllNotificationsOnDevice(activeNotifs),
                    child: const Text("Clear All",
                        style:
                            TextStyle(color: Colors.redAccent, fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Active Notifications Scroll List
            Expanded(
              child: activeNotifs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_rounded,
                              color: Colors.white24, size: 42),
                          SizedBox(height: 8),
                          Text(
                            "No active notifications",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: activeNotifs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = activeNotifs[index];
                        return _buildNotificationCard(item);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String category) {
    final isSelected = _activeFilterCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        selectedColor: const Color(0xFF00BFA5),
        showCheckmark: false,
        onSelected: (_) => setState(() => _activeFilterCategory = category),
      ),
    );
  }

  Widget _buildNotificationCard(RealNotificationItem item) {
    final isReplying = _replyingNotifId == item.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Title Bar
          Row(
            children: [
              _buildAppIconWidget(item.packageName),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.appName,
                  style: const TextStyle(
                    color: Color(0xFF00BFA5),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_off_outlined,
                    color: Colors.white38, size: 14),
                tooltip: "Mute app",
                onPressed: () =>
                    setState(() => _mutedApps.add(item.packageName)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white38, size: 16),
                onPressed: () => _dismissNotificationOnDevice(item),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Message Title & Body
          Text(
            item.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.body,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Notification Actions Buttons
          if (item.actions.isNotEmpty)
            Wrap(
              spacing: 6,
              children: item.actions.map((actText) {
                return InkWell(
                  onTap: () => _handleNotificationAction(item, actText),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      actText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),

          // Direct Inline Reply Input Panel
          if (isReplying) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: "Type reply...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.12),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (text) => _sendDirectReply(item, text),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send_rounded,
                      color: Color(0xFF00BFA5), size: 20),
                  onPressed: () =>
                      _sendDirectReply(item, _replyController.text),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Canned Reply Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _cannedReplies.map((rText) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _sendDirectReply(item, rText),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF00BFA5).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          rText,
                          style: const TextStyle(
                              color: Color(0xFF00BFA5), fontSize: 10),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
