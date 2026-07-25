import 'dart:io';
import 'package:flutter/material.dart';
import '../services/adb_device_scanner.dart';
import '../services/real_adb_sync_service.dart';

class CallDialog extends StatefulWidget {
  const CallDialog({super.key});

  @override
  State<CallDialog> createState() => _CallDialogState();
}

class _CallDialogState extends State<CallDialog> {
  List<RealCallLogItem> _callLogs = [];
  bool _isLoading = true;
  final TextEditingController _numberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCallLogs();
  }

  Future<void> _loadCallLogs() async {
    setState(() => _isLoading = true);
    final logs = await RealAdbSyncService.fetchRealCallLogs();
    if (mounted) {
      setState(() {
        _callLogs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _makeCall(String number) async {
    if (number.trim().isEmpty) return;
    final adbPath = await AdbDeviceScanner.getAdbPath();
    await Process.run(adbPath, [
      'shell',
      'am',
      'start',
      '-a',
      'android.intent.action.CALL',
      '-d',
      'tel:${number.trim()}'
    ]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Initiating call to ${number.trim()}...")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111827).withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 550,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phone_rounded, color: Color(0xFF8B5CF6), size: 24),
                    SizedBox(width: 10),
                    Text(
                      "Phone Dialer & Call Logs",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Dialer Input & Call Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _numberController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: "Enter phone number...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.dialpad, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1F2937),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _makeCall(_numberController.text),
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: const Text("Call"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Row(
              children: [
                Text(
                  "RECENT CALL LOGS",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    )
                  : _callLogs.isEmpty
                      ? const Center(
                          child: Text("No call logs found",
                              style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          itemCount: _callLogs.length,
                          itemBuilder: (context, index) {
                            final call = _callLogs[index];
                            final isIncoming = call.type == '1';
                            final isOutgoing = call.type == '2';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isIncoming
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : isOutgoing
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : Colors.red.withValues(alpha: 0.2),
                                child: Icon(
                                  isIncoming
                                      ? Icons.call_received
                                      : isOutgoing
                                          ? Icons.call_made
                                          : Icons.call_missed,
                                  color: isIncoming
                                      ? Colors.blueAccent
                                      : isOutgoing
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                call.name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14),
                              ),
                              subtitle: Text(
                                call.number,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.phone,
                                    color: Colors.greenAccent, size: 20),
                                onPressed: () => _makeCall(call.number),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
