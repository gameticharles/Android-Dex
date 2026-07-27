import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:adb_device_manager/core/models/device_state.dart';
import 'package:adb_device_manager/features/phone/services/contacts_service.dart';
import 'package:adb_device_manager/features/phone/ui/contacts_dialog.dart';
import 'package:adb_device_manager/features/media/ui/media_player_widget.dart';
import 'package:adb_device_manager/features/phone/ui/sms_dialog.dart';

class DashboardScreen extends StatelessWidget {
  final DeviceState deviceState;
  final VoidCallback onStartBoot;

  const DashboardScreen({
    super.key,
    required this.deviceState,
    required this.onStartBoot,
  });

  void _showContactsDialog(BuildContext context) {
    final contactsService = ContactsService(
      baseUrl: 'http://127.0.0.1:4567',
      authToken: 'dex_secure_token',
    );

    showDialog(
      context: context,
      builder: (_) => ContactsDialog(contactsService: contactsService),
    );
  }

  void _showSmsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const SmsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.phonelink_setup, color: Color(0xFF00BFA5)),
            const SizedBox(width: 10),
            ValueListenableBuilder<String>(
              valueListenable: deviceState.deviceName,
              builder: (_, name, __) => Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onStartBoot,
            tooltip: "Run Boot Protocol",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Grid
            Row(
              children: [
                Expanded(
                  child: _StatusCard(
                    title: "Battery",
                    valueListenable: deviceState.batteryPercentage,
                    format: (v) => "$v%",
                    icon: Icons.battery_charging_full,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _StatusCard(
                    title: "Wi-Fi",
                    valueListenable: deviceState.wifiName,
                    format: (v) => v.toString(),
                    icon: Icons.wifi,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _StatusCard(
                    title: "Music Volume",
                    valueListenable: deviceState.volumeMusic,
                    format: (v) => "$v%",
                    icon: Icons.volume_up,
                    color: Colors.amberAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // Embedded Media Player
            const MediaPlayerWidget(),

            const SizedBox(height: 25),
            const Text(
              "Quick Actions",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.screen_share),
                  label: const Text("Mirror Screen"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    foregroundColor: Colors.black,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showContactsDialog(context),
                  icon: const Icon(Icons.contacts),
                  label: const Text("Live Contacts"),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showSmsDialog(context),
                  icon: const Icon(Icons.message),
                  label: const Text("Live SMS Messages"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard<T> extends StatelessWidget {
  final String title;
  final ValueListenable<T> valueListenable;
  final String Function(T) format;
  final IconData icon;
  final Color color;

  const _StatusCard({
    required this.title,
    required this.valueListenable,
    required this.format,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<T>(
            valueListenable: valueListenable,
            builder: (_, val, __) => Text(
              format(val),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
