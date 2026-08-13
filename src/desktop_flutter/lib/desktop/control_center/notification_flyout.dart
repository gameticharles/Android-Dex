import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
  final void Function(String packageName, String appName)? onLaunchAppWindow;

  const NotificationFlyout({
    super.key,
    this.deviceState,
    this.onClose,
    this.onLaunchAppWindow,
  });

  @override
  State<NotificationFlyout> createState() => _NotificationFlyoutState();
}

class _NotificationFlyoutState extends State<NotificationFlyout> {
  final Set<String> _dismissedKeys = {};
  final Set<String> _mutedApps = {};
  final Set<String> _pinnedKeys = {};
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
      size: 18,
      borderRadius: 9,
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

    if (lowerAct.contains('mute')) {
      setState(() => _mutedApps.add(item.packageName));
      return;
    }

    if (widget.onLaunchAppWindow != null) {
      widget.onLaunchAppWindow!(item.packageName, item.appName);
    } else {
      AppLauncherService.launchApp(item.packageName);
    }
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

  void _openImagePreviewDialog(BuildContext context, ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image(
                image: imageProvider,
                fit: BoxFit.contain,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
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
        final activeNotifs = (notifs.isEmpty
                ? [
                    RealNotificationItem(
                      id: 'ref_weather',
                      packageName: 'com.google.android.apps.weather',
                      appName: 'WEATHER',
                      title: '75° Kumasi',
                      body: 'Storms possible this morning',
                      subText: 'High 86° | Low 73°',
                      timestamp: '10m ago',
                      imageUrl:
                          'https://images.unsplash.com/photo-1592210454359-9043f067919b?w=200&auto=format&fit=crop&q=80',
                      actions: const [],
                    ),
                    RealNotificationItem(
                      id: 'ref_facebook_live',
                      packageName: 'com.facebook.katana',
                      appName: 'FACEBOOK',
                      title: 'Citi 97.3 FM',
                      body:
                          'You, Nana and 15 other friends follow this creator. Check out their live video.',
                      timestamp: '15m ago',
                      imageUrl:
                          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=200&auto=format&fit=crop&q=80',
                      actions: const ['View video'],
                    ),
                    RealNotificationItem(
                      id: 'ref_whatsapp_photo',
                      packageName: 'com.whatsapp',
                      appName: 'WHATSAPP',
                      title: 'WhatsApp',
                      body:
                          '~ Betty Amissah @ 2025 CoE Senior Members Retreat: 📷 Photo',
                      timestamp: '30m ago',
                      actions: const ['Reply', 'Mark as read'],
                    ),
                    RealNotificationItem(
                      id: 'ref_whatsapp_sticker',
                      packageName: 'com.whatsapp',
                      appName: 'WHATSAPP',
                      title: 'YELF (355 messages): ~ Masi-Jo...',
                      body: '💜 Sticker',
                      timestamp: '1h ago',
                      imageUrl:
                          'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=200&auto=format&fit=crop&q=80',
                      actions: const ['Reply', 'Mark as read', 'Mute'],
                    ),
                    RealNotificationItem(
                      id: 'ref_whatsapp_lsd',
                      packageName: 'com.whatsapp',
                      appName: 'WHATSAPP',
                      title: 'LSD-YSN Platform (3 messages):...',
                      body:
                          '📣 ANNOUNCEMENT 📣 Young Surveyors Network Mentor-M...',
                      timestamp: '2h ago',
                      imageUrl:
                          'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=200&auto=format&fit=crop&q=80',
                      actions: const ['Reply', 'Mark as read', 'Mute'],
                    ),
                    RealNotificationItem(
                      id: 'ref_facebook_friend',
                      packageName: 'com.facebook.katana',
                      appName: 'FACEBOOK',
                      title: 'Facebook',
                      body:
                          'Rein Gameti Charles, you have a new friend suggestion: Âmâh Gîfty',
                      timestamp: '3h ago',
                      imageUrl:
                          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
                      actions: const ['Add Friend', 'View profile'],
                    ),
                  ]
                : notifs)
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
                        return _buildReferenceStyleNotificationCard(context, item);
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

  // High-fidelity Reference Card matching user reference images
  Widget _buildReferenceStyleNotificationCard(
      BuildContext context, RealNotificationItem item) {
    final isReplying = _replyingNotifId == item.id;
    final String key = _getNotifKey(item);
    final bool isPinned = _pinnedKeys.contains(key);

    // Determine Image Provider
    ImageProvider? thumbnailProvider;
    if (item.imageDataBase64 != null && item.imageDataBase64!.isNotEmpty) {
      try {
        final cleanBase64 =
            item.imageDataBase64!.replaceAll(RegExp(r'^data:image\/[a-z]+;base64,'), '');
        final Uint8List bytes = base64Decode(cleanBase64);
        thumbnailProvider = MemoryImage(bytes);
      } catch (_) {}
    } else if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      thumbnailProvider = NetworkImage(item.imageUrl!);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPinned
            ? const Color(0xFF2A1F3B)
            : Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPinned
              ? const Color(0xFF00BFA5).withValues(alpha: 0.6)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: App Icon + UPPERCASE App Name + Three-Dot ⋮ Context Menu
          Row(
            children: [
              _buildAppIconWidget(item.packageName),
              const SizedBox(width: 8),
              Text(
                item.appName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),

              // Three-Dot ⋮ Context Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: Colors.white54, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 140),
                color: const Color(0xFF2A1F3B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (choice) {
                  if (choice == 'pin') {
                    setState(() {
                      if (isPinned) {
                        _pinnedKeys.remove(key);
                      } else {
                        _pinnedKeys.add(key);
                      }
                    });
                  } else if (choice == 'mute') {
                    setState(() => _mutedApps.add(item.packageName));
                  } else if (choice == 'mirror') {
                    if (widget.onLaunchAppWindow != null) {
                      widget.onLaunchAppWindow!(item.packageName, item.appName);
                    } else {
                      AppLauncherService.launchApp(item.packageName);
                    }
                  } else if (choice == 'dismiss') {
                    _dismissNotificationOnDevice(item);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        Icon(
                            isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin_rounded,
                            color: Colors.white70,
                            size: 14),
                        const SizedBox(width: 8),
                        Text(
                          isPinned ? "Unpin" : "Pin to Top",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'mute',
                    child: Row(
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            color: Colors.white70, size: 14),
                        SizedBox(width: 8),
                        Text("Mute App",
                            style:
                                TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'mirror',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            color: Colors.white70, size: 14),
                        SizedBox(width: 8),
                        Text("Launch App",
                            style:
                                TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'dismiss',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent, size: 14),
                        SizedBox(width: 8),
                        Text("Dismiss",
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Content Area: Left Column (Text) + Right Column (Image Thumbnail)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Title + Body Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subText,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Right Column: Image Thumbnail (if present)
              if (thumbnailProvider != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _openImagePreviewDialog(context, thumbnailProvider!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Image(
                        image: thumbnailProvider,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.image_rounded,
                              color: Colors.white38, size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Pill-Shaped Action Buttons Row matching reference image
          if (item.actions.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: item.actions.map((actText) {
                final isReplyBtn = actText.toLowerCase().contains('reply');
                return InkWell(
                  onTap: () => _handleNotificationAction(item, actText),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isReplyBtn
                          ? Colors.white.withValues(alpha: 0.30)
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      actText,
                      style: TextStyle(
                        color: isReplyBtn
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.90),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          // Direct Inline Reply Panel
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
