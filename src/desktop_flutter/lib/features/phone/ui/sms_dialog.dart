import 'package:flutter/material.dart';
import 'package:adb_device_manager/core/adb/real_adb_sync_service.dart';

class SmsDialog extends StatefulWidget {
  final bool isWindow;
  const SmsDialog({super.key, this.isWindow = false});

  @override
  State<SmsDialog> createState() => _SmsDialogState();
}

class _SmsDialogState extends State<SmsDialog> {
  List<RealSmsMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSms();
  }

  Future<void> _loadSms() async {
    setState(() => _isLoading = true);
    final msgs = await RealAdbSyncService.fetchRealSms();
    if (mounted) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Container(
      color: const Color(0xFF111827),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!widget.isWindow)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.message, color: Color(0xFF00BFA5)),
                    SizedBox(width: 10),
                    Text(
                      "Live Real-Time SMS",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.grey),
                      onPressed: _loadSms,
                      tooltip: "Sync SMS Now",
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          if (widget.isWindow)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                  onPressed: _loadSms,
                  tooltip: "Sync SMS Now",
                ),
              ],
            ),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00BFA5),
                    ),
                  )
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          "No SMS messages found",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2937),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      msg.address,
                                      style: const TextStyle(
                                        color: Color(0xFF00BFA5),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (msg.date.isNotEmpty)
                                      Text(
                                        msg.date,
                                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  msg.body,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );

    if (widget.isWindow) return Scaffold(body: body);

    return Dialog(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        height: 600,
        child: body,
      ),
    );
  }
}
