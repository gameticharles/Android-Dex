import 'package:flutter/material.dart';
import '../services/adb_device_scanner.dart';

class WirelessAdbDialog extends StatefulWidget {
  final Function(String ipAddress)? onConnected;

  const WirelessAdbDialog({super.key, this.onConnected});

  @override
  State<WirelessAdbDialog> createState() => _WirelessAdbDialogState();
}

class _WirelessAdbDialogState extends State<WirelessAdbDialog> {
  int _selectedTab = 0; // 0 = 1-Click Auto, 1 = Direct IP, 2 = Pair Code

  bool _isProcessing = false;
  String? _statusMessage;
  bool _isError = false;

  final TextEditingController _ipController = TextEditingController(text: '192.168.1.');
  final TextEditingController _portController = TextEditingController(text: '5555');
  final TextEditingController _pairingAddressController = TextEditingController(text: '192.168.1.');
  final TextEditingController _pairingCodeController = TextEditingController();

  List<RealDevice> _usbDevices = [];

  @override
  void initState() {
    super.initState();
    _loadUsbDevices();
  }

  Future<void> _loadUsbDevices() async {
    final devices = await AdbDeviceScanner.scanDevices();
    if (mounted) {
      setState(() {
        _usbDevices = devices.where((d) => !d.isWireless).toList();
      });
    }
  }

  Future<void> _autoSwitchUsbToWireless(RealDevice device) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = "Enabling TCP/IP mode on ${device.model}...";
      _isError = false;
    });

    final okTcp = await AdbDeviceScanner.enableTcpipMode(device.serial);
    if (!okTcp) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Failed to enable TCP/IP mode on USB device.";
          _isError = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _statusMessage = "Resolving device Wi-Fi IP address...");
    }

    final ip = await AdbDeviceScanner.getDeviceWifiAddress(device.serial);
    if (ip == null || ip.isEmpty) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Unable to detect device Wi-Fi IP address. Ensure device is on same Wi-Fi.";
          _isError = true;
        });
      }
      return;
    }

    final fullTarget = "$ip:5555";
    if (mounted) {
      setState(() => _statusMessage = "Connecting wirelessly to $fullTarget...");
    }

    final connected = await AdbDeviceScanner.connectWirelessDevice(fullTarget);
    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (connected) {
          _statusMessage = "Connected wirelessly to $fullTarget ✓";
          _isError = false;
          widget.onConnected?.call(fullTarget);
        } else {
          _statusMessage = "Failed to connect wirelessly to $fullTarget.";
          _isError = true;
        }
      });
    }
  }

  Future<void> _connectDirectIp() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 5555;
    if (ip.isEmpty) return;

    final target = ip.contains(':') ? ip : "$ip:$port";

    setState(() {
      _isProcessing = true;
      _statusMessage = "Connecting to $target...";
      _isError = false;
    });

    final ok = await AdbDeviceScanner.connectWirelessDevice(target);
    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (ok) {
          _statusMessage = "Successfully connected to $target ✓";
          _isError = false;
          widget.onConnected?.call(target);
        } else {
          _statusMessage = "Connection failed to $target. Ensure Wireless Debugging is enabled.";
          _isError = true;
        }
      });
    }
  }

  Future<void> _pairWirelessDevice() async {
    final pairingAddress = _pairingAddressController.text.trim();
    final code = _pairingCodeController.text.trim();

    if (pairingAddress.isEmpty || code.isEmpty) {
      setState(() {
        _statusMessage = "Please enter both Pairing IP:Port and 6-digit Code.";
        _isError = true;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = "Pairing with $pairingAddress using code $code...";
      _isError = false;
    });

    final paired = await AdbDeviceScanner.pairWirelessDevice(pairingAddress, code);
    if (!paired) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Pairing failed. Check pairing port & code and retry.";
          _isError = true;
        });
      }
      return;
    }

    final ipOnly = pairingAddress.split(':')[0];
    final connectTarget = "$ipOnly:5555";

    if (mounted) {
      setState(() => _statusMessage = "Paired! Connecting to $connectTarget...");
    }

    final ok = await AdbDeviceScanner.connectWirelessDevice(connectTarget);
    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (ok) {
          _statusMessage = "Paired & Connected to $connectTarget ✓";
          _isError = false;
          widget.onConnected?.call(connectTarget);
        } else {
          _statusMessage = "Paired, but connection on 5555 timed out. Enter custom connect port.";
          _isError = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              spreadRadius: 4,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wifi_rounded, color: Color(0xFF00BFA5), size: 24),
                    SizedBox(width: 10),
                    Text(
                      "Wireless ADB Manager",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Segmented Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? const Color(0xFF00BFA5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "1-Click Switch",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedTab == 0 ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? const Color(0xFF00BFA5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Direct IP",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedTab == 1 ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 2 ? const Color(0xFF00BFA5) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Pair Code (11+)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedTab == 2 ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tab Content Views
            if (_selectedTab == 0) ...[
              const Text(
                "Connected USB Devices (Enable Wireless Mode)",
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              _usbDevices.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.usb_off_rounded, color: Colors.white38, size: 32),
                          SizedBox(height: 8),
                          Text("No USB devices detected.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                          SizedBox(height: 4),
                          Text("Plug in via USB once to auto-configure Wireless ADB.", style: TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    )
                  : Column(
                      children: _usbDevices.map((dev) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_android_rounded, color: Color(0xFF00BFA5), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dev.model, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text("Serial: ${dev.serial}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _isProcessing ? null : () => _autoSwitchUsbToWireless(dev),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00BFA5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.wifi_tethering, size: 16),
                                label: const Text("Switch to Wi-Fi", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ] else if (_selectedTab == 1) ...[
              const Text(
                "Connect via Device Wi-Fi IP Address",
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _ipController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "IP Address",
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _portController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "Port",
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _connectDirectIp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text("Connect to Wireless IP", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              const Text(
                "Pair New Device (Android 11+ Wireless Debugging)",
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pairingAddressController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: "Pairing IP & Port (e.g. 192.168.1.100:37891)",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pairingCodeController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: "6-Digit Wireless Pairing Code (e.g. 123456)",
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pairWirelessDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.phonelink_setup, size: 18),
                  label: const Text("Pair & Connect Device", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError ? Colors.redAccent.withValues(alpha: 0.15) : const Color(0xFF00BFA5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isError ? Colors.redAccent : const Color(0xFF00BFA5)),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _isError ? Colors.redAccent : const Color(0xFF00BFA5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
