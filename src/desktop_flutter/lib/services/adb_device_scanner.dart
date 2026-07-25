import 'dart:async';
import 'dart:io';
import '../models/device_state.dart';
import 'real_adb_sync_service.dart';

class RealDevice {
  final String serial;
  final String model;
  final String product;
  final bool isWireless;

  RealDevice({
    required this.serial,
    required this.model,
    required this.product,
    required this.isWireless,
  });

  String get connectionType => isWireless ? "Wireless ADB" : "USB ADB";
}

class DiscoveredWirelessDevice {
  final String ipAddress;
  final int port;
  final String name;
  final String serviceType;

  DiscoveredWirelessDevice({
    required this.ipAddress,
    required this.port,
    required this.name,
    required this.serviceType,
  });

  String get fullAddress => '$ipAddress:$port';
}

/// Service to detect and link real Android devices via ADB binary.
class AdbDeviceScanner {
  static String? _adbExecutablePath;

  /// Find ADB binary path (check bundled helper first, then system PATH)
  static Future<String> getAdbPath() async {
    if (_adbExecutablePath != null) return _adbExecutablePath!;

    const bundledPath = '/home/charlesgameti/Documents/GitHub/Android-Dex/reengineering/linux_extracted/All helper_linux/platform-tools/adb';
    if (await File(bundledPath).exists()) {
      _adbExecutablePath = bundledPath;
      return bundledPath;
    }

    _adbExecutablePath = 'adb';
    return 'adb';
  }

  /// Scan for connected real ADB devices (detects USB vs Wireless IP:Port)
  static Future<List<RealDevice>> scanDevices() async {
    final adbPath = await getAdbPath();
    final result = await Process.run(adbPath, ['devices', '-l']);
    final lines = result.stdout.toString().split('\n');

    final List<RealDevice> devices = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('List of devices attached')) {
        continue;
      }

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[1] == 'device') {
        final serial = parts[0];
        final isWireless = serial.contains(':') || RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(serial);
        String model = isWireless ? 'Wireless Device ($serial)' : 'Android Device';
        String product = 'Unknown';

        for (final p in parts) {
          if (p.startsWith('model:')) model = p.substring(6).replaceAll('_', ' ');
          if (p.startsWith('product:')) product = p.substring(8);
        }

        devices.add(RealDevice(
          serial: serial,
          model: model,
          product: product,
          isWireless: isWireless,
        ));
      }
    }

    return devices;
  }

  /// Scan local Wi-Fi network for broadcasting Wireless ADB devices (mDNS & Subnet Probe)
  static Future<List<DiscoveredWirelessDevice>> scanWirelessAdbServices() async {
    final List<DiscoveredWirelessDevice> discovered = [];

    try {
      final adbPath = await getAdbPath();
      final mdnsResult = await Process.run(adbPath, ['mdns', 'services']).timeout(const Duration(seconds: 2));
      final lines = mdnsResult.stdout.toString().split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('List of discovered')) continue;

        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final serviceType = parts[0];
          final addr = parts[1];

          if (addr.contains(':')) {
            final addrParts = addr.split(':');
            final ip = addrParts[0];
            final port = int.tryParse(addrParts[1]) ?? 5555;
            final name = parts.length >= 3 ? parts[2] : 'Android Device ($ip)';

            if (!discovered.any((d) => d.ipAddress == ip && d.port == port)) {
              discovered.add(DiscoveredWirelessDevice(
                ipAddress: ip,
                port: port,
                name: name,
                serviceType: serviceType,
              ));
            }
          }
        }
      }
    } catch (_) {}

    // Subnet Socket probe fallback for local network
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            final ipPrefix = addr.address.substring(0, addr.address.lastIndexOf('.'));
            
            // Probe common local IPs for Wireless ADB port 5555
            final probeFutures = <Future<Socket?>>[];
            for (int i = 1; i <= 254; i++) {
              final targetIp = '$ipPrefix.$i';
              if (targetIp == addr.address) continue;

              probeFutures.add(
                Socket.connect(targetIp, 5555, timeout: const Duration(milliseconds: 120))
                    .then((sock) {
                      sock.destroy();
                      return null;
                    })
                    .catchError((_) => null),
              );
            }
          }
        }
      }
    } catch (_) {}

    return discovered;
  }

  /// Connect to a wireless ADB device via IP and Port (e.g., 192.168.1.105:5555)
  static Future<bool> connectWirelessDevice(String ipAddress, {int port = 5555}) async {
    try {
      final adbPath = await getAdbPath();
      final target = ipAddress.contains(':') ? ipAddress : '$ipAddress:$port';
      final result = await Process.run(adbPath, ['connect', target]);
      final out = result.stdout.toString();
      return out.contains('connected to') || out.contains('already connected');
    } catch (_) {
      return false;
    }
  }

  /// Sync real device state (battery level, model, device serial)
  static Future<void> syncRealDeviceTelemetry(String serial, DeviceState state) async {
    final adbPath = await getAdbPath();

    // 1. Fetch real device model
    final modelRes = await Process.run(adbPath, ['-s', serial, 'shell', 'getprop', 'ro.product.model']);
    final realModel = modelRes.stdout.toString().trim();
    if (realModel.isNotEmpty) {
      state.deviceName.value = realModel;
    }

    // 2. Fetch real battery level
    final batteryRes = await Process.run(adbPath, ['-s', serial, 'shell', 'dumpsys', 'battery']);
    final batteryLines = batteryRes.stdout.toString().split('\n');

    for (final line in batteryLines) {
      final t = line.trim();
      if (t.startsWith('level:')) {
        final level = int.tryParse(t.substring(6).trim());
        if (level != null) state.batteryPercentage.value = level;
      }
      if (t.startsWith('powered:') || t.startsWith('AC powered:')) {
        if (t.contains('true')) state.isCharging.value = true;
      }
    }

    // 4. Fetch real push notifications & real media state
    final notifs = await RealAdbSyncService.fetchRealNotifications();
    state.notifications.value = notifs;

    final media = await RealAdbSyncService.fetchRealMediaState();
    state.mediaState.value = media;

    state.deviceIp.value = serial;
    state.isAdbConnected.value = true;
  }
}
