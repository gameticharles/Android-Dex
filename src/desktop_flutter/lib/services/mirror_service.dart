import 'dart:io';

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

  /// Launch low-latency Scrcpy screen mirroring window
  static Future<Process?> launchScreenMirroring() async {
    final bin = await getScrcpyPath();
    final process = await Process.start(bin, [
      '--max-size=1280',
      '--video-bit-rate=8M',
      '--window-title=Android-Dex Screen Mirroring'
    ]);
    return process;
  }

  /// Launch a specific app inside scrcpy window
  static Future<Process?> launchAppMirror(String packageName, String title) async {
    // Kill previous instance if running
    await stopAppMirror(packageName);

    final bin = await getScrcpyPath();
    final args = [
      '--start-app=$packageName',
      '--window-title=$title',
      '--max-size=1280',
      '--video-bit-rate=8M',
    ];

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
