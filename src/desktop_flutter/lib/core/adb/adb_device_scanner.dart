import 'dart:async';
import 'dart:io';
import 'package:adb_device_manager/core/models/device_state.dart';
import 'package:adb_device_manager/core/adb/real_adb_sync_service.dart';
import 'package:adb_device_manager/features/wireless_adb/services/pairing_service.dart';

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
  static String? activeSerial;

  /// Injects '-s <activeSerial>' into ADB command arguments when activeSerial is present.
  static List<String> getAdbArgs(List<String> args) {
    final s = activeSerial;
    if (s != null && s.isNotEmpty) {
      if (args.isEmpty || args[0] != '-s') {
        return ['-s', s, ...args];
      }
    }
    return args;
  }

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

  /// Scan for connected real ADB devices (USB & automatically discovered Wireless network devices)
  static Future<List<RealDevice>> scanDevices({bool includeNetworkWireless = true}) async {
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

    // Automatically scan Wi-Fi network for broadcasting/open Wireless ADB devices
    if (includeNetworkWireless) {
      try {
        final wirelessDiscovered = await scanWirelessAdbServices();
        for (final w in wirelessDiscovered) {
          final targetSerial = '${w.ipAddress}:${w.port}';
          final exists = devices.any((d) => d.serial == targetSerial || d.serial.startsWith(w.ipAddress));
          if (!exists) {
            devices.add(RealDevice(
              serial: targetSerial,
              model: w.name.isNotEmpty ? w.name : 'Wireless Device (${w.ipAddress})',
              product: 'Wi-Fi Network',
              isWireless: true,
            ));
          }
        }
      } catch (_) {}
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

    // Subnet Socket probe fallback for local network (probing port 5555)
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            final ipPrefix = addr.address.substring(0, addr.address.lastIndexOf('.'));
            
            final probeFutures = <Future<String?>>[];
            for (int i = 1; i <= 254; i++) {
              final targetIp = '$ipPrefix.$i';
              if (targetIp == addr.address) continue;

              probeFutures.add(
                Socket.connect(targetIp, 5555, timeout: const Duration(milliseconds: 150))
                    .then<String?>((sock) {
                      sock.destroy();
                      return targetIp;
                    })
                    .catchError((_) => null),
              );
            }

            final probeResults = await Future.wait(probeFutures);
            for (final ip in probeResults) {
              if (ip != null && !discovered.any((d) => d.ipAddress == ip)) {
                discovered.add(DiscoveredWirelessDevice(
                  ipAddress: ip,
                  port: 5555,
                  name: 'Wireless Device ($ip)',
                  serviceType: '_adb._tcp',
                ));
              }
            }
          }
        }
      }
    } catch (_) {}

    return discovered;
  }

  /// Enable Wireless TCP/IP mode on a connected device (e.g. adb -s <serial> tcpip 5555)
  static Future<bool> enableTcpipMode(String serial, {int port = 5555}) async {
    try {
      final adbPath = await getAdbPath();
      final result = await Process.run(adbPath, ['-s', serial, 'tcpip', '$port']);
      final out = result.stdout.toString().toLowerCase();
      return out.contains('restarting in tcpip mode') || out.contains('restarting in tcp mode') || out.contains('port: 5555');
    } catch (_) {
      return false;
    }
  }

  /// Resolve local Wi-Fi IP address of an Android device
  static Future<String?> getDeviceWifiAddress(String serial) async {
    try {
      final adbPath = await getAdbPath();
      final res = await Process.run(adbPath, ['-s', serial, 'shell', 'ip', '-f', 'inet', 'addr', 'show', 'wlan0']);
      final stdout = res.stdout.toString();
      final match = RegExp(r'inet\s+(\d+\.\d+\.\d+\.\d+)').firstMatch(stdout);
      if (match != null) {
        return match.group(1);
      }

      // Fallback via ip route
      final routeRes = await Process.run(adbPath, ['-s', serial, 'shell', 'ip', 'route']);
      final routeStdout = routeRes.stdout.toString();
      final routeMatch = RegExp(r'src\s+(\d+\.\d+\.\d+\.\d+)').firstMatch(routeStdout);
      if (routeMatch != null) {
        return routeMatch.group(1);
      }
    } catch (_) {}
    return null;
  }

  /// Pair a wireless ADB device using Android 11+ Pairing Code (adb pair <ip:port> <code>)
  static Future<bool> pairWirelessDevice(String pairingIpWithPort, String pairingCode) async {
    try {
      final adbPath = await getAdbPath();
      final result = await Process.run(adbPath, ['pair', pairingIpWithPort, pairingCode]).timeout(const Duration(seconds: 8));
      final out = result.stdout.toString().toLowerCase();
      return out.contains('successfully paired') || out.contains('already paired');
    } catch (_) {
      return false;
    }
  }

  /// Connect to a wireless ADB device via IP and Port (e.g., 192.168.1.105:5555)
  static Future<bool> connectWirelessDevice(String ipAddress, {int port = 5555}) async {
    try {
      final adbPath = await getAdbPath();
      final target = ipAddress.contains(':') ? ipAddress : '$ipAddress:$port';
      final result = await Process.run(adbPath, ['connect', target]).timeout(const Duration(seconds: 6));
      final out = result.stdout.toString().toLowerCase();
      return out.contains('connected to') || out.contains('already connected');
    } catch (_) {
      return false;
    }
  }

  static DateTime _lastPairingHeartbeat = DateTime.fromMillisecondsSinceEpoch(0);

  /// Sync real device state (battery level, model, device serial)
  static Future<void> syncRealDeviceTelemetry(String serial, DeviceState state) async {
    activeSerial = serial;
    final adbPath = await getAdbPath();

    // 0. Enforce ADB port forwarding & reverse rules for Companion Server
    try {
      await Process.run(adbPath, ['-s', serial, 'forward', 'tcp:8080', 'tcp:8080']);
      await Process.run(adbPath, ['-s', serial, 'reverse', 'tcp:38947', 'tcp:38947']);
      await Process.run(adbPath, ['-s', serial, 'reverse', 'tcp:4567', 'tcp:4567']);
    } catch (_) {}

    // 1. Send Companion Heartbeat & Pairing ping every 4 seconds
    final now = DateTime.now();
    if (now.difference(_lastPairingHeartbeat).inSeconds >= 4) {
      _lastPairingHeartbeat = now;
      PairingService.requestPairing().catchError((_) => PairingResult(
        status: 'FAILED',
        deviceId: '',
        computerName: '',
      ));
    }

    // 2. Fetch real device model
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

    final media = await RealAdbSyncService.fetchRealMediaState(currentState: state.mediaState.value);
    state.mediaState.value = media;

    state.deviceIp.value = serial;
    state.isAdbConnected.value = true;
  }
}
