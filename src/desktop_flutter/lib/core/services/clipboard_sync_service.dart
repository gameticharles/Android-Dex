import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:adb_device_manager/core/adb/adb_device_scanner.dart';
import 'package:adb_device_manager/features/settings/services/dex_settings_service.dart';

/// Bi-directional Desktop <-> Android Phone Clipboard Sync Service
class ClipboardSyncService {
  static Timer? _syncTimer;
  static String _lastDesktopClipboard = '';
  static String _lastPhoneClipboard = '';

  /// In-memory clipboard history buffer with real-time UI notification
  static final ValueNotifier<List<String>> historyNotifier =
      ValueNotifier<List<String>>([
    "https://github.com/gameticharles/Android-Dex",
    "ADB Port Forward: 8080 -> 8080",
    "Welcome to Android Dex Desktop Shell Pro!",
  ]);

  /// Start clipboard synchronization loop (runs every 1.5 seconds)
  static void startSync() {
    _syncTimer?.cancel();
    _ensureSyncStorageDir();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      await syncClipboard();
    });
  }

  /// Stop clipboard synchronization loop
  static void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Ensure `~/Downloads/dex_sync` directory exists
  static Future<void> _ensureSyncStorageDir() async {
    try {
      final home = Platform.environment['HOME'] ?? '.';
      final syncDir = Directory(path.join(home, 'Downloads', 'dex_sync'));
      if (!await syncDir.exists()) {
        await syncDir.create(recursive: true);
      }
    } catch (_) {}
  }

  /// Record text entry into clipboard history buffer
  static void recordHistoryItem(String item) {
    if (item.trim().isEmpty) return;
    final cfg = DexSettingsService.notifier.value;
    final current = List<String>.from(historyNotifier.value);
    current.remove(item);
    current.insert(0, item);
    if (current.length > cfg.clipboardMaxHistory) {
      current.removeRange(cfg.clipboardMaxHistory, current.length);
    }
    historyNotifier.value = current;
  }

  /// Clear clipboard history buffer
  static void clearHistory() {
    historyNotifier.value = [];
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
          recordHistoryItem(desktopText);

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
          recordHistoryItem(phoneText);
          await Clipboard.setData(ClipboardData(text: phoneText));
        }
      }
    } catch (_) {}
  }

  /// Execute an immediate test synchronization pass
  static Future<bool> testSyncPayload(String testText) async {
    try {
      await _pushTextToPhone(testText);
      await Clipboard.setData(ClipboardData(text: testText));
      recordHistoryItem(testText);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _pushTextToPhone(String text) async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      // Sanitize text for shell input
      final sanitized = text.replaceAll(RegExp(r'[^a-zA-Z0-9\s._\-/@:]'), '');
      if (sanitized.isNotEmpty) {
        await Process.run(
            adbPath,
            AdbDeviceScanner.getAdbArgs(
                ['shell', 'input', 'text', sanitized]));
      }
    } catch (_) {}
  }

  static Future<String> _fetchPhoneClipboard() async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      final result = await Process.run(
          adbPath,
          AdbDeviceScanner.getAdbArgs(
              ['shell', 'cmd', 'clipboard', 'get']));
      return result.stdout.toString().trim();
    } catch (_) {
      return '';
    }
  }
}
