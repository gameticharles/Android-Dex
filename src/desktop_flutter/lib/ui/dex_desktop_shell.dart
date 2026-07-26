import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../models/device_state.dart';
import '../services/app_launcher_service.dart';
import '../services/clipboard_sync_service.dart';
import '../services/mirror_service.dart';
import '../services/real_adb_sync_service.dart';
import '../services/call_state_service.dart';
import 'app_drawer_dialog.dart';
import 'app_mirror_stream_widget.dart';
import 'battery_popover.dart';
import 'device_health_popover.dart';
import 'file_manager_dialog.dart';
import 'incoming_call_banner.dart';
import 'notification_flyout.dart';
import 'media_player_widget.dart';
import 'quick_settings_popover.dart';
import 'smart_app_icon_widget.dart';
import 'smart_taskbar_popover_button.dart';
import 'sms_dialog.dart';
import 'unified_phone_dialog.dart';
import 'wireless_adb_dialog.dart';
import 'dex_settings_dialog.dart';
import '../services/dex_settings_service.dart';
import '../services/adb_device_scanner.dart';

import 'desktop_window_widget.dart';

enum TaskbarPopoverType {
  none,
  media,
  notifications,
  battery,
  settings,
  health
}

enum WindowSnapZone {
  none,
  leftHalf,
  rightHalf,
  topMaximize,
  topLeftQuarter,
  topRightQuarter,
  bottomLeftQuarter,
  bottomRightQuarter,
}

class DesktopWindowData {
  final String id;
  final String title;
  final IconData icon;
  final Color themeColor;
  final Widget content;
  Offset position;
  Size size;
  Size? preMaximizedSize;
  Offset? preMaximizedPosition;
  bool isMinimized;
  bool isMaximized;
  int zIndex;

  DesktopWindowData({
    required this.id,
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.content,
    required this.position,
    required this.size,
    this.isMinimized = false,
    this.isMaximized = false,
    this.zIndex = 0,
  });
}

class DexDesktopShell extends StatefulWidget {
  final DeviceState deviceState;
  final VoidCallback onStartBoot;

  const DexDesktopShell({
    super.key,
    required this.deviceState,
    required this.onStartBoot,
  });

  @override
  State<DexDesktopShell> createState() => _DexDesktopShellState();
}

class _DexDesktopShellState extends State<DexDesktopShell> {
  late Timer _clockTimer;
  DateTime _now = DateTime.now();
  bool _isPlaying = false;
  bool _isFullScreen = false;
  bool _isDexLocked = false;
  TaskbarPopoverType _activePopover = TaskbarPopoverType.none;

  // Desktop Windowing State
  final List<DesktopWindowData> _openWindows = [];
  int _highestZIndex = 0;

  // Intelligent Window Snapping State
  WindowSnapZone _activeSnapZone = WindowSnapZone.none;

  WindowSnapZone _detectSnapZone(Offset globalPos, Size screenSize) {
    const double edgeThreshold = 28.0;
    const double cornerThreshold = 48.0;
    final double workHeight = screenSize.height - 75;
    final double workWidth = screenSize.width;

    // Corner Snapping Check
    if (globalPos.dx <= cornerThreshold && globalPos.dy <= cornerThreshold) {
      return WindowSnapZone.topLeftQuarter;
    }
    if (globalPos.dx >= workWidth - cornerThreshold &&
        globalPos.dy <= cornerThreshold) {
      return WindowSnapZone.topRightQuarter;
    }
    if (globalPos.dx <= cornerThreshold &&
        globalPos.dy >= workHeight - cornerThreshold) {
      return WindowSnapZone.bottomLeftQuarter;
    }
    if (globalPos.dx >= workWidth - cornerThreshold &&
        globalPos.dy >= workHeight - cornerThreshold) {
      return WindowSnapZone.bottomRightQuarter;
    }

    // Edge Snapping Check
    if (globalPos.dx <= edgeThreshold) {
      return WindowSnapZone.leftHalf;
    }
    if (globalPos.dx >= workWidth - edgeThreshold) {
      return WindowSnapZone.rightHalf;
    }
    if (globalPos.dy <= edgeThreshold) {
      return WindowSnapZone.topMaximize;
    }

    return WindowSnapZone.none;
  }

