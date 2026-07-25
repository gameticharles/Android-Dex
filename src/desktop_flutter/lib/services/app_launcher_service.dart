import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'adb_device_scanner.dart';

class InstalledApp {
  final String packageName;
  final String label;
  String? iconUrl;

  InstalledApp({
    required this.packageName,
    required this.label,
    this.iconUrl,
  });
}

class AppIconSyncProgress {
  final int totalApps;
  final int syncedApps;
  final bool isSyncing;

  const AppIconSyncProgress({
    this.totalApps = 0,
    this.syncedApps = 0,
    this.isSyncing = false,
  });

  bool get isComplete => totalApps > 0 && syncedApps >= totalApps;
  double get progressPercentage =>
      totalApps > 0 ? (syncedApps / totalApps).clamp(0.0, 1.0) : 0.0;
}

class AppLauncherService {
  static final Map<String, String> _iconCache = {};
  static final Map<String, Future<String?>> _pendingIconRequests = {};
  static List<InstalledApp>? _cachedAppsList;
  static Directory? _cacheDir;

  /// Global Notifiers for icon sync progress & individual cache updates
  static final ValueNotifier<AppIconSyncProgress> iconSyncProgress =
      ValueNotifier(const AppIconSyncProgress());
  static final ValueNotifier<int> iconCacheUpdateNotifier = ValueNotifier(0);

  /// Synchronous getter for cached app icon URL or local file path
  static String? getCachedIconUrl(String pkg) => _iconCache[pkg];

