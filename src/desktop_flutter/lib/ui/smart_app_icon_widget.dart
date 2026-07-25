import 'package:flutter/material.dart';
import '../services/app_launcher_service.dart';

class SmartAppIconWidget extends StatefulWidget {
  final String packageName;
  final double size;
  final double borderRadius;

  const SmartAppIconWidget({
    super.key,
    required this.packageName,
    this.size = 24.0,
    this.borderRadius = 12.0,
  });

  @override
  State<SmartAppIconWidget> createState() => _SmartAppIconWidgetState();
}

class _SmartAppIconWidgetState extends State<SmartAppIconWidget> {
  String? _iconUrl;

  @override
  void initState() {
    super.initState();
    _resolveIcon();
  }

  @override
  void didUpdateWidget(SmartAppIconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName) {
      _resolveIcon();
    }
  }

  void _resolveIcon() {
    final cached = AppLauncherService.getCachedIconUrl(widget.packageName);
    if (cached != null) {
      _iconUrl = cached;
      return;
    }

    AppLauncherService.getIconUrlForPackage(widget.packageName).then((url) {
      if (mounted && url != null && url != _iconUrl) {
        setState(() {
          _iconUrl = url;
        });
      }
    });
  }

  Widget _buildFallback() {
    String firstChar = 'A';
    if (widget.packageName.isNotEmpty) {
      final appName = widget.packageName.split('.').last;
      if (appName.isNotEmpty) firstChar = appName[0].toUpperCase();
    }

    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF00BFA5).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Text(
        firstChar,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: widget.size * 0.45,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_iconUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.network(
          _iconUrl!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
      );
    }

    return _buildFallback();
  }
}