  Rect? _getSnapTargetRect(WindowSnapZone zone, Size screenSize) {
    final double workHeight = screenSize.height - 75;
    final double workWidth = screenSize.width;

    switch (zone) {
      case WindowSnapZone.leftHalf:
        return Rect.fromLTWH(0, 0, workWidth / 2, workHeight);
      case WindowSnapZone.rightHalf:
        return Rect.fromLTWH(workWidth / 2, 0, workWidth / 2, workHeight);
      case WindowSnapZone.topMaximize:
        return Rect.fromLTWH(0, 0, workWidth, workHeight);
      case WindowSnapZone.topLeftQuarter:
        return Rect.fromLTWH(0, 0, workWidth / 2, workHeight / 2);
      case WindowSnapZone.topRightQuarter:
        return Rect.fromLTWH(workWidth / 2, 0, workWidth / 2, workHeight / 2);
      case WindowSnapZone.bottomLeftQuarter:
        return Rect.fromLTWH(0, workHeight / 2, workWidth / 2, workHeight / 2);
      case WindowSnapZone.bottomRightQuarter:
        return Rect.fromLTWH(
            workWidth / 2, workHeight / 2, workWidth / 2, workHeight / 2);
      case WindowSnapZone.none:
        return null;
    }
  }

  String _getSnapLabel(WindowSnapZone zone) {
    switch (zone) {
      case WindowSnapZone.leftHalf:
        return "Snap Left (50%)";
      case WindowSnapZone.rightHalf:
        return "Snap Right (50%)";
      case WindowSnapZone.topMaximize:
        return "Maximize Window";
      case WindowSnapZone.topLeftQuarter:
        return "Snap Top-Left (25%)";
      case WindowSnapZone.topRightQuarter:
        return "Snap Top-Right (25%)";
      case WindowSnapZone.bottomLeftQuarter:
        return "Snap Bottom-Left (25%)";
      case WindowSnapZone.bottomRightQuarter:
        return "Snap Bottom-Right (25%)";
      case WindowSnapZone.none:
        return "";
    }
  }

  void _handleWindowDrag(
      DesktopWindowData win, Offset delta, Offset globalPos, Size screenSize) {
    setState(() {
      if (win.isMaximized) {
        win.isMaximized = false;
        if (win.preMaximizedSize != null) {
          win.size = win.preMaximizedSize!;
        }
      }

      win.position += delta;
      _activeSnapZone = _detectSnapZone(globalPos, screenSize);
    });
  }

  void _handleWindowDragEnd(
      DesktopWindowData win, Offset globalPos, Size screenSize) {
    final snapZone = _activeSnapZone;
    setState(() {
      _activeSnapZone = WindowSnapZone.none;

      if (snapZone == WindowSnapZone.topMaximize) {
        _maximizeWindow(win.id);
      } else if (snapZone != WindowSnapZone.none) {
        final targetRect = _getSnapTargetRect(snapZone, screenSize);
        if (targetRect != null) {
          win.preMaximizedPosition = win.position;
          win.preMaximizedSize = win.size;
          win.position = targetRect.topLeft;
          win.size = targetRect.size;
        }
      }
    });
  }

  // Real-Time Connection Toast State
  String? _connectionToastMessage;
  bool _isConnectionToastError = false;
  bool _lastConnectedState = true;

  @override
  void initState() {
    super.initState();
    try {
      windowManager.isFullScreen().then((isFS) {
        if (mounted) setState(() => _isFullScreen = isFS);
      }).catchError((_) {});
    } catch (_) {}

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    ClipboardSyncService.startSync();
    CallStateService.startSync();

    _lastConnectedState = widget.deviceState.isAdbConnected.value;
    widget.deviceState.isAdbConnected.addListener(_onDeviceConnectionChanged);
  }

  @override
  void dispose() {
    CallStateService.stopSync();
    ClipboardSyncService.stopSync();
    widget.deviceState.isAdbConnected
        .removeListener(_onDeviceConnectionChanged);
    _clockTimer.cancel();
    super.dispose();
  }

