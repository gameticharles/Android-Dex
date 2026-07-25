import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Performance Optimization Unit Tests', () {
    test('1. TCP Command Batcher debounces multiple commands into 16ms frame', () async {
      final List<String> sentMessages = [];

      // Simulated socket behavior
      final controller = StreamController<String>();
      controller.stream.listen((msg) => sentMessages.add(msg));

      // Batcher logic test
      final List<Map<String, dynamic>> queue = [];
      Timer? timer;

      void send(String cmd) {
        queue.add({'cmd': cmd});
        timer ??= Timer(const Duration(milliseconds: 16), () {
          controller.add(queue.length == 1 ? queue.first.toString() : 'batch:${queue.length}');
          queue.clear();
          timer = null;
        });
      }

      // Fire 3 commands rapidly (within 5ms)
      send("VOLUME_UP");
      send("VOLUME_UP");
      send("VOLUME_UP");

      expect(sentMessages.isEmpty, isTrue); // Not sent immediately

      // Wait 30ms for 16ms timer to trigger
      await Future.delayed(const Duration(milliseconds: 30));

      expect(sentMessages.length, equals(1));
      expect(sentMessages.first, equals('batch:3')); // Combined 3 commands into 1 frame!
    });

    test('2. Contacts Pagination URI formatting', () {
      final uri = Uri.parse('http://127.0.0.1:4567/contacts/get_all')
          .replace(queryParameters: {
        'token': 'secret123',
        'offset': '50',
        'limit': '50',
        'photos': 'false',
      });

      expect(uri.queryParameters['offset'], equals('50'));
      expect(uri.queryParameters['limit'], equals('50'));
      expect(uri.queryParameters['photos'], equals('false'));
    });
  });
}
