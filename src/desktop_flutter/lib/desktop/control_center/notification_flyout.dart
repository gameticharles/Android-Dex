import 'dart:io';
import 'package:flutter/material.dart';
import '../models/device_state.dart';
import '../services/adb_device_scanner.dart';
import '../services/app_launcher_service.dart';
import '../services/real_adb_sync_service.dart';
import 'smart_app_icon_widget.dart';

import 'device_health_popover.dart';

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
  int _selectedTab = 0; // 0 = Notifications, 1 = Device Health
  String? _replyingNotifId;
  final TextEditingController _replyController = TextEditingController();

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
      size: 20,
      borderRadius: 10,
    );
  }

  Future<void> _handleNotificationAction(
      RealNotificationItem item, String actText) async {
    final lowerAct = actText.toLowerCase();
    final adbPath = await AdbDeviceScanner.getAdbPath();

    // 1. Reply Action
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

    // 2. Media Controls (Play, Pause, Next, Prev, Skip, Mute)
    if (lowerAct.contains('play') || lowerAct.contains('pause')) {
      await Process.run(adbPath, ['shell', 'input', 'keyevent', '85']);
      _showActionToast("Play/Pause toggled");
      return;
    }

    if (lowerAct.contains('next') || lowerAct.contains('skip')) {
      await Process.run(adbPath, ['shell', 'input', 'keyevent', '87']);
      _showActionToast("Next track");
      return;
    }

    if (lowerAct.contains('prev') || lowerAct.contains('back')) {
      await Process.run(adbPath, ['shell', 'input', 'keyevent', '88']);
      _showActionToast("Previous track");
      return;
    }

    if (lowerAct.contains('mute')) {
      await Process.run(adbPath, ['shell', 'input', 'keyevent', '164']);
      _showActionToast("Volume Muted");
      return;
    }

    // 3. Call Actions
    if (lowerAct.contains('call') ||
        lowerAct.contains('answer') ||
        lowerAct.contains('accept')) {
      await Process.run(adbPath, ['shell', 'input', 'keyevent', '5']);
      _showActionToast("Call connected");
      return;
    }

    if (lowerAct.contains('decline') ||
        lowerAct.contains('reject') ||
        lowerAct.contains('hang')) {
      await Process.run(adbPath, ['shell', 'input', 'keyevent', '6']);
      setState(() => _dismissedKeys.add(_getNotifKey(item)));
      _showActionToast("Call declined");
      return;
    }

    // 4. Dismiss / Mark Read / Clear
    if (lowerAct.contains('dismiss') ||
        lowerAct.contains('mark as read') ||
        lowerAct.contains('archive') ||
        lowerAct.contains('clear')) {
      await _dismissNotificationOnDevice(item);
      _showActionToast("Notification dismissed");
      return;
    }

    // 5. Default: Open App
    _showActionToast("Opening ${item.appName}...");
    AppLauncherService.launchApp(item.packageName);
  }

  Future<void> _sendNotificationReply(RealNotificationItem item) async {
    final replyText = _replyController.text.trim();
    if (replyText.isEmpty) return;

    final adbPath = await AdbDeviceScanner.getAdbPath();

    try {
      await Process.run(adbPath, [
        'shell',
        'am',
        'startservice',
        '-n',
        'com.androiddex.companion/.InitializationService',
        '--es',
        'action',
        'reply',
        '--es',
        'pkg',
        item.packageName,
        '--es',
        'text',
        replyText
      ]);
    } catch (_) {}

    _showActionToast("Reply sent to ${item.title}: \"$replyText\"");

    setState(() {
      _replyingNotifId = null;
      _replyController.clear();
      _dismissedKeys.add(_getNotifKey(item));
    });
  }

  void _showActionToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Color(0xFF00BFA5), size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF00BFA5)),
        ),
      ),
    );
  }

  IconData _getActionIcon(String actText) {
    final lower = actText.toLowerCase();
    if (lower.contains('reply') ||
        lower.contains('message') ||
        lower.contains('send')) {
      return Icons.reply_rounded;
    }
    if (lower.contains('play')) return Icons.play_arrow_rounded;
    if (lower.contains('pause')) return Icons.pause_rounded;
    if (lower.contains('next') || lower.contains('skip')) {
      return Icons.skip_next_rounded;
    }
    if (lower.contains('prev') || lower.contains('back')) {
      return Icons.skip_previous_rounded;
    }
    if (lower.contains('mute')) return Icons.volume_off_rounded;
    if (lower.contains('call') ||
        lower.contains('answer') ||
        lower.contains('accept')) {
      return Icons.call_rounded;
    }
    if (lower.contains('decline') ||
        lower.contains('reject') ||
        lower.contains('hang')) {
      return Icons.call_end_rounded;
    }
    if (lower.contains('dismiss') ||
        lower.contains('clear') ||
        lower.contains('read') ||
        lower.contains('archive')) {
      return Icons.check_circle_outline_rounded;
    }
    return Icons.touch_app_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 520,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            spreadRadius: 2,
          )
        ],
      ),
      child: widget.deviceState != null
          ? ValueListenableBuilder<List<RealNotificationItem>>(
              valueListenable: widget.deviceState!.notifications,
              builder: (context, notifs, _) {
                final activeNotifs = notifs
                    .where((n) => !_dismissedKeys.contains(_getNotifKey(n)))
                    .toList();

                for (final n in activeNotifs) {
                  if (AppLauncherService.getCachedIconUrl(n.packageName) ==
                      null) {
                    AppLauncherService.getIconUrlForPackage(n.packageName);
                  }
                }

                return Column(
                  children: [
                    // Segmented Header Tab Switcher
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 0),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 0
                                      ? const Color(0xFF00BFA5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_rounded,
                                      size: 16,
                                      color: _selectedTab == 0
                                          ? Colors.white
                                          : Colors.white54,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Notifications",
                                      style: TextStyle(
                                        color: _selectedTab == 0
                                            ? Colors.white
                                            : Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (activeNotifs.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _selectedTab == 0
                                              ? Colors.black26
                                              : const Color(0xFF00BFA5)
                                                  .withValues(alpha: 0.3),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          "${activeNotifs.length}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 1),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 1
                                      ? const Color(0xFF00BFA5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 16,
                                      color: _selectedTab == 1
                                          ? Colors.white
                                          : Colors.white54,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Device Health",
                                      style: TextStyle(
                                        color: _selectedTab == 1
                                            ? Colors.white
                                            : Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tab 0: Notifications View | Tab 1: Device Health View
                    Expanded(
                      child: _selectedTab == 1
                          ? DeviceHealthPopover(
                              onClose: widget.onClose,
                            )
                          : Column(
                              children: [
                                if (activeNotifs.isNotEmpty)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _clearAllNotificationsOnDevice(
                                                activeNotifs),
                                        child: const Text("Clear all",
                                            style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                Expanded(
                                  child: activeNotifs.isEmpty
                                      ? const Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                  Icons
                                                      .notifications_off_outlined,
                                                  color: Colors.white24,
                                                  size: 48),
                                              SizedBox(height: 12),
                                              Text("No active notifications",
                                                  style: TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 13)),
                                            ],
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: activeNotifs.length,
                                          itemBuilder: (context, index) {
                                            final item = activeNotifs[index];
                                            final isReplying =
                                                _replyingNotifId == item.id;

                                            return Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 12),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1E293B)
                                                    .withValues(alpha: 0.7),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color: Colors.white10),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      _buildAppIconWidget(
                                                          item.packageName),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        item.appName
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white70,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                      ),
                                                      const Spacer(),
                                                      Text(item.timestamp,
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .white38,
                                                              fontSize: 10)),
                                                      const SizedBox(width: 6),
                                                      InkWell(
                                                        onTap: () =>
                                                            _dismissNotificationOnDevice(
                                                                item),
                                                        child: const Icon(
                                                            Icons.close_rounded,
                                                            color:
                                                                Colors.white38,
                                                            size: 14),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    item.title,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.body,
                                                    style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 11),
                                                    maxLines: 3,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  if (item
                                                      .actions.isNotEmpty) ...[
                                                    const SizedBox(height: 10),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 6,
                                                      children: item.actions
                                                          .map((actText) {
                                                        final iconData =
                                                            _getActionIcon(
                                                                actText);

                                                        return InkWell(
                                                          onTap: () =>
                                                              _handleNotificationAction(
                                                                  item,
                                                                  actText),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical:
                                                                        6),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: const Color(
                                                                      0xFF00BFA5)
                                                                  .withValues(
                                                                      alpha:
                                                                          0.15),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                              border: Border.all(
                                                                  color: const Color(
                                                                          0xFF00BFA5)
                                                                      .withValues(
                                                                          alpha:
                                                                              0.4)),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                  iconData,
                                                                  size: 13,
                                                                  color: const Color(
                                                                      0xFF00BFA5),
                                                                ),
                                                                const SizedBox(
                                                                    width: 5),
                                                                Text(
                                                                  actText,
                                                                  style:
                                                                      const TextStyle(
                                                                    color: Color(
                                                                        0xFF00BFA5),
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ],
                                                  if (isReplying) ...[
                                                    const SizedBox(height: 10),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              6),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFF0F172A),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14),
                                                        border: Border.all(
                                                            color: const Color(
                                                                    0xFF00BFA5)
                                                                .withValues(
                                                                    alpha:
                                                                        0.5)),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: TextField(
                                                              controller:
                                                                  _replyController,
                                                              autofocus: true,
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 12),
                                                              decoration:
                                                                  const InputDecoration(
                                                                hintText:
                                                                    "Type reply message...",
                                                                hintStyle: TextStyle(
                                                                    color: Colors
                                                                        .white38,
                                                                    fontSize:
                                                                        12),
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                                isDense: true,
                                                                contentPadding:
                                                                    EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            6),
                                                              ),
                                                              onSubmitted: (_) =>
                                                                  _sendNotificationReply(
                                                                      item),
                                                            ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                                Icons
                                                                    .send_rounded,
                                                                color: Color(
                                                                    0xFF00BFA5),
                                                                size: 18),
                                                            tooltip:
                                                                "Send Reply",
                                                            onPressed: () =>
                                                                _sendNotificationReply(
                                                                    item),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(
                                                                Icons.close,
                                                                color: Colors
                                                                    .white38,
                                                                size: 16),
                                                            tooltip:
                                                                "Cancel Reply",
                                                            onPressed: () {
                                                              setState(() {
                                                                _replyingNotifId =
                                                                    null;
                                                                _replyController
                                                                    .clear();
                                                              });
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            )
          : const SizedBox.shrink(),
    );
  }
}
