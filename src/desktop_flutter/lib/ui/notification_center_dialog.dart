import 'package:flutter/material.dart';

class PhoneNotification {
  final String id;
  final String title;
  final String message;
  final String appName;
  final String time;

  PhoneNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.appName,
    required this.time,
  });
}

class NotificationCenterDialog extends StatefulWidget {
  const NotificationCenterDialog({super.key});

  @override
  State<NotificationCenterDialog> createState() => _NotificationCenterDialogState();
}

class _NotificationCenterDialogState extends State<NotificationCenterDialog> {
  final List<PhoneNotification> _notifications = [
    PhoneNotification(
      id: "1",
      title: "Telecel Weekend Offer",
      message: "Enjoy 4.4GB & 100mins call to ALL NETWORKS for GHs6. Dial *5588#",
      appName: "Telecel",
      time: "10 mins ago",
    ),
    PhoneNotification(
      id: "2",
      title: "MobileMoney Payment",
      message: "Payment made for GHS 1,300.00 to ABDUL-WAHAB BANSI AWUDU.",
      appName: "MobileMoney",
      time: "1 hr ago",
    ),
    PhoneNotification(
      id: "3",
      title: "DoSA Day 2026",
      message: "Join the Directorate of Student Affairs for DoSA Day 2026 at B5 Auditorium.",
      appName: "DOSA KNUST",
      time: "2 hrs ago",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111827).withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 550,
        height: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_rounded,
                        color: Color(0xFF00BFA5), size: 24),
                    SizedBox(width: 10),
                    Text(
                      "Live Notifications",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _notifications.clear()),
                      child: const Text("Clear All",
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            Expanded(
              child: _notifications.isEmpty
                  ? const Center(
                      child: Text("No active notifications",
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    notif.appName,
                                    style: const TextStyle(
                                      color: Color(0xFF00BFA5),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    notif.time,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notif.title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notif.message,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
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
