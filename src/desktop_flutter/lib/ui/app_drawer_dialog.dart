import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/device_state.dart';
import '../services/app_launcher_service.dart';
import 'smart_app_icon_widget.dart';

class SystemAppItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  SystemAppItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class AppDrawerDialog extends StatefulWidget {
  final bool isWindow;
  final DeviceState? deviceState;
  final VoidCallback? onStartBoot;
  final void Function(String packageName, String appName)? onLaunchAppWindow;

  const AppDrawerDialog({
    super.key,
    this.isWindow = false,
    this.deviceState,
    this.onStartBoot,
    this.onLaunchAppWindow,
  });

  @override
  State<AppDrawerDialog> createState() => _AppDrawerDialogState();
}

class _AppDrawerDialogState extends State<AppDrawerDialog> {
  List<InstalledApp> _userApps = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _activeCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final installed = await AppLauncherService.fetchInstalledApps();

    if (mounted) {
      setState(() {
        _userApps = installed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemApps = [
      SystemAppItem(
        title: "Mirroring",
        icon: Icons.screen_share_rounded,
        color: const Color(0xFF3B82F6),
        onTap: () {},
      ),
      SystemAppItem(
        title: "Audio",
        icon: Icons.volume_up_rounded,
        color: const Color(0xFF10B981),
        onTap: () {},
      ),
      SystemAppItem(
        title: "Call",
        icon: Icons.phone_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () {},
      ),
      SystemAppItem(
        title: "Contacts",
        icon: Icons.contacts_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () {},
      ),
      SystemAppItem(
        title: "Settings",
        icon: Icons.settings_rounded,
        color: const Color(0xFF64748B),
        onTap: () {},
      ),
      SystemAppItem(
        title: "Browser",
        icon: Icons.public_rounded,
        color: const Color(0xFF06B6D4),
        onTap: () {},
      ),
      SystemAppItem(
        title: "Camera",
        icon: Icons.camera_alt_rounded,
        color: const Color(0xFFEC4899),
        onTap: () {},
      ),
    ];

    final filteredUserApps = _userApps.where((a) {
      final q = _searchQuery.toLowerCase();
      return a.label.toLowerCase().contains(q) ||
          a.packageName.toLowerCase().contains(q);
    }).toList();

    final body = Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          // Top Header with Close & Filter Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildCategoryPill("All"),
                    const SizedBox(width: 8),
                    _buildCategoryPill("System"),
                    const SizedBox(width: 8),
                    _buildCategoryPill("User Apps"),
                  ],
                ),
                Row(
                  children: [
                    _buildIconSyncBadge(),
                    if (!widget.isWindow)
                      IconButton(
                        icon:
                            const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white10),

          // DISCONNECTED WATERMARK BANNER (if device is offline)
          if (widget.deviceState != null)
            ValueListenableBuilder<bool>(
              valueListenable: widget.deviceState!.isAdbConnected,
              builder: (context, isConnected, _) {
                if (isConnected) return const SizedBox.shrink();

                final devName =
                    widget.deviceState?.deviceName.value ?? 'Device';

                return Container(
                  width: double.infinity,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.amberAccent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.signal_cellular_off_rounded,
                          color: Colors.amberAccent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DEVICE DISCONNECTED: $devName",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const Text(
                              "Connect via USB or Wireless ADB to launch mobile applications.",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onStartBoot != null) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: widget.onStartBoot,
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text("Reconnect"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amberAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

          // Scrollable Content (System Apps + User Apps)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SYSTEM APPS SECTION
                  if (_activeCategory == 'All' ||
                      _activeCategory == 'System') ...[
                    const Text(
                      "SYSTEM APPS",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 95,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: systemApps.length,
                      itemBuilder: (context, index) {
                        final app = systemApps[index];
                        return _buildSquircleAppTile(
                          iconWidget: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: app.color,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: app.color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child:
                                Icon(app.icon, color: Colors.white, size: 26),
                          ),
                          label: app.title,
                          onTap: app.onTap,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // USER APPS SECTION
                  if (_activeCategory == 'All' ||
                      _activeCategory == 'User Apps') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "USER APPS",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          "${filteredUserApps.length} Apps",
                          style: const TextStyle(
                              color: Colors.white30, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF00BFA5),
                              ),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 95,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: filteredUserApps.length,
                            itemBuilder: (context, index) {
                              final app = filteredUserApps[index];
                              return _buildSquircleAppTile(
                                iconWidget: SmartAppIconWidget(
                                  packageName: app.packageName,
                                  size: 52,
                                  borderRadius: 16,
                                ),
                                label: app.label,
                                onTap: () {
                                  if (widget
                                          .deviceState?.isAdbConnected.value ==
                                      false) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "Cannot launch ${app.label}: Device is disconnected."),
                                        backgroundColor: Colors.amberAccent,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                    return;
                                  }
                                  AppLauncherService.launchApp(app.packageName);
                                  if (widget.onLaunchAppWindow != null) {
                                    widget.onLaunchAppWindow!(
                                        app.packageName, app.label);
                                  }
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ],
                ],
              ),
            ),
          ),

          // Floating Pill Search Bar at Bottom
          Container(
            margin: const EdgeInsets.all(16),
            width: 420,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                hintText: "Search apps...",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search_rounded, color: Colors.grey, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.isWindow) return body;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            width: 820,
            height: 650,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String label) {
    final isSelected = _activeCategory == label;
    return InkWell(
      onTap: () => setState(() => _activeCategory = label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00BFA5)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildIconSyncBadge() {
    return ValueListenableBuilder<AppIconSyncProgress>(
      valueListenable: AppLauncherService.iconSyncProgress,
      builder: (context, progress, _) {
        if (progress.totalApps == 0) return const SizedBox.shrink();

        final bool isDone = progress.isComplete;
        final color = isDone ? const Color(0xFF00BFA5) : Colors.amberAccent;
        final text = isDone
            ? "Icons Synced (${progress.syncedApps}/${progress.totalApps}) ✓"
            : "Syncing Icons (${progress.syncedApps}/${progress.totalApps})...";

        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDone) ...[
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
              ] else ...[
                Icon(Icons.check_circle_rounded, color: color, size: 12),
                const SizedBox(width: 4),
              ],
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSquircleAppTile({
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return _AnimatedAppTile(
      iconWidget: iconWidget,
      label: label,
      onTap: onTap,
    );
  }
}

class _AnimatedAppTile extends StatefulWidget {
  final Widget iconWidget;
  final String label;
  final VoidCallback onTap;

  const _AnimatedAppTile({
    required this.iconWidget,
    required this.label,
    required this.onTap,
  });

  @override
  State<_AnimatedAppTile> createState() => _AnimatedAppTileState();
}

class _AnimatedAppTileState extends State<_AnimatedAppTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double scale = _isPressed
        ? 0.92
        : (_isHovered
            ? 1.08
            : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isHovered
                    ? const Color(0xFF00BFA5).withValues(alpha: 0.4)
                    : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00BFA5)
                                  .withValues(alpha: 0.5),
                              blurRadius: 14,
                              spreadRadius: 2,
                            )
                          ]
                        : [],
                  ),
                  child: widget.iconWidget,
                ),
                const SizedBox(height: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: TextStyle(
                    color: _isHovered ? const Color(0xFF00BFA5) : Colors.white70,
                    fontSize: 11,
                    fontWeight: _isHovered ? FontWeight.bold : FontWeight.w500,
                    shadows: _isHovered
                        ? [
                            Shadow(
                              color: const Color(0xFF00BFA5)
                                  .withValues(alpha: 0.8),
                              blurRadius: 8,
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