  void _onDeviceConnectionChanged() {
    final isConn = widget.deviceState.isAdbConnected.value;
    if (_lastConnectedState != isConn) {
      _lastConnectedState = isConn;
      final devName = widget.deviceState.deviceName.value;

      setState(() {
        if (!isConn) {
          _connectionToastMessage = "⚠️ Device Disconnected: $devName";
          _isConnectionToastError = true;
        } else {
          _connectionToastMessage = "✓ Device Connected: $devName";
          _isConnectionToastError = false;
        }
      });

      if (isConn) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && widget.deviceState.isAdbConnected.value) {
            setState(() => _connectionToastMessage = null);
          }
        });
      }
    }
  }

  void _togglePopover(TaskbarPopoverType type) {
    setState(() {
      if (_activePopover == type) {
        _activePopover = TaskbarPopoverType.none;
      } else {
        _activePopover = type;
      }
    });
  }

  Future<void> _toggleFullScreen() async {
    try {
      final isFS = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFS);
      if (mounted) {
        setState(() {
          _isFullScreen = !isFS;
        });
      }
    } catch (_) {
      setState(() {
        _isFullScreen = !_isFullScreen;
      });
      if (_isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  void openDesktopWindow({
    required String id,
    required String title,
    required IconData icon,
    required Color themeColor,
    required Widget content,
    Size defaultSize = const Size(820, 580),
  }) {
    final existingIndex = _openWindows.indexWhere((w) => w.id == id);
    if (existingIndex != -1) {
      final win = _openWindows[existingIndex];
      win.isMinimized = false;
      win.zIndex = ++_highestZIndex;
      setState(() {});
    } else {
      final double offset = (_openWindows.length * 30.0) % 180;
      final newWin = DesktopWindowData(
        id: id,
        title: title,
        icon: icon,
        themeColor: themeColor,
        content: content,
        position: Offset(100 + offset, 50 + offset),
        size: defaultSize,
        zIndex: ++_highestZIndex,
      );
      _openWindows.add(newWin);
      setState(() {});
    }
  }

  void _closeWindow(String id) {
    if (id.startsWith('app_')) {
      final pkg = id.substring(4);
      MirrorService.stopAppMirror(pkg);
    }
    setState(() {
      _openWindows.removeWhere((w) => w.id == id);
    });
  }

  void _minimizeWindow(String id) {
    final win = _openWindows.firstWhere((w) => w.id == id);
    setState(() {
      win.isMinimized = true;
    });
  }

  void _maximizeWindow(String id) {
    final win = _openWindows.firstWhere((w) => w.id == id);
    setState(() {
      if (win.isMaximized) {
        win.isMaximized = false;
        if (win.preMaximizedSize != null) {
          win.size = win.preMaximizedSize!;
        }
        if (win.preMaximizedPosition != null) {
          win.position = win.preMaximizedPosition!;
        }
      } else {
        win.preMaximizedPosition = win.position;
        win.preMaximizedSize = win.size;
        win.isMaximized = true;
        win.position = Offset.zero;
      }
    });
  }

  void _focusWindow(String id) {
    final win = _openWindows.firstWhere((w) => w.id == id);
    if (win.zIndex < _highestZIndex) {
      setState(() {
        win.zIndex = ++_highestZIndex;
      });
    }
  }

  void _toggleWindowFromTaskbar(String id, VoidCallback launchCallback) {
    final existing = _openWindows.where((w) => w.id == id).firstOrNull;
    if (existing != null) {
      if (existing.isMinimized) {
        setState(() {
          existing.isMinimized = false;
          existing.zIndex = ++_highestZIndex;
        });
      } else if (existing.zIndex == _highestZIndex) {
        setState(() {
          existing.isMinimized = true;
        });
      } else {
        _focusWindow(id);
      }
    } else {
      launchCallback();
    }
  }

  void _launchAppMirrorWindow(String packageName, String appName) {
    final winId = 'app_${packageName}_${DateTime.now().millisecondsSinceEpoch}';
    openDesktopWindow(
      id: winId,
      title: appName,
      icon: Icons.screen_share_rounded,
      themeColor: const Color(0xFF3B82F6),
      content: AppMirrorStreamWidget(
        packageName: packageName,
        title: appName,
      ),
      defaultSize: const Size(420, 720),
    );
  }

  void _showAppDrawer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AppDrawerDialog(
        deviceState: widget.deviceState,
        onStartBoot: widget.onStartBoot,
        onLaunchAppWindow: (pkg, name) => _launchAppMirrorWindow(pkg, name),
        onOpenSettingsWindow: () => _showDexSettings(context),
      ),
    );
  }

  void _showDexSettings(BuildContext context) {
    openDesktopWindow(
      id: 'settings',
      title: 'Dex Settings',
      icon: Icons.settings_suggest_rounded,
      themeColor: const Color(0xFF6366F1),
      content: DexSettingsDialog(
        isWindow: true,
        deviceState: widget.deviceState,
        onClose: () => _closeWindow('settings'),
      ),
      defaultSize: const Size(960, 640),
    );
  }

  void _showSms(BuildContext context) {
    openDesktopWindow(
      id: 'sms',
      title: 'Live SMS',
      icon: Icons.message_rounded,
      themeColor: const Color(0xFF00BFA5),
      content: const SmsDialog(isWindow: true),
      defaultSize: const Size(640, 580),
    );
  }

  void _showFileManager(BuildContext context) {
    openDesktopWindow(
      id: 'file_manager',
      title: 'File Explorer',
      icon: Icons.folder_special_rounded,
      themeColor: const Color(0xFF00BFA5),
      content: const FileManagerDialog(isWindow: true),
      defaultSize: const Size(980, 620),
    );
  }

  void _showPhone(BuildContext context, {int initialSubTab = 0}) {
    openDesktopWindow(
      id: 'phone',
      title: 'Phone & Calls',
      icon: Icons.phone_rounded,
      themeColor: const Color(0xFF8B5CF6),
      content: UnifiedPhoneDialog(isWindow: true, initialSubTab: initialSubTab),
      defaultSize: const Size(880, 620),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        "${_now.hour % 12 == 0 ? 12 : _now.hour % 12}:${_now.minute.toString().padLeft(2, '0')} ${_now.hour >= 12 ? 'PM' : 'AM'}";
    final dateStr = "Sat, ${_now.month}/${_now.day}";

    return Scaffold(
      body: Stack(
        children: [
          // 1. Wallpaper Background & Darkness Overlay (Reactive with DexSettingsService)
          Positioned.fill(
            child: ValueListenableBuilder<DexSettingsConfig>(
              valueListenable: DexSettingsService.notifier,
              builder: (_, cfg, __) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      cfg.wallpaperUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/home_page/bg_set_test_1.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (cfg.darknessOverlay > 0)
                      Container(
                        color: Colors.black.withValues(alpha: cfg.darknessOverlay),
                      ),
                  ],
                );
              },
            ),
          ),

          // 2. Desktop Widgets & Shortcuts Grid
          Positioned.fill(
            bottom: 75,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side Widgets & App Shortcuts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBarWidget("Google", Icons.search),
                        const SizedBox(height: 12),
                        _buildSearchBarWidget(
                            "Perplexity AI", Icons.auto_awesome),

                        const Spacer(),

                        // Desktop Icons Grid
                        Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          children: [
                            _buildDesktopShortcut(
                              icon: Icons.screen_share,
                              label: "Mirroring",
                              color: const Color(0xFF3B82F6),
                              onTap: () =>
                                  MirrorService.launchScreenMirroring(),
                            ),
                            _buildDesktopShortcut(
                              icon: Icons.folder_special,
                              label: "File Manager",
                              color: const Color(0xFF10B981),
                              onTap: () => _showFileManager(context),
                            ),
                            _buildDesktopShortcut(
                              icon: Icons.phone,
                              label: "Call",
                              color: const Color(0xFF8B5CF6),
                              onTap: () =>
                                  _showPhone(context, initialSubTab: 0),
                            ),
                            _buildDesktopShortcut(
                              icon: Icons.contacts,
                              label: "Contacts",
                              color: const Color(0xFFF59E0B),
                              onTap: () =>
                                  _showPhone(context, initialSubTab: 2),
                            ),
                            _buildDesktopShortcut(
                              icon: Icons.message_rounded,
                              label: "SMS Messages",
                              color: const Color(0xFF00BFA5),
                              onTap: () =>
                                  _showPhone(context, initialSubTab: 3),
                            ),
                            _buildDesktopShortcut(
                              icon: Icons.grid_view_rounded,
                              label: "Apps Drawer",
                              color: const Color(0xFF00BFA5),
                              onTap: () => _showAppDrawer(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Right Side Widgets (Clock + Phone Health + Media Player)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildClockWidget(timeStr, dateStr),
                      const SizedBox(height: 16),
                      _buildPhoneHealthWidget(),
                      const SizedBox(height: 16),
                      _buildFloatingMediaPlayer(),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2.5 Multi-Window Desktop Stack
          ...(_openWindows.where((w) => !w.isMinimized).toList()
                ..sort((a, b) => a.zIndex.compareTo(b.zIndex)))
              .map((win) {
            final activeWindows =
                _openWindows.where((w) => !w.isMinimized).toList();
            final highestWin = activeWindows.isEmpty
                ? null
                : activeWindows.reduce((a, b) => a.zIndex > b.zIndex ? a : b);
            final isFocused = highestWin?.id == win.id;

            return DesktopWindowWidget(
              key: ValueKey(win.id),
              id: win.id,
              title: win.title,
              icon: win.icon,
              themeColor: win.themeColor,
              content: win.content,
              position: win.position,
              size: win.size,
              isMaximized: win.isMaximized,
              isFocused: isFocused,
              onClose: () => _closeWindow(win.id),
              onMinimize: () => _minimizeWindow(win.id),
              onMaximize: () => _maximizeWindow(win.id),
              onFocus: () => _focusWindow(win.id),
              onDrag: (delta, globalPos) => _handleWindowDrag(
                win,
                delta,
                globalPos,
                MediaQuery.of(context).size,
              ),
              onDragEnd: (globalPos) => _handleWindowDragEnd(
                win,
                globalPos,
                MediaQuery.of(context).size,
              ),
              onResize: (delta,
                  {left = false, top = false, right = false, bottom = false}) {
                setState(() {
                  double newWidth = win.size.width;
                  double newHeight = win.size.height;
                  double newDx = win.position.dx;
                  double newDy = win.position.dy;

                  if (right) {
                    newWidth = (win.size.width + delta.dx).clamp(400.0, 1600.0);
                  }
                  if (bottom) {
                    newHeight =
                        (win.size.height + delta.dy).clamp(300.0, 1000.0);
                  }
                  if (left) {
                    final potentialWidth = win.size.width - delta.dx;
                    if (potentialWidth >= 400.0 && potentialWidth <= 1600.0) {
                      newWidth = potentialWidth;
                      newDx += delta.dx;
                    }
                  }
                  if (top) {
                    final potentialHeight = win.size.height - delta.dy;
                    if (potentialHeight >= 300.0 && potentialHeight <= 1000.0) {
                      newHeight = potentialHeight;
                      newDy += delta.dy;
                    }
                  }

                  win.size = Size(newWidth, newHeight);
                  win.position = Offset(newDx, newDy);
                });
              },
            );
          }),

          // 2.8 Glassmorphic Snap Preview Ghost Box
          if (_activeSnapZone != WindowSnapZone.none)
            Builder(
              builder: (context) {
                final screenSize = MediaQuery.of(context).size;
                final targetRect =
                    _getSnapTargetRect(_activeSnapZone, screenSize);
                if (targetRect == null) return const SizedBox.shrink();

                return Positioned.fromRect(
                  rect: targetRect,
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.8),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF00BFA5).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          )
                        ],
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0F172A).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.aspect_ratio_rounded,
                                  color: Color(0xFF00BFA5), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                _getSnapLabel(_activeSnapZone),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Floating Connection Status Toast Overlay
          if (_connectionToastMessage != null)
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isConnectionToastError
                            ? Colors.redAccent
                            : const Color(0xFF00BFA5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isConnectionToastError
                              ? Icons.signal_cellular_off_rounded
                              : Icons.check_circle_rounded,
                          color: _isConnectionToastError
                              ? Colors.redAccent
                              : const Color(0xFF00BFA5),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _connectionToastMessage!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (_isConnectionToastError) ...[
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: widget.onStartBoot,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.redAccent),
                              ),
                              child: const Text(
                                "Reconnect",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () =>
                              setState(() => _connectionToastMessage = null),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white54, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // FLOATING CALL BANNER OVERLAY
          const Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: Center(
              child: IncomingCallBanner(),
            ),
          ),

          // TASKBAR DOCK
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ZONE 1: Left Navigation & Audio Island
                Row(
                  children: [
                    _buildDockZone(
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu,
                                color: Colors.white70, size: 18),
                            onPressed: () => _showAppDrawer(context),
                            tooltip: "App List",
                          ),
                          IconButton(
                            icon: const Icon(Icons.circle_outlined,
                                color: Colors.white70, size: 16),
                            onPressed: () => AppLauncherService.sendKeyEvent(3),
                            tooltip: "Home",
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_left,
                                color: Colors.white70, size: 20),
                            onPressed: () => AppLauncherService.sendKeyEvent(4),
                            tooltip: "Back",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    TaskbarMediaIsland(
                      deviceState: widget.deviceState,
                      isExpanded: _activePopover == TaskbarPopoverType.media,
                      onTap: () => _togglePopover(TaskbarPopoverType.media),
                      onDismiss: () => setState(
                          () => _activePopover = TaskbarPopoverType.none),
                    ),
                  ],
                ),

                // ZONE 2: Center App Launcher Island & Fluid Active Taskbar Dock
                _buildDockZone(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.apps_rounded,
                            color: Color(0xFF00BFA5), size: 20),
                        onPressed: () => _showAppDrawer(context),
                        tooltip: "App Drawer Launcher",
                      ),
                      const SizedBox(width: 4),
                      _buildTaskbarDockIcon(
                        id: 'file_manager',
                        icon: Icons.folder_special_rounded,
                        color: const Color(0xFF10B981),
                        tooltip: "File Explorer",
                        onTap: () => _toggleWindowFromTaskbar(
                            'file_manager', () => _showFileManager(context)),
                      ),
                      const SizedBox(width: 6),
                      _buildTaskbarDockIcon(
                        id: 'phone',
                        icon: Icons.phone_rounded,
                        color: const Color(0xFF8B5CF6),
                        tooltip: "Phone & Calls",
                        onTap: () => _toggleWindowFromTaskbar(
                            'phone', () => _showPhone(context)),
                      ),
                      const SizedBox(width: 6),
                      _buildTaskbarDockIcon(
                        id: 'sms',
                        icon: Icons.message_rounded,
                        color: const Color(0xFF00BFA5),
                        tooltip: "Live SMS",
                        onTap: () => _toggleWindowFromTaskbar(
                            'sms', () => _showSms(context)),
                      ),

                      // Fluid Dynamic Open Windows Registration!
                      for (final win in _openWindows.where((w) => ![
                            'file_manager',
                            'phone',
                            'sms'
                          ].contains(w.id))) ...[
                        const SizedBox(width: 6),
                        _buildTaskbarDockIcon(
                          id: win.id,
                          icon: win.icon,
                          color: win.themeColor,
                          tooltip: win.title,
                          onTap: () => _toggleWindowFromTaskbar(win.id, () {}),
                        ),
                      ],
                    ],
                  ),
                ),

                Row(
                  children: [
                    // ZONE 3: System Tray Islands (Adaptive Notifications, Battery, Settings)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // 0. Icon Sync Status Indicator
                        ValueListenableBuilder<AppIconSyncProgress>(
                          valueListenable: AppLauncherService.iconSyncProgress,
                          builder: (context, progress, _) {
                            if (progress.totalApps == 0) {
                              return const SizedBox.shrink();
                            }
                            if (progress.isComplete) {
                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: Tooltip(
                                  message:
                                      "All app icons synced (${progress.syncedApps}/${progress.totalApps})",
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00BFA5)
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFF00BFA5)
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: const Icon(Icons.cloud_done_rounded,
                                        color: Color(0xFF00BFA5), size: 14),
                                  ),
                                ),
                              );
                            }

                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: Tooltip(
                                message:
                                    "Syncing app icons (${progress.syncedApps}/${progress.totalApps})...",
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.amberAccent
                                            .withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.amberAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${progress.syncedApps}/${progress.totalApps}",
                                        style: const TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // 1. Notification Island
                        ValueListenableBuilder<List<RealNotificationItem>>(
                          valueListenable: widget.deviceState.notifications,
                          builder: (context, notifs, _) {
                            final count = notifs.length;
                            return SmartTaskbarPopoverButton(
                              isExpanded: _activePopover ==
                                  TaskbarPopoverType.notifications,
                              onTap: () => _togglePopover(
                                  TaskbarPopoverType.notifications),
                              onDismiss: () => setState(() =>
                                  _activePopover = TaskbarPopoverType.none),
                              compactChild: Row(
                                children: [
                                  _buildStackedNotificationIcons(notifs),
                                  if (count > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        count > 9 ? "9+" : "$count",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              expandedChild: NotificationFlyout(
                                deviceState: widget.deviceState,
                                onClose: () => setState(() =>
                                    _activePopover = TaskbarPopoverType.none),
                              ),
                            );
                          },
                        ),

                        const SizedBox(width: 6),

                        // 2. Battery Island
                        ValueListenableBuilder<int>(
                          valueListenable: widget.deviceState.batteryPercentage,
                          builder: (_, battery, __) =>
                              SmartTaskbarPopoverButton(
                            isExpanded:
                                _activePopover == TaskbarPopoverType.battery,
                            onTap: () =>
                                _togglePopover(TaskbarPopoverType.battery),
                            onDismiss: () => setState(
                                () => _activePopover = TaskbarPopoverType.none),
                            compactChild: Row(
                              children: [
                                const Icon(Icons.battery_charging_full,
                                    color: Colors.greenAccent, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  "$battery%",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            expandedChild: const BatteryPopover(),
                          ),
                        ),

                        const SizedBox(width: 6),

                        // 3. Control Center Settings Island
                        SmartTaskbarPopoverButton(
                          isExpanded:
                              _activePopover == TaskbarPopoverType.settings,
                          onTap: () =>
                              _togglePopover(TaskbarPopoverType.settings),
                          onDismiss: () => setState(
                              () => _activePopover = TaskbarPopoverType.none),
                          compactChild: const Icon(Icons.settings,
                              color: Colors.white70, size: 18),
                          expandedChild: QuickSettingsPopover(
                            deviceState: widget.deviceState,
                            onOpenFullSettings: () {
                              setState(() => _activePopover = TaskbarPopoverType.none);
                              _showDexSettings(context);
                            },
                            onLockDex: () {
                              setState(() {
                                _activePopover = TaskbarPopoverType.none;
                                _isDexLocked = true;
                              });
                            },
                            onShutdown: () {
                              setState(() =>
                                  _activePopover = TaskbarPopoverType.none);
                              _showPowerConfirmationDialog(context,
                                  isShutdown: true);
                            },
                            onRestart: () {
                              setState(() =>
                                  _activePopover = TaskbarPopoverType.none);
                              _showPowerConfirmationDialog(context,
                                  isShutdown: false);
                            },
                            onRestartDexApp: () {
                              setState(() =>
                                  _activePopover = TaskbarPopoverType.none);
                              _showRestartDexAppDialog(context);
                            },
                            onTakeScreenshot: () {
                              setState(() =>
                                  _activePopover = TaskbarPopoverType.none);
                              _takeScreenshot();
                            },
                            onOpenDeviceHealth: () {
                              setState(() =>
                                  _activePopover = TaskbarPopoverType.none);
                              _showDeviceHealthDialog(context);
                            },
                            onOpenWirelessAdb: () {
                              setState(() =>
                                  _activePopover = TaskbarPopoverType.none);
                              _showWirelessAdbDialog(context);
                            },
                            onShowSystemInfo: () {
                              setState(() =>
                                  _activePopover = TaskbarPopoverType.none);
                              _showSystemInfoDialog(context);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 6),
                    // ZONE 4: Right Clock & Display Island
                    _buildDockZone(
                      child: Row(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeStr,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10),
                              ),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 8),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _isFullScreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              color: Colors.white70,
                              size: 18,
                            ),
                            onPressed: _toggleFullScreen,
                            tooltip: _isFullScreen
                                ? "Exit Fullscreen"
                                : "Toggle Fullscreen",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isDexLocked) _buildDexLockScreen(),
        ],
      ),
    );
  }

  void _showDeviceHealthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: DeviceHealthPopover(
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _showWirelessAdbDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const WirelessAdbDialog(),
    );
  }

  void _showRestartDexAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Row(
          children: [
            Icon(Icons.refresh_rounded, color: Colors.cyanAccent, size: 24),
            SizedBox(width: 10),
            Text(
              "Restart DEX Application",
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to restart the DEX Desktop Shell application process?",
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final String executable = Platform.resolvedExecutable;
                final List<String> args = Platform.executableArguments;
                await Process.start(executable, args,
                    mode: ProcessStartMode.detached);
                exit(0);
              } catch (e) {
                debugPrint("Restart app failed: $e");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Restart App",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPowerConfirmationDialog(BuildContext context,
      {required bool isShutdown}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white12),
        ),
        title: Row(
          children: [
            Icon(
              isShutdown ? Icons.power_settings_new : Icons.restart_alt,
              color: isShutdown ? Colors.redAccent : Colors.orangeAccent,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              isShutdown ? "Shutdown DEX Device" : "Restart DEX Device",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ],
        ),
        content: Text(
          isShutdown
              ? "Are you sure you want to power off the connected Android device?"
              : "Are you sure you want to reboot the connected Android device?",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final adbPath = await AdbDeviceScanner.getAdbPath();
              if (isShutdown) {
                await Process.run(adbPath, ['shell', 'reboot', '-p']);
              } else {
                await Process.run(adbPath, ['shell', 'reboot']);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isShutdown
                        ? "Shutting down device..."
                        : "Rebooting device..."),
                    backgroundColor: const Color(0xFF1E293B),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isShutdown ? Colors.redAccent : Colors.orangeAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isShutdown ? "Shutdown" : "Restart"),
          ),
        ],
      ),
    );
  }

  Future<void> _takeScreenshot() async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final remotePath = '/sdcard/dex_screenshot_$timestamp.png';
      await Process.run(adbPath, ['shell', 'screencap', '-p', remotePath]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.camera_alt,
                    color: Color(0xFF00BFA5), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      Text("Screenshot saved: dex_screenshot_$timestamp.png"),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFF00BFA5)),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Screenshot failed: $e");
    }
  }

  void _showSystemInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF00BFA5), size: 24),
            SizedBox(width: 10),
            Text("System & Hardware Information",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSystemInfoRow("Device IP", widget.deviceState.deviceIp.value),
            _buildSystemInfoRow("Battery Level",
                "${widget.deviceState.batteryPercentage.value}%"),
            _buildSystemInfoRow("DEX Environment", "Desktop Shell v2.5"),
            _buildSystemInfoRow("ADB Reverse Port", "38947, 4567, 8080"),
            _buildSystemInfoRow("Platform OS", "Linux x86_64"),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Close",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF00BFA5),
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDexLockScreen() {
    final timeStr =
        "${_now.hour % 12 == 0 ? 12 : _now.hour % 12}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')} ${_now.hour >= 12 ? 'PM' : 'AM'}";
    final dateStr =
        "${_getWeekdayName(_now.weekday)}, ${_getMonthName(_now.month)} ${_now.day}";

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Center(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white12, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:
                              const Color(0xFF00BFA5).withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Color(0xFF00BFA5), size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFF00BFA5),
                        child:
                            Icon(Icons.person, color: Colors.black, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "GameT1 DEX User",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            "Session Locked",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isDexLocked = false;
                      });
                    },
                    icon: const Icon(Icons.lock_open_rounded, size: 20),
                    label: const Text(
                      "Unlock DEX",
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneHealthWidget() {
    return ValueListenableBuilder<int>(
      valueListenable: widget.deviceState.batteryPercentage,
      builder: (context, batteryPct, _) {
        return Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phonelink_setup, color: Color(0xFF00BFA5), size: 18),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<String>(
                        valueListenable: widget.deviceState.deviceName,
                        builder: (_, name, __) => Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: widget.deviceState.connectionRoute,
                    builder: (_, route, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        route,
                        style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Phone Battery", style: TextStyle(color: Colors.white70, fontSize: 11)),
                            Text("$batteryPct%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (batteryPct / 100.0).clamp(0.0, 1.0),
                            backgroundColor: Colors.white10,
                            color: batteryPct > 20 ? const Color(0xFF10B981) : Colors.redAccent,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _getWeekdayName(int weekday) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return days[(weekday - 1) % 7];
  }

  String _getMonthName(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[(month - 1) % 12];
  }

  Widget _buildStackedNotificationIcons(List<RealNotificationItem> notifs) {
    if (notifs.isEmpty) {
      return const Icon(Icons.notifications_outlined,
          color: Color(0xFF00BFA5), size: 18);
    }

    final recent = notifs.take(3).toList();

    return SizedBox(
      width: 22 + (recent.length - 1) * 14.0,
      height: 26,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          for (int i = recent.length - 1; i >= 0; i--) ...[
            Positioned(
              left: i * 14.0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFF0F172A), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                    )
                  ],
                ),
                child: SmartAppIconWidget(
                  packageName: recent[i].packageName,
                  size: 22,
                  borderRadius: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskbarDockIcon({
    required String id,
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final isOpen = _openWindows.any((w) => w.id == id);
    final activeWindows = _openWindows.where((w) => !w.isMinimized).toList();
    final highestWin = activeWindows.isEmpty
        ? null
        : activeWindows.reduce((a, b) => a.zIndex > b.zIndex ? a : b);
    final isFocused = highestWin?.id == id;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isFocused
                ? color.withValues(alpha: 0.3)
                : isOpen
                    ? Colors.white10
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isFocused
                ? Border.all(color: color.withValues(alpha: 0.6))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isFocused ? color : Colors.white70, size: 18),
              if (isOpen) ...[
                const SizedBox(height: 2),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockZone({required Widget child}) {
    return SizedBox(
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarWidget(String title, IconData icon) {
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00BFA5), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Search $title",
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockWidget(String timeStr, String dateStr) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.7),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingMediaPlayer() {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.music_note, color: Colors.purpleAccent),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "THE REPORTER WA...",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  "Unknown Artist",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous,
                color: Colors.white70, size: 20),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: const Color(0xFF00BFA5),
              size: 32,
            ),
            onPressed: () => setState(() => _isPlaying = !_isPlaying),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, color: Colors.white70, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopShortcut({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class TaskbarMediaIsland extends StatefulWidget {
  final DeviceState? deviceState;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const TaskbarMediaIsland({
    super.key,
    this.deviceState,
    required this.isExpanded,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<TaskbarMediaIsland> createState() => _TaskbarMediaIslandState();
}

class _TaskbarMediaIslandState extends State<TaskbarMediaIsland> {
  @override
  Widget build(BuildContext context) {
    return widget.deviceState != null
        ? ValueListenableBuilder<RealMediaState>(
            valueListenable: widget.deviceState!.mediaState,
            builder: (context, media, _) {
              return _buildCompactIsland(media);
            },
          )
        : _buildCompactIsland(const RealMediaState());
  }

  Widget _buildCompactArtwork(RealMediaState media) {
    if (media.artworkBase64 != null && media.artworkBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(media.artworkBase64!);
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        );
      } catch (_) {}
    }
    if (media.packageName.isNotEmpty) {
      return SmartAppIconWidget(
          packageName: media.packageName, size: 18, borderRadius: 9);
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.music_note_rounded,
          color: Color(0xFF8B5CF6), size: 12),
    );
  }

  Widget _buildCompactIsland(RealMediaState media) {
    final bool isPlaying = media.isPlaying;
    final String title =
        media.title.isNotEmpty ? media.title : "Starlight Horizon";

    return SmartTaskbarPopoverButton(
      isExpanded: widget.isExpanded,
      onTap: widget.onTap,
      onDismiss: widget.onDismiss,
      compactChild: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactArtwork(media),
          const SizedBox(width: 6),
          SizedBox(
            width: 110,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => AppLauncherService.sendKeyEvent(88), // PREVIOUS
            child: const Icon(Icons.skip_previous_rounded,
                color: Colors.white70, size: 16),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              if (widget.deviceState != null) {
                final cur = widget.deviceState!.mediaState.value;
                widget.deviceState!.mediaState.value = cur.copyWith(
                  isPlaying: !cur.isPlaying,
                );
              }
              AppLauncherService.sendKeyEvent(85); // PLAY_PAUSE
            },
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: const Color(0xFF00BFA5),
              size: 18,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => AppLauncherService.sendKeyEvent(87), // NEXT
            child: const Icon(Icons.skip_next_rounded,
                color: Colors.white70, size: 16),
          ),
        ],
      ),
      expandedChild: MediaPlayerFlyout(deviceState: widget.deviceState),
    );
  }
}
