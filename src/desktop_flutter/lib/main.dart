import 'dart:async';
import 'package:flutter/material.dart';
import 'models/device_state.dart';
import 'services/adb_device_scanner.dart';
import 'services/boot_manager.dart';
import 'services/shelf_server.dart';
import 'ui/bootloader_screen.dart';
import 'ui/dex_desktop_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdbDeviceManagerApp());
}

class AdbDeviceManagerApp extends StatefulWidget {
  const AdbDeviceManagerApp({super.key});

  @override
  State<AdbDeviceManagerApp> createState() => _AdbDeviceManagerAppState();
}

class _AdbDeviceManagerAppState extends State<AdbDeviceManagerApp> {
  final DeviceState _deviceState = DeviceState();
  late DesktopShelfServer _shelfServer;
  Timer? _telemetryTimer;
  bool _isBootCompleted = false;

  @override
  void initState() {
    super.initState();
    _shelfServer = DesktopShelfServer(deviceState: _deviceState, port: 8080);
    _shelfServer.start();
    _scanAndConnectRealDevice();

    // Real-Time Hardware Polling Loop (every 1 second)
    _telemetryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _scanAndConnectRealDevice();
    });
  }

  Future<void> _scanAndConnectRealDevice() async {
    final devices = await AdbDeviceScanner.scanDevices();
    if (devices.isNotEmpty) {
      final realDev = devices.first;
      await AdbDeviceScanner.syncRealDeviceTelemetry(
          realDev.serial, _deviceState);
    }
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _shelfServer.stop();
    super.dispose();
  }

  void _runBootProtocol() async {
    await _scanAndConnectRealDevice();

    final bootManager = BootManager(
      deviceIp: _deviceState.deviceIp.value,
      onProgress: (progress, status) {
        debugPrint("Boot Progress [${(progress * 100).toInt()}%]: $status");
      },
    );

    bootManager.executeBootProtocol(
      localJarPath:
          '/home/charlesgameti/Documents/GitHub/Android-Dex/reengineering/linux_extracted/All helper_linux/_server_apk/adb_device_manger.jar',
      remoteJarPath: '/data/local/tmp/adb_device_manger.jar',
      companionPackage: 'com.shrey.adbdevicemanager',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Android Dex Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: AnimatedCrossFade(
        firstChild: BootloaderScreen(
          deviceState: _deviceState,
          onLaunchDesktop: () {
            setState(() {
              _isBootCompleted = true;
            });
          },
        ),
        secondChild: _isBootCompleted
            ? DexDesktopShell(
                deviceState: _deviceState,
                onStartBoot: _runBootProtocol,
              )
            : const SizedBox.shrink(),
        crossFadeState: _isBootCompleted
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
}
