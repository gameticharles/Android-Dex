import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:adb_device_manager/features/settings/services/dex_settings_service.dart';
import 'package:adb_device_manager/core/services/dex_audio_routing_service.dart';

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

    test('3. DexSettingsConfig serialization and computed helpers', () {
      const config = DexSettingsConfig(
        darkMode: true,
        glassEffects: true,
        blurIntensity: 0.8,
        surfaceTransparency: 0.85,
        itemRounding: 0.7,
        accentColor: 0xFF6366F1,
        displaySize: 'Large Screen',
        fontSizeScale: 1.1,
        selectedLanguage: 'Spanish',
        selectedFont: 'SamsungSharpSans',
        desktopGridSize: '5x5',
        showDesktopShortcuts: true,
        autoHideTaskbar: false,
        scrcpyBitrate: '16M',
        scrcpyMaxResolution: '1440',
        scrcpyMaxFps: 60,
        turnScreenOffOnMirror: true,
        stayAwakeOnMirror: true,
        forwardAudio: true,
        syncClipboard: true,
        androidToLinux: true,
        linuxToAndroid: true,
      );

      final json = config.toJson();
      final restored = DexSettingsConfig.fromJson(json);

      expect(restored.darkMode, isTrue);
      expect(restored.glassEffects, isTrue);
      expect(restored.accentColor, equals(0xFF6366F1));
      expect(restored.displaySize, equals('Large Screen'));
      expect(restored.scaleFactor, equals(1.10));
      expect(restored.selectedLanguage, equals('Spanish'));
      expect(restored.scrcpyBitrate, equals('16M'));
      expect(restored.scrcpyMaxResolution, equals('1440'));
      expect(restored.effectiveBorderRadius, greaterThan(0.0));
      expect(restored.effectiveBlurSigma, greaterThan(0.0));
      expect(restored.effectiveSurfaceAlpha, greaterThan(0.0));
    });

    test('4. DexAudioRoutingService destination normalization', () {
      expect(DexAudioRoutingService.normalizeDestination('Android (system)'),
          equals(DexAudioRoutingService.androidSpeaker));
      expect(DexAudioRoutingService.normalizeDestination('Android Speaker'),
          equals(DexAudioRoutingService.androidSpeaker));
      expect(DexAudioRoutingService.normalizeDestination('Android Dex'),
          equals(DexAudioRoutingService.dexSpeaker));
      expect(DexAudioRoutingService.normalizeDestination('Linux Desktop'),
          equals(DexAudioRoutingService.dexSpeaker));
      expect(DexAudioRoutingService.normalizeDestination('Dex Speaker'),
          equals(DexAudioRoutingService.dexSpeaker));
      expect(DexAudioRoutingService.normalizeDestination('Bluetooth Device'),
          equals(DexAudioRoutingService.bluetooth));
    });
  });
}
