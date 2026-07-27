import 'dart:async';
import 'dart:io';
import 'package:adb_device_manager/core/models/device_state.dart';
import 'package:adb_device_manager/core/adb/adb_device_scanner.dart';
import 'package:adb_device_manager/core/services/boot_manager.dart';

enum DiagnosticStatus { pending, running, passed, warning, failed }

class DiagnosticStepItem {
  final String id;
  final String title;
  DiagnosticStatus status;
  String detail;

  DiagnosticStepItem({
    required this.id,
    required this.title,
    this.status = DiagnosticStatus.pending,
    this.detail = 'Waiting...',
  });
}

class BootDiagnosticService {
  final DeviceState deviceState;
  final String? targetSerial;
  final Function(double progress, String statusText,
      List<DiagnosticStepItem> steps, List<RealDevice> scannedDevices) onUpdate;

  BootDiagnosticService({
    required this.deviceState,
    this.targetSerial,
    required this.onUpdate,
  });

  List<DiagnosticStepItem> createInitialSteps() {
    return [
      DiagnosticStepItem(id: 'adb', title: 'ADB Toolchain Verification'),
      DiagnosticStepItem(id: 'device', title: 'Android Device Connection'),
      DiagnosticStepItem(id: 'ports', title: 'TCP Reverse Port Forwarding'),
      DiagnosticStepItem(
          id: 'permissions', title: 'System Permissions & Telemetry'),
      DiagnosticStepItem(id: 'engine', title: 'Dex Companion Engine Handshake'),
    ];
  }

  Future<bool> runDiagnostics() async {
    final steps = createInitialSteps();
    bool allSuccess = true;
    List<RealDevice> devices = [];

    // Step 1: ADB Toolchain Check
    steps[0].status = DiagnosticStatus.running;
    steps[0].detail = 'Locating adb binary...';
    onUpdate(0.15, 'Checking ADB environment...', steps, devices);

    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      final res = await Process.run(adbPath, ['version']);
      if (res.exitCode == 0) {
        final versionLine = res.stdout.toString().split('\n').first;
        steps[0].status = DiagnosticStatus.passed;
        steps[0].detail = 'Ready: ${versionLine.trim()}';
      } else {
        steps[0].status = DiagnosticStatus.failed;
        steps[0].detail = 'ADB returned error code ${res.exitCode}';
        allSuccess = false;
      }
    } catch (e) {
      steps[0].status = DiagnosticStatus.failed;
      steps[0].detail = 'ADB not found: $e';
      allSuccess = false;
    }
    onUpdate(0.25, 'ADB verified', steps, devices);
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 2: Device Connection Discovery
    steps[1].status = DiagnosticStatus.running;
    steps[1].detail = 'Scanning USB & Wireless ADB devices...';
    onUpdate(
        0.35, 'Searching for connected Android devices...', steps, devices);

    try {
      devices = await AdbDeviceScanner.scanDevices();
      if (devices.isNotEmpty) {
        final selected = targetSerial != null
            ? (devices.firstWhere((d) => d.serial == targetSerial,
                orElse: () => devices.first))
            : devices.first;

        deviceState.deviceName.value = selected.model;
        deviceState.isAdbConnected.value = true;

        steps[1].status = DiagnosticStatus.passed;
        steps[1].detail =
            '${selected.model} (${selected.serial}) - ${selected.connectionType}';
      } else {
        steps[1].status = DiagnosticStatus.warning;
        steps[1].detail = 'No physical Android device connected via ADB';
        deviceState.isAdbConnected.value = false;
        allSuccess = false;
      }
    } catch (e) {
      steps[1].status = DiagnosticStatus.failed;
      steps[1].detail = 'Device scan error: $e';
      allSuccess = false;
    }
    onUpdate(0.50, 'Device discovery finished', steps, devices);
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 3: TCP Reverse Port Forwarding
    steps[2].status = DiagnosticStatus.running;
    steps[2].detail = 'Configuring ports (38947, 4567)...';
    onUpdate(0.65, 'Setting up reverse network ports...', steps, devices);

    if (devices.isNotEmpty) {
      final activeSerial = targetSerial ?? devices.first.serial;
      try {
        final adbPath = await AdbDeviceScanner.getAdbPath();
        await Process.run(
            adbPath, ['-s', activeSerial, 'forward', 'tcp:8080', 'tcp:8080']);
        await Process.run(
            adbPath, ['-s', activeSerial, 'reverse', 'tcp:38947', 'tcp:38947']);
        await Process.run(
            adbPath, ['-s', activeSerial, 'forward', 'tcp:4567', 'tcp:4567']);
        steps[2].status = DiagnosticStatus.passed;
        steps[2].detail = 'Forward 8080, 4567 & Reverse 38947 active for $activeSerial';
      } catch (e) {
        steps[2].status = DiagnosticStatus.warning;
        steps[2].detail = 'Port reverse warning: $e';
      }
    } else {
      steps[2].status = DiagnosticStatus.warning;
      steps[2].detail = 'Skipped (device offline)';
    }
    onUpdate(0.75, 'Port configuration complete', steps, devices);
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 4: System Permissions & Telemetry Check
    steps[3].status = DiagnosticStatus.running;
    steps[3].detail = 'Verifying notification listener & system permissions...';
    onUpdate(
        0.85, 'Auditing device permissions & telemetry...', steps, devices);

    if (devices.isNotEmpty) {
      final activeSerial = targetSerial ?? devices.first.serial;
      try {
        await AdbDeviceScanner.syncRealDeviceTelemetry(
            activeSerial, deviceState);
        steps[3].status = DiagnosticStatus.passed;
        steps[3].detail =
            'Battery: ${deviceState.batteryPercentage.value}% | Wi-Fi: ${deviceState.wifiName.value}';
      } catch (e) {
        steps[3].status = DiagnosticStatus.warning;
        steps[3].detail = 'Telemetry partial sync: $e';
      }
    } else {
      steps[3].status = DiagnosticStatus.warning;
      steps[3].detail = 'Offline demo mode ready';
    }
    onUpdate(0.92, 'Permissions audit complete', steps, devices);
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 5: Dex Companion Engine Handshake & Auto-Deployment
    steps[4].status = DiagnosticStatus.running;
    steps[4].detail = 'Verifying & deploying companion service...';
    onUpdate(0.98, 'Handshaking with Dex engine...', steps, devices);

    if (devices.isNotEmpty) {
      final activeSerial = targetSerial ?? devices.first.serial;
      try {
        final bootManager = BootManager(
          deviceIp: activeSerial,
          onProgress: (p, statusText) {
            steps[4].detail = statusText;
            onUpdate(0.95 + (p * 0.05), statusText, steps, devices);
          },
        );

        await bootManager.executeBootProtocol(
          localJarPath:
              '/home/charlesgameti/Documents/GitHub/Android-Dex/reengineering/linux_extracted/All helper_linux/_server_apk/adb_device_manger.jar',
          remoteJarPath: '/data/local/tmp/adb_device_manger.jar',
          companionPackage: 'com.androiddex.companion',
        );
        steps[4].status = DiagnosticStatus.passed;
        steps[4].detail = 'Dex Companion Engine Initialized & Active';
      } catch (e) {
        steps[4].status = DiagnosticStatus.warning;
        steps[4].detail = 'Companion deployment warning: $e';
      }
    } else {
      steps[4].status = DiagnosticStatus.passed;
      steps[4].detail = 'Dex Desktop Engine Initialized';
    }

    onUpdate(1.00, 'Diagnostic System Check Complete', steps, devices);
    return allSuccess;
  }
}
