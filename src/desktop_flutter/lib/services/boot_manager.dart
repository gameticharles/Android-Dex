import 'dart:io';
import 'package:crypto/crypto.dart';
import 'adb_device_scanner.dart';

/// Performance-Optimized Boot Manager with MD5 Hash Caching & Parallel Steps.
class BootManager {
  final String deviceIp;
  final Function(double progress, String status) onProgress;

  BootManager({required this.deviceIp, required this.onProgress});

  Future<bool> executeBootProtocol({
    required String localJarPath,
    required String remoteJarPath,
    required String companionPackage,
  }) async {
    try {
      // Step 1: Connect ADB
      onProgress(0.10, "Connecting to Android device...");
      await _runAdb(['connect', deviceIp]);

      // Step 2: Reverse Port Forwarding
      onProgress(0.20, "Configuring reverse ports (38947, 4567)...");
      await _runAdb(['reverse', 'tcp:38947', 'tcp:38947']);
      await _runAdb(['reverse', 'tcp:4567', 'tcp:4567']);

      // Step 3 & 4: PARALLEL EXECUTION (Performance Fix #2)
      // Concurrently check JAR hash and package status
      onProgress(0.38, "Verifying JAR binary and companion app...");
      final results = await Future.wait([
        _shouldPushJar(localJarPath, remoteJarPath),
        _isPackageInstalled(companionPackage),
      ]);

      final bool needsJarPush = results[0];
      final bool isAppInstalled = results[1];

      if (needsJarPush) {
        onProgress(0.48, "Deploying Logic Engine JAR...");
        await _runAdb(['push', localJarPath, remoteJarPath]);
        await _saveJarHashCache(localJarPath);
      } else {
        onProgress(0.48, "Logic Engine up-to-date (cached) ✓");
      }

      // Step 5: Launch Companion App if installed
      if (isAppInstalled) {
        onProgress(0.72, "Starting companion services...");
        await _runAdb([
          'shell',
          'am', 'startservice',
          '-n', '$companionPackage/.InitializationService'
        ]);
      }

      // Step 6: Final Handshake
      onProgress(0.93, "Waiting for system handshake...");
      await Future.delayed(const Duration(milliseconds: 300));

      onProgress(1.00, "System Ready");
      return true;
    } catch (e) {
      onProgress(0.00, "Boot Failed: $e");
      return false;
    }
  }

  /// Performance Fix #1: MD5 Hash Caching
  Future<bool> _shouldPushJar(String localPath, String remotePath) async {
    final localFile = File(localPath);
    if (!await localFile.exists()) return false;

    final bytes = await localFile.readAsBytes();
    final localMd5 = md5.convert(bytes).toString();

    // 1. Check local hash cache
    final cacheFile = File('.jar_hash.cache');
    if (await cacheFile.exists()) {
      final cached = (await cacheFile.readAsString()).trim();
      if (cached == localMd5) {
        return false; // Hash matches cache, skip expensive ADB push!
      }
    }

    // 2. Fallback check via ADB
    final result = await _runAdb(['shell', 'md5sum', remotePath]);
    if (result.contains(localMd5)) {
      await cacheFile.writeAsString(localMd5);
      return false;
    }

    return true; // Push required
  }

  Future<void> _saveJarHashCache(String localPath) async {
    final bytes = await File(localPath).readAsBytes();
    final localMd5 = md5.convert(bytes).toString();
    await File('.jar_hash.cache').writeAsString(localMd5);
  }

  Future<bool> _isPackageInstalled(String pkg) async {
    final out = await _runAdb(['shell', 'pm', 'list', 'packages', pkg]);
    return out.contains(pkg);
  }

  Future<String> _runAdb(List<String> args) async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    final result = await Process.run(adbPath, args);
    return result.stdout.toString();
  }
}
