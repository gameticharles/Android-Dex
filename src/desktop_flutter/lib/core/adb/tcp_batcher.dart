import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Performance Fix #5: Debounced 16ms TCP Command Batcher.
/// Combines rapid control events (e.g. volume hold) into single frame packets.
class TcpCommandBatcher {
  final Socket socket;
  final _queue = <Map<String, dynamic>>[];
  Timer? _flushTimer;

  TcpCommandBatcher({required this.socket});

  void sendCommand(String command, [Map<String, dynamic>? params]) {
    _queue.add({
      'cmd': command,
      if (params != null) ...params,
    });

    // Schedule flush on next frame boundary (16ms)
    _flushTimer ??= Timer(const Duration(milliseconds: 16), _flush);
  }

  void _flush() {
    if (_queue.isEmpty) return;

    if (_queue.length == 1) {
      // Single command
      socket.write('${jsonEncode(_queue.first)}\n');
    } else {
      // Batch payload
      socket.write('${jsonEncode({
            'type': 'batch',
            'commands': List.from(_queue),
          })}\n');
    }

    _queue.clear();
    _flushTimer = null;
  }

  void dispose() {
    _flushTimer?.cancel();
    _queue.clear();
  }
}
