import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
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

class AppLauncherService {
  static final Map<String, String> _iconCache = {};
  static final Map<String, Future<String?>> _pendingIconRequests = {};
  static List<InstalledApp>? _cachedAppsList;

  /// Synchronous getter for cached app icon URL
  static String? getCachedIconUrl(String pkg) => _iconCache[pkg];

  /// Fetch all installed third-party apps with persistent in-memory caching
  static Future<List<InstalledApp>> fetchInstalledApps({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedAppsList != null && _cachedAppsList!.isNotEmpty) {
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
          label = label[0].toUpperCase() + label.substring(1);

          if (label == 'Frontpage') label = 'Reddit';
          if (label == 'Gpsstatus2') label = 'GPS Status';
          if (label == 'Music') label = 'Samsung Music';
          if (label == 'Calendar') label = 'Google Calendar';

          final iconUrl = _iconCache[pkg];
          apps.add(InstalledApp(packageName: pkg, label: label, iconUrl: iconUrl));
        }
      }

      _cachedAppsList = apps;
      return apps;
    } catch (_) {
      return _cachedAppsList ?? [];
    }
  }

  /// Resolve real app icon URL from package name with request deduplication & timeout
  static Future<String?> getIconUrlForPackage(String pkg) async {
    if (_iconCache.containsKey(pkg)) return _iconCache[pkg];
    if (_pendingIconRequests.containsKey(pkg)) return _pendingIconRequests[pkg];

    final completer = Completer<String?>();
    final future = completer.future;
    _pendingIconRequests[pkg] = future;

    _fetchIconUrlFromWeb(pkg).then((url) {
      if (url != null) {
        _iconCache[pkg] = url;
      }
      _pendingIconRequests.remove(pkg);
      completer.complete(url);
    }).catchError((_) {
      _pendingIconRequests.remove(pkg);
      completer.complete(null);
    });

    return future;
  }

  static Future<String?> _fetchIconUrlFromWeb(String pkg) async {
    try {
      final uri = Uri.parse('https://play.google.com/store/apps/details?id=$pkg');
      final res = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      }).timeout(const Duration(milliseconds: 1500));

      if (res.statusCode == 200) {
        final regExp = RegExp(r'https://play-lh\.googleusercontent\.com/[^\s"]+');
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
    await Process.run(adbPath, ['shell', 'input', 'keyevent', keyCode.toString()]);
  }
}
