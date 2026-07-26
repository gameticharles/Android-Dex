import 'package:flutter/foundation.dart';
import '../services/real_adb_sync_service.dart';

/// Real-time state store for connected Android device.
class DeviceState {
  final ValueNotifier<int> batteryPercentage = ValueNotifier<int>(100);
  final ValueNotifier<bool> isCharging = ValueNotifier<bool>(false);
  final ValueNotifier<int> volumeMusic = ValueNotifier<int>(50);
  final ValueNotifier<String> wifiName = ValueNotifier<String>('Disconnected');
  final ValueNotifier<bool> isWifiEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBluetoothEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isTorchEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<String> deviceName = ValueNotifier<String>('Unknown Device');
  final ValueNotifier<String> deviceIp = ValueNotifier<String>('127.0.0.1');
  final ValueNotifier<String> connectionRoute = ValueNotifier<String>('USB ADB');
  final ValueNotifier<bool> isAdbConnected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isAppConnected = ValueNotifier<bool>(false);
  final ValueNotifier<List<RealNotificationItem>> notifications =
      ValueNotifier<List<RealNotificationItem>>([]);
  final ValueNotifier<RealMediaState> mediaState =
      ValueNotifier<RealMediaState>(const RealMediaState());

  void updateFromTelemetry(Map<String, dynamic> json) {
    if (json.containsKey('battery')) {
      final b = json['battery'];
      if (b is Map) {
        batteryPercentage.value = b['percentage'] ?? batteryPercentage.value;
        isCharging.value = b['charging'] ?? isCharging.value;
      }
    }

    if (json.containsKey('states')) {
      final s = json['states'];
      if (s is Map) {
        isWifiEnabled.value = s['wifi'] ?? isWifiEnabled.value;
        isBluetoothEnabled.value = s['bluetooth'] ?? isBluetoothEnabled.value;
        if (s['wifi_name'] != null) wifiName.value = s['wifi_name'];
      }
    }

    if (json.containsKey('media')) {
      final m = json['media'];
      if (m is Map) {
        mediaState.value = mediaState.value.copyWith(
          title: m['title']?.toString() ?? mediaState.value.title,
          artist: m['artist']?.toString() ?? mediaState.value.artist,
          album: m['album']?.toString() ?? mediaState.value.album,
          packageName: (m['package_name'] ?? m['packageName'])?.toString() ?? mediaState.value.packageName,
          isPlaying: (m['is_playing'] ?? m['isPlaying']) as bool? ?? mediaState.value.isPlaying,
          positionMs: (m['position_ms'] ?? m['positionMs']) as int? ?? mediaState.value.positionMs,
          durationMs: (m['duration_ms'] ?? m['durationMs']) as int? ?? mediaState.value.durationMs,
          artworkBase64: (m['artwork'] ?? m['artwork_base64'] ?? m['artworkBase64'])?.toString() ?? mediaState.value.artworkBase64,
          artworkUrl: (m['artwork_url'] ?? m['artworkUrl'])?.toString() ?? mediaState.value.artworkUrl,
        );
      }
    }
  }
}
