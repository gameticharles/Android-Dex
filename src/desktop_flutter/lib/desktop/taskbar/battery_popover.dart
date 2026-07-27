import 'dart:io';
import 'package:flutter/material.dart';
import '../services/adb_device_scanner.dart';

class BatteryInfo {
  final int level;
  final bool isCharging;
  final String plugType;
  final double temperature;
  final double voltage;
  final String health;
  final String technology;

  BatteryInfo({
    required this.level,
    required this.isCharging,
    required this.plugType,
    required this.temperature,
    required this.voltage,
    required this.health,
    required this.technology,
  });
}

class BatteryPopover extends StatefulWidget {
  const BatteryPopover({super.key});

  @override
  State<BatteryPopover> createState() => _BatteryPopoverState();
}

class _BatteryPopoverState extends State<BatteryPopover> {
  BatteryInfo? _info;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBatteryDetails();
  }

  Future<void> _fetchBatteryDetails() async {
    setState(() => _isLoading = true);
    final adbPath = await AdbDeviceScanner.getAdbPath();
    final res = await Process.run(adbPath, ['shell', 'dumpsys', 'battery']);
    final lines = res.stdout.toString().split('\n');

    int level = 50;
    bool isCharging = false;
    String plugType = 'USB';
    double temp = 35.0;
    double voltage = 4.0;
    String health = 'GOOD';
    String tech = 'Li-ion';

    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('level:')) {
        level = int.tryParse(t.substring(6).trim()) ?? level;
      }
      if (t.startsWith('USB powered:') && t.contains('true')) {
        isCharging = true;
        plugType = 'USB';
      }
      if (t.startsWith('AC powered:') && t.contains('true')) {
        isCharging = true;
        plugType = 'AC';
      }
      if (t.startsWith('Wireless powered:') && t.contains('true')) {
        isCharging = true;
        plugType = 'Wireless';
      }
      if (t.startsWith('temperature:')) {
        final rawTemp = double.tryParse(t.substring(12).trim()) ?? 350;
        temp = rawTemp / 10.0;
      }
      if (t.startsWith('voltage:')) {
        final rawVolt = double.tryParse(t.substring(8).trim()) ?? 4000;
        voltage = rawVolt / 1000.0;
      }
      if (t.startsWith('technology:')) {
        tech = t.substring(11).trim();
      }
    }

    if (mounted) {
      setState(() {
        _info = BatteryInfo(
          level: level,
          isCharging: isCharging,
          plugType: plugType,
          temperature: temp,
          voltage: voltage,
          health: health,
          technology: tech.isEmpty ? 'Li-ion' : tech,
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 25,
            spreadRadius: 2,
          )
        ],
      ),
      child: _isLoading || _info == null
          ? const SizedBox(
              height: 180,
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00BFA5))),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Battery Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.battery_charging_full,
                            color: Colors.greenAccent, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          "${_info!.level}%",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (_info!.isCharging)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.green.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt,
                                color: Colors.greenAccent, size: 12),
                            Text(
                              _info!.plugType,
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Battery Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _info!.level / 100.0,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(height: 18),

                const Divider(height: 1, color: Colors.white10),
                const SizedBox(height: 12),

                // Metrics Grid
                _buildMetricRow("Plug Type", _info!.plugType, Icons.electrical_services),
                _buildMetricRow("Temperature", "${_info!.temperature} °C", Icons.thermostat),
                _buildMetricRow("Voltage", "${_info!.voltage.toStringAsFixed(2)} V", Icons.flash_on),
                _buildMetricRow("Health", _info!.health, Icons.favorite),
                _buildMetricRow("Technology", _info!.technology, Icons.memory),
              ],
            ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00BFA5), size: 14),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
