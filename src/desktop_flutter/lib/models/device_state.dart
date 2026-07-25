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
  }
}
