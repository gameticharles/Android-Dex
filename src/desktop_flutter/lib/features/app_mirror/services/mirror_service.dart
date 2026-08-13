import 'dart:io';
import 'package:adb_device_manager/features/settings/services/dex_settings_service.dart';

class MirrorService {
  static final Map<String, Process> _activeProcesses = {};

  static Future<String> getScrcpyPath() async {
    const scrcpyPath =
        '/home/charlesgameti/Documents/GitHub/Android-Dex/reengineering/linux_extracted/All helper_linux/platform-tools/scrcpy';
    if (await File(scrcpyPath).exists()) {
      await Process.run('chmod', ['+x', scrcpyPath]);
      return scrcpyPath;
    }
    return 'scrcpy';
  }

  /// Build dynamic scrcpy arguments based on DexSettingsService config
  static List<String> _buildScrcpyFlags({String? packageName, String? windowTitle}) {
    final cfg = DexSettingsService.notifier.value;
    final List<String> args = [];

    if (packageName != null && packageName.isNotEmpty) {
      args.add('--start-app=+$packageName');

      // Virtual Display Mode: Creates dedicated secondary display surface for the app
      if (cfg.appLaunchMode == 'Resizable APP mode') {
        args.add('--new-display=1440x900/220');
      } else if (cfg.appLaunchMode == 'Flex Display mode') {
        args.add('--new-display');
      } else {
        // Normal APP mode (standard mobile density)
        args.add('--new-display=1080x1920/280');
      }
    }
    if (windowTitle != null && windowTitle.isNotEmpty) {
      args.add('--window-title=$windowTitle');
    }

    // Video Resolution
    if (cfg.scrcpyMaxResolution != 'Native') {
      args.add('--max-size=${cfg.scrcpyMaxResolution}');
    }

    // Video Bitrate
    args.add('--video-bit-rate=${cfg.scrcpyBitrate}');

    // Framerate
    args.add('--max-fps=${cfg.scrcpyMaxFps}');

    // Video Codec / Encoder
    if (cfg.videoEncoder != 'Auto') {
      final enc = cfg.videoEncoder.toLowerCase();
      if (enc.contains('265') || enc.contains('hevc')) {
        args.add('--video-codec=h265');
      } else if (enc.contains('av1')) {
        args.add('--video-codec=av1');
      } else {
        args.add('--video-codec=h264');
      }
    }

    // Screen power & awake flags
    if (cfg.turnScreenOffOnMirror) {
      args.add('--turn-screen-off');
    }
    if (cfg.stayAwakeOnMirror) {
      args.add('--stay-awake');
    }

    // Audio Forwarding
    final isDesktopTarget = cfg.audioOutputTarget.toLowerCase().contains('dex') ||
        cfg.audioOutputTarget.toLowerCase().contains('linux') ||
        cfg.audioOutputTarget.toLowerCase().contains('desktop');

    if (!cfg.forwardAudio || !isDesktopTarget) {
      args.add('--no-audio');
    } else {
      args.add('--audio-source=output');
      args.add('--audio-buffer=50');
      args.add('--audio-codec=opus');
    }

    return args;
  }

  /// Launch low-latency Scrcpy screen mirroring window
  static Future<Process?> launchScreenMirroring() async {
    final bin = await getScrcpyPath();
    final args = _buildScrcpyFlags(windowTitle: 'Android-Dex Screen Mirroring');
    final process = await Process.start(bin, args);
    return process;
  }

  /// Launch a specific app inside scrcpy window
  static Future<Process?> launchAppMirror(String packageName, String title) async {
    // Kill previous instance if running
    await stopAppMirror(packageName);

    final bin = await getScrcpyPath();
    final args = _buildScrcpyFlags(packageName: packageName, windowTitle: title);

    try {
      final process = await Process.start(bin, args);
      _activeProcesses[packageName] = process;

      process.exitCode.then((_) {
        _activeProcesses.remove(packageName);
      });

      return process;
    } catch (e) {
      return null;
    }
  }

  /// Kill process for a specific package name
  static Future<void> stopAppMirror(String packageName) async {
    final proc = _activeProcesses[packageName];
    if (proc != null) {
      proc.kill(ProcessSignal.sigterm);
      _activeProcesses.remove(packageName);
    }
  }

  /// Check if app is running
  static bool isAppMirrorRunning(String packageName) {
    return _activeProcesses.containsKey(packageName);
  }
}
