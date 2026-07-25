import 'dart:ui';
import 'package:flutter/material.dart';

class TaskbarPopoverOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback onClose;
  final double rightOffset;

  const TaskbarPopoverOverlay({
    super.key,
    required this.child,
    required this.onClose,
    this.rightOffset = 16.0,
  });

  @override
  State<TaskbarPopoverOverlay> createState() => _TaskbarPopoverOverlayState();
}

class _TaskbarPopoverOverlayState extends State<TaskbarPopoverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closeWithAnimation() async {
    await _controller.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeWithAnimation, // Dismiss when clicking background
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned(
            right: widget.rightOffset,
            bottom: 64, // Positioned right above the bottom taskbar
            child: GestureDetector(
              onTap: () {}, // Prevent tap-through
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
