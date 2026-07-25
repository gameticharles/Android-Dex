import 'package:flutter/material.dart';

typedef WindowResizeCallback = void Function(
  Offset delta, {
  bool left,
  bool top,
  bool right,
  bool bottom,
});

typedef WindowDragUpdateCallback = void Function(
    Offset delta, Offset globalPosition);
typedef WindowDragEndCallback = void Function(Offset globalPosition);

class DesktopWindowWidget extends StatelessWidget {
  final String id;
  final String title;
  final IconData icon;
  final Color themeColor;
  final Widget content;
  final Offset position;
  final Size size;
  final bool isMaximized;
  final bool isFocused;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final VoidCallback onFocus;
  final WindowDragUpdateCallback onDrag;
  final ValueChanged<Offset>? onDragStart;
  final WindowDragEndCallback? onDragEnd;
  final WindowResizeCallback onResize;

  const DesktopWindowWidget({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    required this.themeColor,
    required this.content,
    required this.position,
    required this.size,
    required this.isMaximized,
    required this.isFocused,
    required this.onClose,
    required this.onMinimize,
    required this.onMaximize,
    required this.onFocus,
    required this.onDrag,
    this.onDragStart,
    this.onDragEnd,
    required this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: isMaximized ? 0 : position.dx,
      top: isMaximized ? 0 : position.dy,
      width: isMaximized ? MediaQuery.of(context).size.width : size.width,
      height:
          isMaximized ? MediaQuery.of(context).size.height - 75 : size.height,
      child: GestureDetector(
        onTapDown: (_) => onFocus(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.96),
            borderRadius:
                isMaximized ? BorderRadius.zero : BorderRadius.circular(16),
            border: Border.all(
              color: isFocused
                  ? themeColor.withValues(alpha: 0.8)
                  : Colors.white10,
              width: isFocused ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isFocused
                    ? themeColor.withValues(alpha: 0.25)
                    : Colors.black45,
                blurRadius: isFocused ? 25 : 15,
                spreadRadius: isFocused ? 2 : 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius:
                isMaximized ? BorderRadius.zero : BorderRadius.circular(16),
            child: Stack(
              children: [
                Column(
                  children: [
                    // Desktop Window Title Bar (Drag Handle & Controls with Move Cursor)
                    MouseRegion(
                      cursor: isMaximized
                          ? SystemMouseCursors.basic
                          : SystemMouseCursors.move,
                      child: GestureDetector(
                        onPanStart: (details) {
                          if (!isMaximized) {
                            onDragStart?.call(details.globalPosition);
                          }
                        },
                        onPanUpdate: (details) {
                          if (!isMaximized) {
                            onDrag(details.delta, details.globalPosition);
                          }
                        },
                        onPanEnd: (details) {
                          if (!isMaximized) {
                            onDragEnd?.call(details.globalPosition);
                          }
                        },
                        onDoubleTap: onMaximize,
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF111827),
                            border: const Border(
                                bottom: BorderSide(color: Colors.white10)),
                          ),
                          child: Row(
                            children: [
                              Icon(icon, color: themeColor, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    color: isFocused
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // Window Control Buttons (Minimize, Maximize/Restore, Close)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: InkWell(
                                      onTap: onMinimize,
                                      borderRadius: BorderRadius.circular(6),
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(Icons.remove_rounded,
                                            color: Colors.white70, size: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: InkWell(
                                      onTap: onMaximize,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(
                                          isMaximized
                                              ? Icons.filter_none_rounded
                                              : Icons.crop_square_rounded,
                                          color: Colors.white70,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: InkWell(
                                      onTap: onClose,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.white10,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close_rounded,
                                            color: Colors.white70, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Window Body Content
                    Expanded(
                      child: ClipRect(
                        child: content,
                      ),
                    ),
                  ],
                ),

                // Window Border & Corner Resize Handles (with Dynamic System Mouse Cursors)
                if (!isMaximized) ...[
                  // Top Edge
                  Positioned(
                    top: 0,
                    left: 12,
                    right: 12,
                    height: 6,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            onResize(details.delta, top: true),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Bottom Edge
                  Positioned(
                    bottom: 0,
                    left: 12,
                    right: 12,
                    height: 6,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            onResize(details.delta, bottom: true),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Left Edge
                  Positioned(
                    left: 0,
                    top: 12,
                    bottom: 12,
                    width: 6,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            onResize(details.delta, left: true),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Right Edge
                  Positioned(
                    right: 0,
                    top: 12,
                    bottom: 12,
                    width: 6,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            onResize(details.delta, right: true),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Top-Left Corner
                  Positioned(
                    top: 0,
                    left: 0,
                    width: 12,
                    height: 12,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            onResize(details.delta, top: true, left: true),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Top-Right Corner
                  Positioned(
                    top: 0,
                    right: 0,
                    width: 12,
                    height: 12,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpRightDownLeft,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            onResize(details.delta, top: true, right: true),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Bottom-Left Corner
                  Positioned(
                    bottom: 0,
                    left: 0,
                    width: 12,
                    height: 12,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpRightDownLeft,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            onResize(details.delta, bottom: true, left: true),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),

                  // Bottom-Right Corner (with visual Grip Handle painter)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: 18,
                    height: 18,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      child: GestureDetector(
                        onPanUpdate: (details) =>
                            onResize(details.delta, bottom: true, right: true),
                        child: Container(
                          color: Colors.transparent,
                          child: CustomPaint(
                            painter: _ResizeHandlePainter(
                                color: isFocused ? themeColor : Colors.white30),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResizeHandlePainter extends CustomPainter {
  final Color color;
  _ResizeHandlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(size.width - 4, size.height - 12),
        Offset(size.width - 12, size.height - 4), paint);
    canvas.drawLine(Offset(size.width - 4, size.height - 7),
        Offset(size.width - 7, size.height - 4), paint);
  }

  @override
  bool shouldRepaint(covariant _ResizeHandlePainter oldDelegate) =>
      oldDelegate.color != color;
}