  /// Internal cache directory getter
  static Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final dir = Directory(path.join(home, '.dex_icon_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  /// Fetch all installed third-party apps with persistent caching & icon sync
  static Future<List<InstalledApp>> fetchInstalledApps(
      {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedAppsList != null &&
        _cachedAppsList!.isNotEmpty) {
      return _cachedAppsList!;
    }

    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      final result =
          await Process.run(adbPath, ['shell', 'pm', 'list', 'packages', '-3']);
      final lines = result.stdout.toString().split('\n');

      final List<InstalledApp> apps = [];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('package:')) {
          final pkg = trimmed.substring(8);
          String label = pkg.split('.').last;
          if (label.isNotEmpty) {
            label = label[0].toUpperCase() + label.substring(1);
          }

          if (label == 'Frontpage') label = 'Reddit';
          if (label == 'Gpsstatus2') label = 'GPS Status';
          if (label == 'Music') label = 'Samsung Music';
          if (label == 'Calendar') label = 'Google Calendar';

          final iconUrl = _iconCache[pkg];
          apps.add(
              InstalledApp(packageName: pkg, label: label, iconUrl: iconUrl));
        }
      }

      _cachedAppsList = apps;
      _initIconSync(apps);
      return apps;
    } catch (_) {
      return _cachedAppsList ?? [];
    }
  }

  /// Initialize background icon sync and update iconSyncProgress state
  static void _initIconSync(List<InstalledApp> apps) async {
    final cacheDir = await _getCacheDirectory();
    int initialSynced = 0;

    for (final app in apps) {
      if (_iconCache.containsKey(app.packageName)) {
        initialSynced++;
        continue;
      }
      final localFile =
          File(path.join(cacheDir.path, '${app.packageName}.png'));
      if (localFile.existsSync()) {
        _iconCache[app.packageName] = localFile.path;
        app.iconUrl = localFile.path;
        initialSynced++;
      }
    }

    iconSyncProgress.value = AppIconSyncProgress(
      totalApps: apps.length,
      syncedApps: initialSynced,
      isSyncing: initialSynced < apps.length,
    );

    if (initialSynced < apps.length) {
      _startBackgroundIconSync(apps);
    }
  }

  /// Background sync loop for resolving app icons
  static void _startBackgroundIconSync(List<InstalledApp> apps) async {
    int syncedCount = iconSyncProgress.value.syncedApps;

    for (final app in apps) {
      if (!_iconCache.containsKey(app.packageName)) {
        final iconPath = await getIconUrlForPackage(app.packageName);
        if (iconPath != null) {
          app.iconUrl = iconPath;
        }
        syncedCount++;
        iconSyncProgress.value = AppIconSyncProgress(
          totalApps: apps.length,
          syncedApps: syncedCount,
          isSyncing: syncedCount < apps.length,
        );
      }
    }

    iconSyncProgress.value = AppIconSyncProgress(
      totalApps: apps.length,
      syncedApps: apps.length,
      isSyncing: false,
    );
  }

  /// Resolve app icon URL or disk path with deduplication, disk persistence, & listener notification
  static Future<String?> getIconUrlForPackage(String pkg) async {
    if (_iconCache.containsKey(pkg)) return _iconCache[pkg];
    if (_pendingIconRequests.containsKey(pkg)) return _pendingIconRequests[pkg];

    // Check disk cache first
    try {
      final cacheDir = await _getCacheDirectory();
      final localFile = File(path.join(cacheDir.path, '$pkg.png'));
      if (await localFile.exists() && (await localFile.length()) > 0) {
        _iconCache[pkg] = localFile.path;
        iconCacheUpdateNotifier.value++;
        return localFile.path;
      }
    } catch (_) {}

    final completer = Completer<String?>();
    final future = completer.future;
    _pendingIconRequests[pkg] = future;

    _fetchAndStoreIcon(pkg).then((resPath) {
      if (resPath != null) {
        _iconCache[pkg] = resPath;
        iconCacheUpdateNotifier.value++;
      }
      _pendingIconRequests.remove(pkg);
      completer.complete(resPath);
    }).catchError((_) {
      _pendingIconRequests.remove(pkg);
      completer.complete(null);
    });

    return future;
  }

  static Future<String?> _fetchAndStoreIcon(String pkg) async {
    // Primary: Extract icon directly from connected Android device via ADB
    final deviceIconPath = await _fetchIconFromAdbDevice(pkg);
    if (deviceIconPath != null) return deviceIconPath;

    // Secondary Fallback: Fetch from web Play Store if device extraction returns no raster PNG
    final webUrl = await _fetchIconUrlFromWeb(pkg);
    if (webUrl == null) return null;

    try {
      final cacheDir = await _getCacheDirectory();
      final localFile = File(path.join(cacheDir.path, '$pkg.png'));

      final response =
          await http.get(Uri.parse(webUrl)).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await localFile.writeAsBytes(response.bodyBytes);
        return localFile.path;
      }
    } catch (_) {}

    // Fall back to web URL if disk writing failed
    return webUrl;
  }

  /// Extract app launcher PNG directly from connected Android device via ADB
  static Future<String?> _fetchIconFromAdbDevice(String pkg) async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();

      // 1. Locate APK path on device
      final pmResult = await Process.run(
          adbPath, ['shell', 'pm', 'list', 'packages', '-f', pkg]);
      final pmStdout = pmResult.stdout.toString();

      String? apkPath;
      for (final line in pmStdout.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.contains('=$pkg')) {
          final startIdx = trimmed.indexOf(':') + 1;
          final endIdx = trimmed.lastIndexOf('=');
          if (startIdx > 0 && endIdx > startIdx) {
            apkPath = trimmed.substring(startIdx, endIdx).trim();
            break;
          }
        }
      }

      if (apkPath == null || apkPath.isEmpty) return null;

      // 2. List PNG files inside APK archive via ADB shell unzip
      final listResult =
          await Process.run(adbPath, ['shell', 'unzip', '-l', apkPath]);
      final listStdout = listResult.stdout.toString();

      String? bestIconPath;
      int highestResPriority = -1;

      final lines = listStdout.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.endsWith('.png')) continue;

        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length < 4) continue;
        final entryPath = parts.last;

        int priority = -1;
        if (entryPath.contains('ic_launcher') ||
            entryPath.contains('icon') ||
            entryPath.contains('app_icon')) {
          priority = 10;
          if (entryPath.contains('xxxhdpi')) {
            priority += 50;
          } else if (entryPath.contains('xxhdpi')) {
            priority += 40;
          } else if (entryPath.contains('xhdpi')) {
            priority += 30;
          } else if (entryPath.contains('hdpi')) {
            priority += 20;
          } else if (entryPath.contains('mdpi')) {
            priority += 10;
          }

          if (entryPath.contains('mipmap')) priority += 15;
        }

        if (priority > highestResPriority) {
          highestResPriority = priority;
          bestIconPath = entryPath;
        }
      }

      if (bestIconPath == null) return null;

      // 3. Extract raw binary PNG bytes via adb shell unzip -p
      final extractResult = await Process.run(
        adbPath,
        ['shell', 'unzip', '-p', apkPath, bestIconPath],
        stdoutEncoding: null,
      );

      if (extractResult.exitCode == 0 && extractResult.stdout is List<int>) {
        final bytes = extractResult.stdout as List<int>;
        if (bytes.isNotEmpty) {
          final cacheDir = await _getCacheDirectory();
          final localFile = File(path.join(cacheDir.path, '$pkg.png'));
          await localFile.writeAsBytes(bytes);
          return localFile.path;
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<String?> _fetchIconUrlFromWeb(String pkg) async {
    try {
      final uri =
          Uri.parse('https://play.google.com/store/apps/details?id=$pkg');
      final res = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }).timeout(const Duration(milliseconds: 1500));

      if (res.statusCode == 200) {
        final regExp =
            RegExp(r'https://play-lh\.googleusercontent\.com/[^\s"]+');
        final match = regExp.firstMatch(res.body);
        if (match != null) {
          return match.group(0);
        }
      }
    } catch (_) {}

    return null;
  }

  /// Launch an app remotely on the connected Android device
  static Future<void> launchApp(String packageName) async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    await Process.run(adbPath, [
      'shell',
      'monkey',
      '-p',
      packageName,
      '-c',
      'android.intent.category.LAUNCHER',
      '1'
    ]);
  }

  /// Trigger navigation actions
  static Future<void> sendKeyEvent(int keyCode) async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    await Process.run(
        adbPath, ['shell', 'input', 'keyevent', keyCode.toString()]);
  }
}
