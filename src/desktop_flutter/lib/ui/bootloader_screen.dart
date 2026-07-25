import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/device_state.dart';
import '../services/adb_device_scanner.dart';
import '../services/boot_diagnostic_service.dart';

class BootloaderScreen extends StatefulWidget {
  final DeviceState deviceState;
  final VoidCallback onLaunchDesktop;

  const BootloaderScreen({
    super.key,
    required this.deviceState,
    required this.onLaunchDesktop,
  });

  @override
  State<BootloaderScreen> createState() => _BootloaderScreenState();
}

class _BootloaderScreenState extends State<BootloaderScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  double _progress = 0.0;
  String _statusMessage = 'Initializing Diagnostics...';
  List<DiagnosticStepItem> _steps = [];
  List<RealDevice> _scannedDevices = [];
  String? _selectedSerial;
  String _deviceFilter = 'All'; // 'All', 'USB', 'Wireless'

  bool _isDiagnosticFinished = false;
  Timer? _hotplugTimer;
  bool _isAutoDetecting = true;
  String _previousDeviceCountHash = '';

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startDiagnosticRun();

    // Background Hot-Plug Auto-Detection Timer (polls every 2 seconds)
    _hotplugTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isAutoDetecting && mounted) {
        _autoDetectHotpluggedDevices();
      }
    });
  }

  @override
  void dispose() {
    _hotplugTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _autoDetectHotpluggedDevices() async {
    try {
      final devices = await AdbDeviceScanner.scanDevices();
      final currentHash =
          devices.map((d) => '${d.serial}_${d.model}').join(',');

      if (currentHash != _previousDeviceCountHash) {
        _previousDeviceCountHash = currentHash;
        if (mounted) {
          _startDiagnosticRun(
            targetSerial: devices.isNotEmpty ? devices.first.serial : null,
          );
        }
      }
    } catch (_) {}
  }

  void _startDiagnosticRun({String? targetSerial}) {
    setState(() {
      _isDiagnosticFinished = false;
      _progress = 0.05;
      _statusMessage = 'Starting Diagnostic Sequence...';
      if (targetSerial != null) _selectedSerial = targetSerial;
    });

    final service = BootDiagnosticService(
      deviceState: widget.deviceState,
      targetSerial: _selectedSerial,
      onUpdate: (prog, statusText, updatedSteps, devices) {
        if (mounted) {
          setState(() {
            _progress = prog;
            _statusMessage = statusText;
            _steps = List.from(updatedSteps);
            _scannedDevices = List.from(devices);

            if (_selectedSerial == null && _scannedDevices.isNotEmpty) {
              _selectedSerial = _scannedDevices.first.serial;
            }
          });
        }
      },
    );

    service.runDiagnostics().then((success) {
      if (mounted) {
        setState(() {
          _isDiagnosticFinished = true;
        });
      }
    });
  }

  void _showWirelessAdbDialog() {
    final ipController = TextEditingController(text: '192.168.1.');
    final portController = TextEditingController(text: '5555');
    bool isConnecting = false;
    bool isScanningWifi = true;
    bool showManualEntry = false;
    List<DiscoveredWirelessDevice> discoveredWifiDevices = [];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void runWifiScan() async {
              setDialogState(() {
                isScanningWifi = true;
                discoveredWifiDevices.clear();
              });

              final results = await AdbDeviceScanner.scanWirelessAdbServices();

              if (dialogCtx.mounted) {
                setDialogState(() {
                  discoveredWifiDevices = results;
                  isScanningWifi = false;
                });
              }
            }

            // Trigger scan on initial dialog open
            if (isScanningWifi && discoveredWifiDevices.isEmpty) {
              runWifiScan();
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF00BFA5), width: 1.5),
              ),
              title: Row(
                children: [
                  const Icon(Icons.wifi_tethering_rounded,
                      color: Color(0xFF00BFA5)),
                  const SizedBox(width: 10),
                  const Text("Wireless ADB Discovery",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded,
                        color: isScanningWifi
                            ? const Color(0xFF00BFA5)
                            : Colors.white54,
                        size: 20),
                    onPressed: isScanningWifi ? null : () => runWifiScan(),
                    tooltip: "Scan Wi-Fi Network",
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Scanning local Wi-Fi network for Wireless ADB debugging devices...",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    // Radar Scanner / Discovered List
                    if (isScanningWifi) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        alignment: Alignment.center,
                        child: const Column(
                          children: [
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF00BFA5)),
                              ),
                            ),
                            SizedBox(height: 12),
                            Text("Scanning Wi-Fi Network via mDNS & Probes...",
                                style: TextStyle(
                                    color: Color(0xFF00BFA5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ] else if (discoveredWifiDevices.isNotEmpty) ...[
                      const Text(
                        "DISCOVERED WIRELESS DEVICES:",
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: SingleChildScrollView(
                          child: Column(
                            children: discoveredWifiDevices.map((dev) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFF00BFA5)
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.wifi_rounded,
                                        color: Color(0xFF00BFA5), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(dev.name,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
                                          Text(
                                              "${dev.fullAddress} (${dev.serviceType})",
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: isConnecting
                                          ? null
                                          : () async {
                                              setDialogState(
                                                  () => isConnecting = true);
                                              final success =
                                                  await AdbDeviceScanner
                                                      .connectWirelessDevice(
                                                          dev.ipAddress,
                                                          port: dev.port);
                                              if (dialogCtx.mounted)
                                                Navigator.pop(dialogCtx);
                                              if (mounted) {
                                                if (success) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          "Connected to ${dev.name} (${dev.fullAddress})!"),
                                                      backgroundColor:
                                                          const Color(
                                                              0xFF00BFA5),
                                                    ),
                                                  );
                                                  _startDiagnosticRun(
                                                      targetSerial:
                                                          dev.fullAddress);
                                                } else {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          "Failed to connect to ${dev.fullAddress}."),
                                                      backgroundColor:
                                                          Colors.redAccent,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF00BFA5),
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                      ),
                                      child: const Text("Connect",
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.wifi_off_rounded,
                                color: Colors.amberAccent, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "No broadcasting Wireless ADB devices found on Wi-Fi. Ensure 'Wireless Debugging' is ON in Developer Options.",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => setDialogState(
                          () => showManualEntry = !showManualEntry),
                      child: Text(
                        showManualEntry
                            ? "Hide Manual IP Entry"
                            : "Manual IP Entry & Port",
                        style: const TextStyle(
                            color: Color(0xFF00BFA5),
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),

                    if (showManualEntry) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: ipController,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: "Device IP Address",
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.wifi_rounded,
                              color: Color(0xFF00BFA5), size: 18),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: portController,
                        keyboardType: TextInputType.number,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: "ADB Port (Default 5555)",
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(
                              Icons.settings_ethernet_rounded,
                              color: Color(0xFF00BFA5),
                              size: 18),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.white54)),
                ),
                if (showManualEntry)
                  ElevatedButton(
                    onPressed: isConnecting
                        ? null
                        : () async {
                            setDialogState(() => isConnecting = true);
                            final ip = ipController.text.trim();
                            final port =
                                int.tryParse(portController.text.trim()) ??
                                    5555;

                            final success =
                                await AdbDeviceScanner.connectWirelessDevice(ip,
                                    port: port);
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            if (mounted) {
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "Connected to Wireless ADB at $ip:$port!"),
                                    backgroundColor: const Color(0xFF00BFA5),
                                  ),
                                );
                                _startDiagnosticRun(targetSerial: "$ip:$port");
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "Failed to connect to $ip:$port. Verify IP & Wireless Debugging."),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      foregroundColor: Colors.black,
                    ),
                    child: isConnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : const Text("Connect Device"),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStepIcon(DiagnosticStatus status) {
    switch (status) {
      case DiagnosticStatus.running:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BFA5)),
          ),
        );
      case DiagnosticStatus.passed:
        return const Icon(Icons.check_circle_rounded,
            color: Color(0xFF00BFA5), size: 20);
      case DiagnosticStatus.warning:
        return const Icon(Icons.warning_amber_rounded,
            color: Colors.amberAccent, size: 20);
      case DiagnosticStatus.failed:
        return const Icon(Icons.cancel_rounded,
            color: Colors.redAccent, size: 20);
      case DiagnosticStatus.pending:
        return const Icon(Icons.radio_button_unchecked,
            color: Colors.white24, size: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredDevices = _scannedDevices.where((d) {
      if (_deviceFilter == 'USB') return !d.isWireless;
      if (_deviceFilter == 'Wireless') return d.isWireless;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF070A12),
      body: Stack(
        children: [
          // Background Gradient Radial Glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: [
                        const Color(0xFF00BFA5).withValues(
                            alpha: 0.12 + _glowController.value * 0.08),
                        const Color(0xFF070A12),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // PERFECT CENTERING: Positioned.fill -> Center -> SingleChildScrollView
          Positioned.fill(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 640,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 35,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header Logo & Branding
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00BFA5)
                                      .withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: const Color(0xFF00BFA5),
                                      width: 1.5),
                                ),
                                child: const Icon(Icons.developer_board_rounded,
                                    color: Color(0xFF00BFA5), size: 26),
                              ),
                              const SizedBox(width: 12),
                              const Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "ANDROID DEX DOCK",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    Text(
                                      "System Diagnostic & Hardware Handshake Protocol",
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Radial Progress Indicator
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: CircularProgressIndicator(
                                  value: _progress,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.white10,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF00BFA5)),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${(_progress * 100).toInt()}%",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    "DIAGNOSIS",
                                    style: TextStyle(
                                      color: Color(0xFF00BFA5),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Status Message Text
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // MULTI-DEVICE SELECTOR & WIRELESS ADB BAR
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B)
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.devices_rounded,
                                                  color: Color(0xFF00BFA5),
                                                  size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                "DETECTED DEVICES (${_scannedDevices.length})",
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00BFA5)
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: const Color(0xFF00BFA5)
                                                      .withValues(alpha: 0.6)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.sensors_rounded,
                                                    color: Color(0xFF00BFA5),
                                                    size: 10),
                                                SizedBox(width: 4),
                                                Text(
                                                  "AUTO-LISTEN",
                                                  style: TextStyle(
                                                    color: Color(0xFF00BFA5),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Filter Chips (All, USB, Wireless)
                                    for (final filter in [
                                      'All',
                                      'USB',
                                      'Wireless'
                                    ]) ...[
                                      InkWell(
                                        onTap: () => setState(
                                            () => _deviceFilter = filter),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          margin:
                                              const EdgeInsets.only(left: 4),
                                          decoration: BoxDecoration(
                                            color: _deviceFilter == filter
                                                ? const Color(0xFF00BFA5)
                                                    .withValues(alpha: 0.25)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _deviceFilter == filter
                                                  ? const Color(0xFF00BFA5)
                                                  : Colors.white10,
                                            ),
                                          ),
                                          child: Text(
                                            filter,
                                            style: TextStyle(
                                              color: _deviceFilter == filter
                                                  ? const Color(0xFF00BFA5)
                                                  : Colors.grey,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Scanned Device Chips Grid
                                if (filteredDevices.isEmpty) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.link_off_rounded,
                                            color: Colors.amberAccent,
                                            size: 16),
                                        SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            "No devices found. Plug in USB or connect Wireless ADB.",
                                            style: TextStyle(
                                                color: Colors.amberAccent,
                                                fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: filteredDevices.map((dev) {
                                      final isSelected =
                                          _selectedSerial == dev.serial;

                                      return InkWell(
                                        onTap: () => _startDiagnosticRun(
                                            targetSerial: dev.serial),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF00BFA5)
                                                    .withValues(alpha: 0.2)
                                                : const Color(0xFF0F172A),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected
                                                  ? const Color(0xFF00BFA5)
                                                  : Colors.white12,
                                              width: isSelected ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                dev.isWireless
                                                    ? Icons.wifi_rounded
                                                    : Icons.usb_rounded,
                                                color: isSelected
                                                    ? const Color(0xFF00BFA5)
                                                    : Colors.grey,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    dev.model,
                                                    style: TextStyle(
                                                      color: isSelected
                                                          ? Colors.white
                                                          : Colors.white70,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    "${dev.connectionType} (${dev.serial})",
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 9,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (isSelected) ...[
                                                const SizedBox(width: 8),
                                                const Icon(Icons.check_circle,
                                                    color: Color(0xFF00BFA5),
                                                    size: 14),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],

                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: _showWirelessAdbDialog,
                                    icon: const Icon(
                                        Icons.wifi_tethering_rounded,
                                        size: 16,
                                        color: Color(0xFF00BFA5)),
                                    label: const Text(
                                      "Connect Wireless ADB",
                                      style: TextStyle(
                                        color: Color(0xFF00BFA5),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Divider(color: Colors.white10, height: 1),
                          const SizedBox(height: 14),

                          // Animated Diagnostic Check Items List
                          Column(
                            children: _steps.map((step) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    _buildStepIcon(step.status),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            step.title,
                                            style: TextStyle(
                                              color: step.status ==
                                                      DiagnosticStatus.pending
                                                  ? Colors.white38
                                                  : Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            step.detail,
                                            style: TextStyle(
                                              color: step.status ==
                                                      DiagnosticStatus.warning
                                                  ? Colors.amberAccent
                                                  : step.status ==
                                                          DiagnosticStatus
                                                              .failed
                                                      ? Colors.redAccent
                                                      : Colors.grey,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 20),

                          // Control Buttons Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isDiagnosticFinished) ...[
                                ElevatedButton.icon(
                                  onPressed: widget.onLaunchDesktop,
                                  icon: const Icon(
                                      Icons.desktop_windows_rounded,
                                      size: 18),
                                  label: const Text("Launch Dex Desktop"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00BFA5),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: () => _startDiagnosticRun(
                                      targetSerial: _selectedSerial),
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 18),
                                  label: const Text("Re-run Diagnosis"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side:
                                        const BorderSide(color: Colors.white24),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
