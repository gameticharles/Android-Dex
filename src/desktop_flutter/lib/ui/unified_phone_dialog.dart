import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/adb_device_scanner.dart';
import '../services/real_adb_sync_service.dart';

class UnifiedPhoneDialog extends StatefulWidget {
  final int initialSubTab; // 0: ALL, 1: MISSED, 2: CONTACTS, 3: DIAL
  final bool isWindow;

  const UnifiedPhoneDialog({
    super.key,
    this.initialSubTab = 0,
    this.isWindow = false,
  });

  @override
  State<UnifiedPhoneDialog> createState() => _UnifiedPhoneDialogState();
}

class _UnifiedPhoneDialogState extends State<UnifiedPhoneDialog> {
  late int _activeSubTab;
  List<RealCallLogItem> _callLogs = [];
  List<RealContactItem> _contacts = [];
  bool _isLoading = true;

  // Selected Item for Right Detail View
  Object? _selectedItem;

  final TextEditingController _dialerController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _activeSubTab = widget.initialSubTab;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final contacts = await RealAdbSyncService.fetchRealContacts();
    final logs = await RealAdbSyncService.fetchRealCallLogs();

    if (mounted) {
      setState(() {
        _contacts = contacts;
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

  void _appendDigit(String digit) {
    setState(() {
      _dialerController.text = _dialerController.text + digit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final missedLogs = _callLogs.where((l) => l.type == '3').toList();
    final filteredContacts = _contacts.where((c) {
      final q = _searchController.text.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.number.contains(q);
    }).toList();

    final body = Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          // Top Custom DeX Window Title Bar (only if modal dialog)
          if (!widget.isWindow)
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.phone, color: Color(0xFF00BFA5), size: 16),
                      SizedBox(width: 8),
                      Text(
                        "Phone & Calls",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.push_pin_outlined, color: Colors.grey, size: 16),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.crop_square, color: Colors.grey, size: 16),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Main Dual-Pane Workspace (Left Master Pane + Right Detail Pane)
          Expanded(
            child: Row(
              children: [
                // LEFT MASTER PANE (Width: 340px)
                Container(
                  width: 340,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.white10)),
                  ),
                  child: Column(
                    children: [
                      // Pane Header: Title + Refresh + Clear All
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Phone & Calls",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh,
                                      color: Colors.grey, size: 18),
                                  onPressed: _loadData,
                                  tooltip: "Sync Calls & Contacts",
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 18),
                                  onPressed: () =>
                                      setState(() => _callLogs.clear()),
                                  tooltip: "Clear Call Logs",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Sub-tabs: ALL | MISSED | CONTACTS | DIAL
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildSubTab(0, "ALL"),
                            _buildSubTab(1, "MISSED"),
                            _buildSubTab(2, "CONTACTS"),
                            _buildSubTab(3, "DIAL"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Sub-tab View Content
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF00BFA5)))
                            : IndexedStack(
                                index: _activeSubTab,
                                children: [
                                  // 0: ALL LOGS
                                  _buildCallLogsList(_callLogs),

                                  // 1: MISSED LOGS
                                  _buildCallLogsList(missedLogs),

                                  // 2: CONTACTS
                                  _buildContactsList(filteredContacts),

                                  // 3: DIALER KEYPAD
                                  _buildKeypadPane(),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),

                // RIGHT DETAIL PANE (Width: Expanded)
                Expanded(
                  child: _buildRightDetailPane(),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.isWindow) {
      return Scaffold(body: body);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            width: 880,
            height: 640,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 35,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _buildSubTab(int index, String label) {
    final isActive = _activeSubTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeSubTab = index),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF00BFA5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white60,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // LEFT PANE: CALL LOGS LIST
  Widget _buildCallLogsList(List<RealCallLogItem> logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Text("No call logs found", style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final call = logs[index];
        final isSelected = _selectedItem == call;
        final isMissed = call.type == '3';
        final isIncoming = call.type == '1';

        return InkWell(
          onTap: () => setState(() => _selectedItem = call),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00BFA5).withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: const Color(0xFF00BFA5).withValues(alpha: 0.4))
                  : null,
            ),
            child: Row(
              children: [
                // Status Icon Avatar
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isMissed
                      ? Colors.red.withValues(alpha: 0.2)
                      : isIncoming
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.2),
                  child: Icon(
                    isMissed
                        ? Icons.call_missed
                        : isIncoming
                            ? Icons.call_received
                            : Icons.call_made,
                    color: isMissed
                        ? Colors.redAccent
                        : isIncoming
                            ? Colors.greenAccent
                            : Colors.blueAccent,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 10),

                // Name & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              isMissed ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            isMissed
                                ? Icons.south_west
                                : isIncoming
                                    ? Icons.south_west
                                    : Icons.north_east,
                            color: isMissed
                                ? Colors.redAccent
                                : isIncoming
                                    ? Colors.greenAccent
                                    : Colors.blueAccent,
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isMissed
                                ? "missed"
                                : isIncoming
                                    ? "incoming"
                                    : "outgoing",
                            style: TextStyle(
                              color: isMissed
                                  ? Colors.redAccent
                                  : isIncoming
                                      ? Colors.greenAccent
                                      : Colors.blueAccent,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            call.duration != '0' ? "${call.duration}s" : "Not connected",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Timestamp
                Text(
                  call.timestamp,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // LEFT PANE: CONTACTS LIST
  Widget _buildContactsList(List<RealContactItem> contacts) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() {}),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: "Search contacts...",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.grey, size: 16),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: contacts.isEmpty
              ? const Center(
                  child: Text("No contacts found",
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final c = contacts[index];
                    final isSelected = _selectedItem == c;

                    return InkWell(
                      onTap: () => setState(() => _selectedItem = c),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00BFA5).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF00BFA5)
                                  .withValues(alpha: 0.2),
                              child: Text(
                                c.name.isNotEmpty
                                    ? c.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Color(0xFF00BFA5), fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1),
                                  Text(c.number,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // LEFT PANE: KEYPAD DIALER (Matching original screenshot styling!)
  Widget _buildKeypadPane() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Sleek Input Display Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _dialerController.text.isEmpty
                        ? "Enter number"
                        : _dialerController.text,
                    style: TextStyle(
                      color: _dialerController.text.isEmpty
                          ? Colors.grey
                          : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                if (_dialerController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.backspace_outlined,
                        color: Colors.grey, size: 18),
                    onPressed: () => setState(() {
                      _dialerController.text = _dialerController.text.substring(
                          0, _dialerController.text.length - 1);
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Keypad Buttons Grid (Wide rounded dark key cards matching original screenshot)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDialKey("1", ""),
                    _buildDialKey("2", "ABC"),
                    _buildDialKey("3", "DEF"),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDialKey("4", "GHI"),
                    _buildDialKey("5", "JKL"),
                    _buildDialKey("6", "MNO"),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDialKey("7", "PQRS"),
                    _buildDialKey("8", "TUV"),
                    _buildDialKey("9", "WXYZ"),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDialKey("*", ""),
                    _buildDialKey("0", "+"),
                    _buildDialKey("#", ""),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Full-width vibrant Call Button
          ElevatedButton.icon(
            onPressed: () => _makeCall(_dialerController.text),
            icon: const Icon(Icons.phone, color: Colors.black, size: 20),
            label: const Text("Call",
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialKey(String digit, String sub) {
    return InkWell(
      onTap: () => _appendDigit(digit),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 80,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(digit,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            if (sub.isNotEmpty)
              Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  // RIGHT DETAIL PANE
  Widget _buildRightDetailPane() {
    if (_selectedItem == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(Icons.phone_in_talk,
                  color: Color(0xFF00BFA5), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              "Phone & Calls",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Select a log or use the Dial tab to make a call",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    String name = '';
    String number = '';

    if (_selectedItem is RealCallLogItem) {
      final log = _selectedItem as RealCallLogItem;
      name = log.name;
      number = log.number;
    } else if (_selectedItem is RealContactItem) {
      final contact = _selectedItem as RealContactItem;
      name = contact.name;
      number = contact.number;
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Contact Header Card
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.25),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Color(0xFF00BFA5),
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      number,
                      style: const TextStyle(
                        color: Color(0xFF00BFA5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Direct Action Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _makeCall(number),
                  icon: const Icon(Icons.phone, color: Colors.black, size: 18),
                  label: const Text("Call Phone",
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 20),

          // Call History Timeline Details
          const Text(
            "CALL HISTORY TIMELINE",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: ListView(
                children: [
                  _buildTimelineTile(
                    icon: Icons.call_made,
                    color: Colors.blueAccent,
                    title: "Outgoing call",
                    sub: "Connected • 23s",
                    time: "14:03 Today",
                  ),
                  _buildTimelineTile(
                    icon: Icons.call_received,
                    color: Colors.greenAccent,
                    title: "Incoming call",
                    sub: "Connected • 58s",
                    time: "14:15 Today",
                  ),
                  _buildTimelineTile(
                    icon: Icons.call_missed,
                    color: Colors.redAccent,
                    title: "Missed call",
                    sub: "Not connected",
                    time: "15:25 Today",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTile({
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}
