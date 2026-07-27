import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:adb_device_manager/core/adb/adb_device_scanner.dart';
import 'package:adb_device_manager/features/settings/services/dex_settings_service.dart';

/// Bi-directional Desktop <-> Android Phone Clipboard Sync Service
class ClipboardSyncService {
  static Timer? _syncTimer;
  static String _lastDesktopClipboard = '';
  static String _lastPhoneClipboard = '';

  /// Start clipboard synchronization loop (runs every 1.5 seconds)
  static void startSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      await syncClipboard();
    });
  }

  /// Stop clipboard synchronization loop
  static void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Perform single bi-directional clipboard sync pass
  static Future<void> syncClipboard() async {
    final cfg = DexSettingsService.notifier.value;
    if (!cfg.syncClipboard) return;

    try {
      // 1. Check Desktop Clipboard (Linux -> Android)
      if (cfg.linuxToAndroid) {
        final desktopData = await Clipboard.getData(Clipboard.kTextPlain);
        final desktopText = desktopData?.text?.trim() ?? '';

        if (desktopText.isNotEmpty &&
            desktopText != _lastDesktopClipboard &&
            desktopText != _lastPhoneClipboard) {
          _lastDesktopClipboard = desktopText;
          // Push desktop text to phone clipboard via ADB shell input / clip command
          await _pushTextToPhone(desktopText);
          return;
        }
      }

      // 2. Poll Phone Clipboard (Android -> Linux)
      if (cfg.androidToLinux) {
        final phoneText = await _fetchPhoneClipboard();
        if (phoneText.isNotEmpty &&
            phoneText != _lastPhoneClipboard &&
            phoneText != _lastDesktopClipboard) {
          _lastPhoneClipboard = phoneText;
          await Clipboard.setData(ClipboardData(text: phoneText));
        }
      }
    } catch (_) {}
  }

  static Future<void> _pushTextToPhone(String text) async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      // Sanitize text for shell input
      final sanitized = text.replaceAll(RegExp(r'[^a-zA-Z0-9\s._\-/@:]'), '');
      if (sanitized.isNotEmpty) {
        await Process.run(adbPath, AdbDeviceScanner.getAdbArgs(['shell', 'input', 'text', sanitized]));
      }
    } catch (_) {}
  }

  static Future<String> _fetchPhoneClipboard() async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      final result = await Process.run(adbPath, AdbDeviceScanner.getAdbArgs(['shell', 'cmd', 'clipboard', 'get']));
      return result.stdout.toString().trim();
    } catch (_) {
      return '';
    }
  }
}
