import 'package:flutter/material.dart';
import '../models/device_state.dart';
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
  final List<RealNotificationItem> _dismissed = [];
  int _selectedTab = 0; // 0 = Notifications, 1 = Device Health

  Widget _buildAppIconWidget(String pkg) {
    return SmartAppIconWidget(
      packageName: pkg,
      size: 20,
      borderRadius: 10,
    );
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
                final activeNotifs = notifs.where((n) => !_dismissed.contains(n)).toList();

                for (final n in activeNotifs) {
                  if (AppLauncherService.getCachedIconUrl(n.packageName) == null) {
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
                                padding: const EdgeInsets.symmetric(vertical: 8),
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
                                padding: const EdgeInsets.symmetric(vertical: 8),
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
                                        onPressed: () {
                                          setState(() {
                                            _dismissed.addAll(activeNotifs);
                                          });
                                        },
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
                                                        item.appName.toUpperCase(),
                                                        style: const TextStyle(
                                                            color: Colors.white70,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold),
                                                      ),
                                                      const Spacer(),
                                                      Text(item.timestamp,
                                                          style: const TextStyle(
                                                              color:
                                                                  Colors.white38,
                                                              fontSize: 10)),
                                                      const SizedBox(width: 6),
                                                      InkWell(
                                                        onTap: () => setState(
                                                            () => _dismissed
                                                                .add(item)),
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
                                                  if (item.actions.isNotEmpty) ...[
                                                    const SizedBox(height: 10),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 6,
                                                      children: item.actions
                                                          .map((actText) {
                                                        return InkWell(
                                                          onTap: () {
                                                            ScaffoldMessenger.of(
                                                                    context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                    "Action '$actText' executed for ${item.appName}"),
                                                                duration:
                                                                    const Duration(
                                                                        seconds:
                                                                            2),
                                                                backgroundColor:
                                                                    const Color(
                                                                        0xFF00BFA5),
                                                              ),
                                                            );
                                                            AppLauncherService
                                                                .launchApp(item
                                                                    .packageName);
                                                          },
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical: 5),
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
                                                            child: Text(
                                                              actText,
                                                              style:
                                                                  const TextStyle(
                                                                color: Color(
                                                                    0xFF00BFA5),
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
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
