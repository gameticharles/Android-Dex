import 'package:flutter/material.dart';

class SmartTaskbarPopoverButton extends StatefulWidget {
  final Widget compactChild;
  final Widget expandedChild;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const SmartTaskbarPopoverButton({
    super.key,
    required this.compactChild,
    required this.expandedChild,
    required this.isExpanded,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<SmartTaskbarPopoverButton> createState() => _SmartTaskbarPopoverButtonState();
}

class _SmartTaskbarPopoverButtonState extends State<SmartTaskbarPopoverButton> {
  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) {
        if (widget.isExpanded) {
          widget.onDismiss();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        height: widget.isExpanded ? null : 48,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: widget.isExpanded ? 0.95 : 0.7),
          borderRadius: BorderRadius.circular(widget.isExpanded ? 24 : 16),
          border: Border.all(
            color: widget.isExpanded ? const Color(0xFF00BFA5) : Colors.white10,
            width: widget.isExpanded ? 1.5 : 1,
          ),
          boxShadow: [
            if (widget.isExpanded)
              BoxShadow(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
        ),
        child: InkWell(
          onTap: widget.isExpanded ? null : widget.onTap,
          borderRadius: BorderRadius.circular(widget.isExpanded ? 24 : 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.isExpanded ? 24 : 16),
            child: AnimatedCrossFade(
              firstChild: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                child: widget.compactChild,
              ),
              secondChild: widget.expandedChild,
              crossFadeState: widget.isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ),
        ),
      ),
    );
  }
}
