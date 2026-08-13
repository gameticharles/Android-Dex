import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:adb_device_manager/features/settings/services/dex_settings_service.dart';
import 'package:adb_device_manager/features/app_mirror/services/mirror_service.dart';
import 'package:adb_device_manager/features/app_mirror/services/app_launcher_service.dart';

class AppMirrorStreamWidget extends StatefulWidget {
  final String packageName;
  final String title;

  const AppMirrorStreamWidget({
    super.key,
    required this.packageName,
    required this.title,
  });

  @override
  State<AppMirrorStreamWidget> createState() => _AppMirrorStreamWidgetState();
}

class _AppMirrorStreamWidgetState extends State<AppMirrorStreamWidget> {
  bool _isLaunching = true;
  bool _isStreaming = false;
  bool _isFetchingFrame = false;
  Uint8List? _currentFrame;
  Size _deviceResolution = const Size(1080, 2400);
  Timer? _streamTimer;
  Offset? _panStartPos;

  @override
  void initState() {
    super.initState();
    _initAppStream();
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _stopStream() {
    _isStreaming = false;
    _streamTimer?.cancel();
    _streamTimer = null;
  }

  Future<void> _initAppStream() async {
    setState(() {
      _isLaunching = true;
      _currentFrame = null;
    });

    final cfg = DexSettingsService.notifier.value;
    if (cfg.appOpeningMode == 'Scrcpy standalone') {
      await MirrorService.launchAppMirror(widget.packageName, widget.title);
      if (mounted) {
        setState(() {
          _isLaunching = false;
        });
      }
      return;
    }

    // 1. Launch the requested app on the device
    await AppLauncherService.launchApp(widget.packageName);
    await Future.delayed(const Duration(milliseconds: 120));

    // 2. Fetch real physical screen size
    final size = await AppLauncherService.getDeviceDisplaySize();
    if (mounted) {
      setState(() {
        _deviceResolution = size;
      });
    }

    // 3. Capture first frame
    final initialFrame = await AppLauncherService.captureScreenFrame();
    if (mounted) {
      setState(() {
        _isLaunching = false;
        _currentFrame = initialFrame;
      });
    }

    // 4. Start active stream loop
    _startLiveStream();
  }

  void _startLiveStream() {
    _stopStream();
    _isStreaming = true;
    _streamTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      _fetchNextFrame();
    });
  }

  Future<void> _fetchNextFrame() async {
    if (!_isStreaming || _isFetchingFrame || !mounted) return;
    _isFetchingFrame = true;

    try {
      final frame = await AppLauncherService.captureScreenFrame();
      if (frame != null && mounted) {
        setState(() {
          _currentFrame = frame;
          _isLaunching = false;
        });
      }
    } catch (_) {
    } finally {
      _isFetchingFrame = false;
    }
  }

  Future<void> _requestImmediateFrame() async {
    await Future.delayed(const Duration(milliseconds: 60));
    await _fetchNextFrame();
  }

  Offset _mapLocalToDeviceCoords(Offset local, BoxConstraints constraints) {
    final double devW = _deviceResolution.width;
    final double devH = _deviceResolution.height;
    final double widgetW = constraints.maxWidth;
    final double widgetH = constraints.maxHeight;

    if (widgetW <= 0 || widgetH <= 0) return Offset.zero;

    final double devAspect = devW / devH;
    final double widgetAspect = widgetW / widgetH;

    double renderW, renderH, offsetX, offsetY;

    if (widgetAspect > devAspect) {
      renderH = widgetH;
      renderW = widgetH * devAspect;
      offsetX = (widgetW - renderW) / 2;
      offsetY = 0;
    } else {
      renderW = widgetW;
      renderH = widgetW / devAspect;
      offsetX = 0;
      offsetY = (widgetH - renderH) / 2;
    }

    final double relativeX = (local.dx - offsetX).clamp(0.0, renderW);
    final double relativeY = (local.dy - offsetY).clamp(0.0, renderH);

    final double touchX = (relativeX / renderW) * devW;
    final double touchY = (relativeY / renderH) * devH;

    return Offset(touchX.clamp(0.0, devW), touchY.clamp(0.0, devH));
  }

  void _showTextInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.keyboard_alt_rounded, color: Color(0xFF00BFA5)),
            SizedBox(width: 10),
            Text("Send Text to App",
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Type message or search term...",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (text) {
            if (text.isNotEmpty) {
              AppLauncherService.sendInputText(text);
              _requestImmediateFrame();
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5)),
            onPressed: () {
              final text = controller.text;
              if (text.isNotEmpty) {
                AppLauncherService.sendInputText(text);
                _requestImmediateFrame();
              }
              Navigator.pop(ctx);
            },
            child: const Text("Send",
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0F19),
      child: Column(
        children: [
          // Control Toolbar Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_android_rounded,
                      color: Color(0xFF00BFA5), size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fiber_manual_record,
                                    size: 7, color: Color(0xFF10B981)),
                                SizedBox(width: 3),
                                Text(
                                  "LIVE",
                                  style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "${widget.packageName} • ${_deviceResolution.width.toInt()}x${_deviceResolution.height.toInt()}",
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 9),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                IconButton(
                  icon: const Icon(Icons.keyboard_alt_rounded,
                      color: Colors.white70, size: 17),
                  tooltip: "Type Text Input",
                  visualDensity: VisualDensity.compact,
                  onPressed: _showTextInputDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white70, size: 17),
                  tooltip: "Refresh Screen",
                  visualDensity: VisualDensity.compact,
                  onPressed: _requestImmediateFrame,
                ),
                IconButton(
                  icon: const Icon(Icons.rotate_90_degrees_cw_rounded,
                      color: Colors.white70, size: 17),
                  tooltip: "Rotate Screen",
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    AppLauncherService.sendKeyEvent(268);
                    _requestImmediateFrame();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: Colors.white70, size: 19),
                  tooltip: "Back (Android)",
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    AppLauncherService.sendKeyEvent(4);
                    _requestImmediateFrame();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.circle_outlined,
                      color: Colors.white70, size: 14),
                  tooltip: "Home (Android)",
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    AppLauncherService.sendKeyEvent(3);
                    _requestImmediateFrame();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.crop_square_rounded,
                      color: Colors.white70, size: 16),
                  tooltip: "Recents / Multitasking",
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    AppLauncherService.sendKeyEvent(187);
                    _requestImmediateFrame();
                  },
                ),
              ],
            ),
          ),

          // Main Live Screen Viewport
          Expanded(
            child: Center(
              child: _isLaunching
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            color: Color(0xFF00BFA5)),
                        const SizedBox(height: 16),
                        Text(
                          "Connecting to ${widget.title}...",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.packageName,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    )
                  : _currentFrame != null
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) {
                                final mapped = _mapLocalToDeviceCoords(
                                    details.localPosition, constraints);
                                AppLauncherService.sendTouchTap(
                                    mapped.dx.toInt(), mapped.dy.toInt());
                                _requestImmediateFrame();
                              },
                              onPanStart: (details) {
                                _panStartPos = _mapLocalToDeviceCoords(
                                    details.localPosition, constraints);
                              },
                              onPanEnd: (details) {
                                if (_panStartPos != null) {
                                  final start = _panStartPos!;
                                  final double deltaY =
                                      -(details.velocity.pixelsPerSecond.dy *
                                              0.2)
                                          .clamp(-600.0, 600.0);
                                  final double deltaX =
                                      -(details.velocity.pixelsPerSecond.dx *
                                              0.2)
                                          .clamp(-400.0, 400.0);

                                  final double endX = (start.dx + deltaX).clamp(
                                      0.0, _deviceResolution.width);
                                  final double endY = (start.dy + deltaY).clamp(
                                      0.0, _deviceResolution.height);

                                  AppLauncherService.sendTouchSwipe(
                                    start.dx.toInt(),
                                    start.dy.toInt(),
                                    endX.toInt(),
                                    endY.toInt(),
                                    200,
                                  );
                                  _requestImmediateFrame();
                                  _panStartPos = null;
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.black,
                                alignment: Alignment.center,
                                child: Image.memory(
                                  _currentFrame!,
                                  gaplessPlayback: true,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            );
                          },
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 44, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(
                              "Unable to display ${widget.title}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00BFA5)),
                              icon: const Icon(Icons.refresh,
                                  color: Colors.black, size: 16),
                              label: const Text("Retry Connection",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                              onPressed: _initAppStream,
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
