import 'dart:io';
import 'dart:math';

/// Manages local DEX Desktop Identity (Client ID and Computer Hostname).
class DesktopIdentityService {
  static String? _cachedId;
  static String? _cachedHostname;
  static String? _activeAuthToken;

  static String? get activeAuthToken => _activeAuthToken;
  static set activeAuthToken(String? token) => _activeAuthToken = token;
  static String? get cachedId => _cachedId;

  static Future<String> getDeviceId() async {
    if (_cachedId != null) return _cachedId!;
    try {
      final file = File('.dex_desktop_id');
      if (await file.exists()) {
        final content = (await file.readAsString()).trim();
        if (content.isNotEmpty) {
          _cachedId = content;
          return content;
        }
      }
      final newId = _generateRandomUuid();
      await file.writeAsString(newId);
      _cachedId = newId;
      return newId;
    } catch (_) {
      final fallbackId = _generateRandomUuid();
      _cachedId = fallbackId;
      return fallbackId;
    }
  }

  static String getComputerName() {
    if (_cachedHostname != null) return _cachedHostname!;
    try {
      final name = Platform.localHostname;
      if (name.isNotEmpty && name != 'localhost') {
        _cachedHostname = name;
        return name;
      }
      final envName = Platform.environment['HOSTNAME'] ??
          Platform.environment['COMPUTERNAME'];
      if (envName != null && envName.isNotEmpty) {
        _cachedHostname = envName;
        return envName;
      }
    } catch (_) {}
    _cachedHostname = 'DEX Desktop PC';
    return 'DEX Desktop PC';
  }

  static String _generateRandomUuid() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
