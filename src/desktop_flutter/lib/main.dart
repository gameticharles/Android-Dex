import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:adb_device_manager/core/models/device_state.dart';
import 'package:adb_device_manager/core/adb/adb_device_scanner.dart';
import 'package:adb_device_manager/core/services/boot_manager.dart';
import 'package:adb_device_manager/core/server/shelf_server.dart';
import 'package:adb_device_manager/app/bootloader_screen.dart';
import 'package:adb_device_manager/desktop/shell/dex_desktop_shell.dart';

import 'package:adb_device_manager/features/settings/services/dex_settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DexSettingsService.init();
  try {
    await windowManager.ensureInitialized();
  } catch (e) {
    debugPrint("WindowManager init skipped/failed: $e");
  }
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
    _shelfServer = DesktopShelfServer(deviceState: _deviceState, port: 38947);
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
      companionPackage: 'com.androiddex.companion',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Android Dex Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _isBootCompleted
            ? DexDesktopShell(
                key: const ValueKey('dex_desktop_shell'),
                deviceState: _deviceState,
                onStartBoot: _runBootProtocol,
              )
            : BootloaderScreen(
                key: const ValueKey('bootloader_screen'),
                deviceState: _deviceState,
                onLaunchDesktop: () {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _isBootCompleted = true;
                      });
                    }
                  });
                },
              ),
      ),
    );
  }
}
