import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:adb_device_manager/core/adb/adb_device_scanner.dart';
import 'package:adb_device_manager/core/adb/real_adb_sync_service.dart';

class SmsThread {
  final String address;
  final String normalizedNumber;
  final String contactName;
  final String latestMessage;
  final int latestTimestamp;
  final List<RealSmsMessage> messages;

  SmsThread({
    required this.address,
    required this.normalizedNumber,
    required this.contactName,
    required this.latestMessage,
    required this.latestTimestamp,
    required this.messages,
  });
}

class UnifiedPhoneDialog extends StatefulWidget {
  final int initialSubTab; // 0: ALL, 1: MISSED, 2: CONTACTS, 3: SMS, 4: DIAL
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
  List<RealSmsMessage> _rawSmsMessages = [];
  List<SmsThread> _smsThreads = [];
  bool _isLoading = true;
  bool _isSendingSms = false;

  // Selected Item for Right Detail View (RealCallLogItem | RealContactItem | SmsThread)
  Object? _selectedItem;

  final TextEditingController _dialerController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _smsComposerController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

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
    final sms = await RealAdbSyncService.fetchRealSms();

    final threads = _groupSmsThreads(sms, contacts);

    if (mounted) {
      setState(() {
        _contacts = contacts;
        _callLogs = logs;
        _rawSmsMessages = sms;
        _smsThreads = threads;
        _isLoading = false;

        if (_activeSubTab == 3 && _smsThreads.isNotEmpty && _selectedItem == null) {
          _selectedItem = _smsThreads.first;
        }
      });
    }
  }

  List<SmsThread> _groupSmsThreads(List<RealSmsMessage> messages, List<RealContactItem> contacts) {
    final Map<String, List<RealSmsMessage>> grouped = {};

    for (final msg in messages) {
      if (msg.address.trim().isEmpty) continue;
      final norm = RealAdbSyncService.normalizeNumber(msg.address);
      final key = norm.isNotEmpty ? norm : msg.address.trim();
      grouped.putIfAbsent(key, () => []).add(msg);
    }

    final List<SmsThread> threads = [];

    grouped.forEach((key, msgList) {
      msgList.sort((a, b) {
        final tA = int.tryParse(a.date) ?? 0;
        final tB = int.tryParse(b.date) ?? 0;
        return tA.compareTo(tB);
      });

      final latestMsg = msgList.last;
      final displayAddress = msgList.firstWhere(
        (m) => m.address.isNotEmpty && m.address != 'Unknown',
        orElse: () => latestMsg,
      ).address;

      String contactName = displayAddress;
      for (final c in contacts) {
        if (RealAdbSyncService.normalizeNumber(c.number) == key && c.name.isNotEmpty) {
          contactName = c.name;
          break;
        }
      }

      final timestamp = int.tryParse(latestMsg.date) ?? 0;

      threads.add(SmsThread(
        address: displayAddress,
        normalizedNumber: key,
        contactName: contactName,
        latestMessage: latestMsg.body,
        latestTimestamp: timestamp,
        messages: msgList,
      ));
    });

    threads.sort((a, b) => b.latestTimestamp.compareTo(a.latestTimestamp));
    return threads;
  }

  Future<void> _sendSms(String number) async {
    final text = _smsComposerController.text.trim();
    if (number.trim().isEmpty || text.isEmpty) return;

    setState(() => _isSendingSms = true);
    final ok = await RealAdbSyncService.sendSms(number, text);
    if (mounted) {
      final newMsg = RealSmsMessage(
        address: number,
        body: text,
        date: DateTime.now().millisecondsSinceEpoch.toString(),
        isSent: true,
      );

      setState(() {
        _isSendingSms = false;
        if (ok) {
          _rawSmsMessages.add(newMsg);
          _smsThreads = _groupSmsThreads(_rawSmsMessages, _contacts);

          // Keep selection on active thread
          final norm = RealAdbSyncService.normalizeNumber(number);
          final updatedThread = _smsThreads.firstWhere(
            (t) => t.normalizedNumber == norm || t.address == number,
            orElse: () => SmsThread(
              address: number,
              normalizedNumber: norm,
              contactName: number,
              latestMessage: text,
              latestTimestamp: DateTime.now().millisecondsSinceEpoch,
              messages: [newMsg],
            ),
          );
          _selectedItem = updatedThread;
          _smsComposerController.clear();
        }
      });

      // Scroll to bottom after post
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? "SMS sent to $number" : "Failed to send SMS"),
          backgroundColor: ok ? const Color(0xFF00BFA5) : Colors.redAccent,
        ),
      );
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

  String _formatSmsTime(int timestampMs) {
    if (timestampMs <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return "$h:$m";
    }
    return "${dt.month}/${dt.day} $h:$m";
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
                      Icon(Icons.phone_in_talk, color: Color(0xFF00BFA5), size: 16),
                      SizedBox(width: 8),
                      Text(
                        "Phone & Conversations",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Main Dual-Pane Workspace
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
                      // Pane Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  icon: const Icon(Icons.refresh, color: Colors.grey, size: 18),
                                  onPressed: _loadData,
                                  tooltip: "Sync Calls, Contacts & SMS",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Sub-tabs: ALL | MISSED | CONTACTS | SMS | DIAL
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
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
                            _buildSubTab(3, "SMS"),
                            _buildSubTab(4, "DIAL"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Sub-tab View Content
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BFA5)))
                            : IndexedStack(
                                index: _activeSubTab,
                                children: [
                                  _buildCallLogsList(_callLogs),
                                  _buildCallLogsList(missedLogs),
                                  _buildContactsList(filteredContacts),
                                  _buildSmsThreadsList(_smsThreads),
                                  _buildKeypadPane(),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),

                // RIGHT DETAIL PANE
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
              color: const Color(0xFF0F172A).withValues(alpha: 0.94),
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
        onTap: () {
          setState(() {
            _activeSubTab = index;
            if (index == 3 && _smsThreads.isNotEmpty) {
              _selectedItem = _smsThreads.first;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00BFA5) : Colors.transparent,
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
              color: isSelected ? const Color(0xFF00BFA5).withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: const Color(0xFF00BFA5).withValues(alpha: 0.4)) : null,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isMissed
                      ? Colors.red.withValues(alpha: 0.2)
                      : isIncoming
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.2),
                  child: Icon(
                    isMissed ? Icons.call_missed : isIncoming ? Icons.call_received : Icons.call_made,
                    color: isMissed ? Colors.redAccent : isIncoming ? Colors.greenAccent : Colors.blueAccent,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 10),
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
                          fontWeight: isMissed ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        call.duration != '0' ? "${call.duration}s" : "Not connected",
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Text(call.timestamp, style: const TextStyle(color: Colors.grey, fontSize: 10)),
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
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 16),
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
              ? const Center(child: Text("No contacts found", style: TextStyle(color: Colors.grey)))
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF00BFA5).withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                              child: Text(
                                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                      maxLines: 1),
                                  Text(c.number, style: const TextStyle(color: Colors.grey, fontSize: 10)),
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

  // LEFT PANE: SMS THREADS LIST (Deduplicated, grouped by unique contact/number)
  Widget _buildSmsThreadsList(List<SmsThread> threads) {
    if (threads.isEmpty) {
      return const Center(
        child: Text("No SMS conversations found", style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: threads.length,
      itemBuilder: (context, index) {
        final thread = threads[index];
        final isSelected = _selectedItem == thread;

        return InkWell(
          onTap: () => setState(() => _selectedItem = thread),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF00BFA5).withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: const Color(0xFF00BFA5).withValues(alpha: 0.4)) : null,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                  child: Text(
                    thread.contactName.isNotEmpty ? thread.contactName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              thread.contactName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            _formatSmsTime(thread.latestTimestamp),
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                      if (thread.contactName != thread.address)
                        Text(
                          thread.address,
                          style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 10),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        thread.latestMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // LEFT PANE: KEYPAD DIALER
  Widget _buildKeypadPane() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                    _dialerController.text.isEmpty ? "Enter number" : _dialerController.text,
                    style: TextStyle(
                      color: _dialerController.text.isEmpty ? Colors.grey : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                if (_dialerController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.backspace_outlined, color: Colors.grey, size: 18),
                    onPressed: () => setState(() {
                      _dialerController.text =
                          _dialerController.text.substring(0, _dialerController.text.length - 1);
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
          ElevatedButton.icon(
            onPressed: () => _makeCall(_dialerController.text),
            icon: const Icon(Icons.phone, color: Colors.black, size: 20),
            label: const Text("Call", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            Text(digit, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            if (sub.isNotEmpty) Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 8)),
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
              child: const Icon(Icons.phone_in_talk, color: Color(0xFF00BFA5), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              "Phone, Contacts & SMS",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Select a contact, call log, or SMS thread to interact",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    String name = '';
    String number = '';
    List<RealSmsMessage> conversationMessages = [];

    if (_selectedItem is SmsThread) {
      final thread = _selectedItem as SmsThread;
      name = thread.contactName;
      number = thread.address;
      conversationMessages = thread.messages;
    } else if (_selectedItem is RealContactItem) {
      final contact = _selectedItem as RealContactItem;
      name = contact.name;
      number = contact.number;

      // Find matching thread for this contact
      final norm = RealAdbSyncService.normalizeNumber(number);
      final matchingThread = _smsThreads.firstWhere(
        (t) => t.normalizedNumber == norm,
        orElse: () => SmsThread(
          address: number,
          normalizedNumber: norm,
          contactName: name,
          latestMessage: '',
          latestTimestamp: 0,
          messages: [],
        ),
      );
      conversationMessages = matchingThread.messages;
    } else if (_selectedItem is RealCallLogItem) {
      final log = _selectedItem as RealCallLogItem;
      name = log.name;
      number = log.number;

      final norm = RealAdbSyncService.normalizeNumber(number);
      final matchingThread = _smsThreads.firstWhere(
        (t) => t.normalizedNumber == norm,
        orElse: () => SmsThread(
          address: number,
          normalizedNumber: norm,
          contactName: name,
          latestMessage: '',
          latestTimestamp: 0,
          messages: [],
        ),
      );
      conversationMessages = matchingThread.messages;
    }

    final isSmsMode = _selectedItem is SmsThread || _activeSubTab == 3;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF00BFA5).withValues(alpha: 0.25),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Color(0xFF00BFA5),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      number,
                      style: const TextStyle(
                        color: Color(0xFF00BFA5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _makeCall(number),
                    icon: const Icon(Icons.phone, color: Colors.black, size: 16),
                    label: const Text("Call", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 12),

          // Conversation Thread Body
          Expanded(
            child: isSmsMode
                ? Column(
                    children: [
                      Expanded(
                        child: conversationMessages.isEmpty
                            ? Center(
                                child: Text(
                                  "No past messages with $name",
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: _chatScrollController,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: conversationMessages.length,
                                itemBuilder: (context, index) {
                                  final m = conversationMessages[index];
                                  final isMe = m.isSent;
                                  final timeStr = _formatSmsTime(int.tryParse(m.date) ?? 0);

                                  return Align(
                                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      constraints: const BoxConstraints(maxWidth: 320),
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: isMe
                                            ? const LinearGradient(
                                                colors: [Color(0xFF00BFA5), Color(0xFF0D9488)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                        color: isMe ? null : const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(16),
                                          topRight: const Radius.circular(16),
                                          bottomLeft: Radius.circular(isMe ? 16 : 2),
                                          bottomRight: Radius.circular(isMe ? 2 : 16),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m.body,
                                            style: TextStyle(
                                              color: isMe ? Colors.white : Colors.white,
                                              fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              color: isMe ? Colors.white70 : Colors.grey,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 10),
                      // Text Composer Input Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _smsComposerController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              onSubmitted: (_) => _sendSms(number),
                              decoration: InputDecoration(
                                hintText: "Type SMS message to $name...",
                                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _isSendingSms
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BFA5)),
                                )
                              : Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00BFA5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: () => _sendSms(number),
                                    icon: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                                    tooltip: "Send SMS",
                                  ),
                                ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            ],
                          ),
                        ),
                      ),
                    ],
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
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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
