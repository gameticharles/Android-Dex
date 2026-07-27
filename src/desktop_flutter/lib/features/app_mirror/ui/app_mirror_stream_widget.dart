import 'package:flutter/material.dart';
import '../services/mirror_service.dart';
import '../services/app_launcher_service.dart';

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
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _startAppStream();
  }

  Future<void> _startAppStream() async {
    setState(() {
      _isLaunching = true;
      _hasStarted = false;
    });

    final proc =
        await MirrorService.launchAppMirror(widget.packageName, widget.title);

    if (mounted) {
      setState(() {
        _isLaunching = false;
        _hasStarted = proc != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          // Control Toolbar Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.screen_share_rounded,
                      color: Color(0xFF00BFA5), size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.packageName,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white70, size: 18),
                  tooltip: "Relaunch App Mirror",
                  onPressed: _startAppStream,
                ),
                IconButton(
                  icon: const Icon(Icons.rotate_90_degrees_cw_rounded,
                      color: Colors.white70, size: 18),
                  tooltip: "Rotate Screen",
                  onPressed: () => AppLauncherService.sendKeyEvent(268),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: Colors.white70, size: 20),
                  tooltip: "Back",
                  onPressed: () => AppLauncherService.sendKeyEvent(4),
                ),
                IconButton(
                  icon: const Icon(Icons.circle_outlined,
                      color: Colors.white70, size: 16),
                  tooltip: "Home",
                  onPressed: () => AppLauncherService.sendKeyEvent(3),
                ),
              ],
            ),
          ),

          // Main Stream / Mirror Display Region
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
                          "Launching ${widget.title} on desktop...",
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
                  : _hasStarted
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            return GestureDetector(
                              onTapDown: (details) {
                                final double dx = (details.localPosition.dx /
                                        constraints.maxWidth)
                                    .clamp(0.0, 1.0) *
                                    1080;
                                final double dy = (details.localPosition.dy /
                                        constraints.maxHeight)
                                    .clamp(0.0, 1.0) *
                                    2340;
                                AppLauncherService.sendTouchTap(
                                    dx.toInt(), dy.toInt());
                              },
                              onPanEnd: (details) {
                                final double startX = 540;
                                final double startY = 1170;
                                final double endY = (startY -
                                        (details.velocity.pixelsPerSecond.dy *
                                            0.2))
                                    .clamp(100.0, 2200.0);
                                AppLauncherService.sendTouchSwipe(
                                    startX.toInt(),
                                    startY.toInt(),
                                    startX.toInt(),
                                    endY.toInt(),
                                    250);
                              },
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: Colors.transparent,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00BFA5)
                                            .withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF00BFA5)
                                                .withValues(alpha: 0.4)),
                                      ),
                                      child: const Icon(
                                          Icons.screen_share_rounded,
                                          size: 48,
                                          color: Color(0xFF00BFA5)),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "${widget.title} is Active on Desktop",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Interactive touch & drag controls enabled. Click/drag anywhere to interact.",
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 12),
                                    ),
                                    const SizedBox(height: 20),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: Color(0xFF00BFA5)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.refresh,
                                          color: Color(0xFF00BFA5), size: 16),
                                      label: const Text("Focus / Re-stream App",
                                          style: TextStyle(
                                              color: Color(0xFF00BFA5))),
                                      onPressed: _startAppStream,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 48, color: Colors.redAccent),
                            const SizedBox(height: 16),
                            Text(
                              "Failed to stream ${widget.title}",
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
                              label: const Text("Retry",
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                              onPressed: _startAppStream,
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
