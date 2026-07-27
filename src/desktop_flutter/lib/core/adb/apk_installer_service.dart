import 'dart:io';
import 'adb_device_scanner.dart';

class ApkInstallerService {
  /// Sideload and install an APK file onto the connected Android device
  static Future<bool> installApk(String apkFilePath) async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    final result = await Process.run(adbPath, ['install', '-r', apkFilePath]);
    return result.stdout.toString().contains('Success') || result.exitCode == 0;
  }
}
