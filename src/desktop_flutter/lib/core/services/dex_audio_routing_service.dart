import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:adb_device_manager/core/adb/adb_device_scanner.dart';
import 'package:adb_device_manager/features/settings/services/dex_settings_service.dart';
import 'package:adb_device_manager/features/app_mirror/services/mirror_service.dart';

/// Manages real-time audio routing between Android device, Dex Speaker (Linux PC),
/// and Bluetooth output endpoints.
class DexAudioRoutingService {
  static const String androidSpeaker = "Android Speaker";
  static const String dexSpeaker = "Dex Speaker";
  static const String bluetooth = "Bluetooth Device";

  static final ValueNotifier<String> activeDestinationNotifier =
      ValueNotifier<String>(androidSpeaker);
  static final ValueNotifier<bool> isStreamingNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<String?> routingStatusNotifier =
      ValueNotifier<String?>(null);

  static Process? _audioForwardProcess;
  static bool _isInitialized = false;

  /// Initialize state from persistent DexSettings
  static void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    final target = DexSettingsService.notifier.value.audioOutputTarget;
    activeDestinationNotifier.value = normalizeDestination(target);

    // Listen to changes in DexSettings
    DexSettingsService.notifier.addListener(() {
      final currentSetting = DexSettingsService.notifier.value.audioOutputTarget;
      final normalized = normalizeDestination(currentSetting);
      if (activeDestinationNotifier.value != normalized) {
        activeDestinationNotifier.value = normalized;
      }
    });
  }

  /// Normalize various UI labels to canonical audio destinations
  static String normalizeDestination(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('dex') || lower.contains('linux') || lower.contains('desktop')) {
      return dexSpeaker;
    }
    if (lower.contains('bluetooth')) {
      return bluetooth;
    }
    return androidSpeaker;
  }

  /// Switch the active audio destination in real-time
  static Future<bool> switchAudioDestination(String rawTarget, {String? serial}) async {
    final destination = normalizeDestination(rawTarget);
    activeDestinationNotifier.value = destination;

    final cfg = DexSettingsService.notifier.value;

    if (destination == dexSpeaker) {
      // 1. Forward audio to Dex Speaker / Linux PC
      final success = await _startAudioForwarding(serial: serial);
      if (success) {
        DexSettingsService.update(cfg.copyWith(
          audioOutputTarget: dexSpeaker,
          forwardAudio: true,
        ));
        routingStatusNotifier.value = "Audio routed to Dex Desktop Speaker ✓";
        return true;
      } else {
        routingStatusNotifier.value = "Failed to start audio forwarding to Dex Speaker.";
        return false;
      }
    } else {
      // 2. Route back to Android Phone Speaker or Bluetooth
      await stopAudioForwarding();

      final isBt = destination == bluetooth;
      DexSettingsService.update(cfg.copyWith(
        audioOutputTarget: isBt ? bluetooth : androidSpeaker,
        forwardAudio: false,
      ));

      routingStatusNotifier.value = isBt
          ? "Audio routed to Bluetooth Device"
          : "Audio routed to Android Phone Speaker";
      return true;
    }
  }

  /// Launch low-latency background audio forwarding pipeline via Scrcpy
  static Future<bool> _startAudioForwarding({String? serial}) async {
    await stopAudioForwarding();

    try {
      final scrcpyPath = await MirrorService.getScrcpyPath();

      // Determine serial if not provided
      String? targetSerial = serial;
      if (targetSerial == null || targetSerial.isEmpty) {
        final devices = await AdbDeviceScanner.scanDevices();
        if (devices.isNotEmpty) {
          targetSerial = devices.first.serial;
        }
      }

      final List<String> args = [
        '--no-video',
        '--no-window',
        '--audio-source=output',
        '--audio-buffer=50',
        '--audio-codec=opus',
      ];

      if (targetSerial != null && targetSerial.isNotEmpty) {
        args.addAll(['-s', targetSerial]);
      }

      debugPrint('DexAudioRoutingService: Starting scrcpy audio forwarder with args: $args');
      final process = await Process.start(scrcpyPath, args);
      _audioForwardProcess = process;
      isStreamingNotifier.value = true;

      // Handle termination
      process.exitCode.then((code) {
        debugPrint('DexAudioRoutingService: Scrcpy audio process exited with code $code');
        if (_audioForwardProcess == process) {
          _audioForwardProcess = null;
          isStreamingNotifier.value = false;
        }
      });

      return true;
    } catch (e) {
      debugPrint('DexAudioRoutingService: Error starting audio forwarder: $e');
      _audioForwardProcess = null;
      isStreamingNotifier.value = false;
      return false;
    }
  }

  /// Stop active standalone audio forwarding process
  static Future<void> stopAudioForwarding() async {
    final proc = _audioForwardProcess;
    if (proc != null) {
      debugPrint('DexAudioRoutingService: Stopping standalone audio forwarder...');
      proc.kill(ProcessSignal.sigterm);
      _audioForwardProcess = null;
      isStreamingNotifier.value = false;
    }
  }

  /// Direct ADB stream volume helper
  static Future<void> setStreamVolume(int streamType, double value) async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      final volInt = (value * 15).toInt().clamp(0, 15);
      await Process.run(
          adbPath, ['shell', 'cmd', 'audio', 'set-stream-volume', '$streamType', '$volInt']);
    } catch (e) {
      debugPrint('DexAudioRoutingService: Error setting stream volume: $e');
    }
  }

  /// Direct ADB ringer mode helper (0: mute, 1: vibrate, 2: normal)
  static Future<void> setRingerMode(int mode) async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      await Process.run(adbPath, ['shell', 'cmd', 'audio', 'set-ringer-mode', '$mode']);
    } catch (e) {
      debugPrint('DexAudioRoutingService: Error setting ringer mode: $e');
    }
  }
}
