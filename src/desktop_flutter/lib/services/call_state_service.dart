import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device_state.dart';
import 'real_adb_sync_service.dart';

class CallStateData {
  final String state; // "IDLE", "RINGING", "ACTIVE"
  final String name;
  final String number;
  final String location;
  final int durationSec;
  final bool isSpeakerOn;

  CallStateData({
    required this.state,
    required this.name,
    required this.number,
    required this.location,
    required this.durationSec,
    this.isSpeakerOn = false,
  });

  factory CallStateData.idle() {
    return CallStateData(
      state: "IDLE",
      name: "",
      number: "",
      location: "",
      durationSec: 0,
    );
  }

  factory CallStateData.fromJson(Map<String, dynamic> json) {
    return CallStateData(
      state: json['state'] as String? ?? "IDLE",
      name: json['name'] as String? ?? "Unknown Caller",
      number: json['number'] as String? ?? "",
      location: json['location'] as String? ?? "Mobile Call",
      durationSec: (json['duration_sec'] as num?)?.toInt() ?? 0,
      isSpeakerOn: json['is_speaker_on'] as bool? ?? false,
    );
  }
}

class CallStateService {
  static final ValueNotifier<CallStateData> currentCallState =
      ValueNotifier<CallStateData>(CallStateData.idle());

  static Timer? _pollTimer;
  static Timer? _durationTimer;
  static int _activeDurationCounter = 0;

  static const String _adbPath =
      '/home/charlesgameti/Documents/GitHub/Android-Dex/reengineering/linux_extracted/All helper_linux/platform-tools/adb';

  static void startSync([DeviceState? deviceState]) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 800), (_) async {
      await _fetchCallState(deviceState);
    });
  }

  static void stopSync() {
    _pollTimer?.cancel();
    _durationTimer?.cancel();
    _pollTimer = null;
    _durationTimer = null;
  }

  static Future<void> _fetchCallState([DeviceState? deviceState]) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 600);
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:8080/telephony/state'));
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body);
        if (json['status'] == 'success' && json['call'] != null) {
          final newState = CallStateData.fromJson(json['call']);
          _updateState(newState);
          return;
        }
      }
    } catch (_) {}

    // Fallback: Check if notification feed contains call notifications
    _checkNotificationCallFallback(deviceState);
  }

  static void _checkNotificationCallFallback(DeviceState? deviceState) {
    if (deviceState == null) return;
    final notifs = deviceState.notifications.value;
    final callNotif = notifs.firstWhere(
      (n) =>
          n.packageName.contains('dialer') ||
          n.packageName.contains('telecom') ||
          n.packageName.contains('phone') ||
          n.title.toLowerCase().contains('incoming call') ||
          n.title.toLowerCase().contains('calling'),
      orElse: () => RealNotificationItem(
        id: "",
        packageName: "",
        appName: "",
        title: "",
        body: "",
        timestamp: "",
      ),
    );

    if (callNotif.packageName.isNotEmpty &&
        currentCallState.value.state == "IDLE") {
      currentCallState.value = CallStateData(
        state: "RINGING",
        name: callNotif.title.isNotEmpty ? callNotif.title : "Incoming Call",
        number: "",
        location: callNotif.body.isNotEmpty ? callNotif.body : "Mobile Call",
        durationSec: 0,
      );
    }
  }

  static void _updateState(CallStateData newState) {
    if (newState.state == "ACTIVE" &&
        currentCallState.value.state != "ACTIVE") {
      _startDurationTimer();
    } else if (newState.state != "ACTIVE") {
      _durationTimer?.cancel();
      _activeDurationCounter = 0;
    }

    if (newState.state == "ACTIVE") {
      currentCallState.value = CallStateData(
        state: newState.state,
        name: newState.name.isNotEmpty ? newState.name : "Sophia",
        number: newState.number,
        location: newState.location,
        durationSec: newState.durationSec > 0
            ? newState.durationSec
            : _activeDurationCounter,
        isSpeakerOn: newState.isSpeakerOn,
      );
    } else {
      currentCallState.value = newState;
    }
  }

  static void _startDurationTimer() {
    _durationTimer?.cancel();
    _activeDurationCounter = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _activeDurationCounter++;
      if (currentCallState.value.state == "ACTIVE") {
        currentCallState.value = CallStateData(
          state: "ACTIVE",
          name: currentCallState.value.name,
          number: currentCallState.value.number,
          location: currentCallState.value.location,
          durationSec: _activeDurationCounter,
          isSpeakerOn: currentCallState.value.isSpeakerOn,
        );
      }
    });
  }

  static Future<void> answerCall() async {
    // 1. HTTP Endpoint Call
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 600)
      ..idleTimeout = Duration.zero;
    try {
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:8080/telephony/answer'));
      req.headers.set('Connection', 'close');
      await req.close();
    } catch (_) {
    } finally {
      client.close(force: true);
    }

    // 2. ADB Telecom / Keyevent Fallback
    try {
      await Process.run(_adbPath, ['shell', 'telecom', 'accept-ringing-call']);
    } catch (_) {
      try {
        await Process.run(_adbPath, ['shell', 'input', 'keyevent', '5']);
      } catch (_) {}
    }

    _startDurationTimer();
    currentCallState.value = CallStateData(
      state: "ACTIVE",
      name: currentCallState.value.name.isNotEmpty
          ? currentCallState.value.name
          : "Sophia",
      number: currentCallState.value.number,
      location: currentCallState.value.location,
      durationSec: 0,
      isSpeakerOn: currentCallState.value.isSpeakerOn,
    );
  }

  static Future<void> endCall() async {
    // 1. HTTP Endpoint Call
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 600)
      ..idleTimeout = Duration.zero;
    try {
      final req =
          await client.getUrl(Uri.parse('http://127.0.0.1:8080/telephony/end'));
      req.headers.set('Connection', 'close');
      await req.close();
    } catch (_) {
    } finally {
      client.close(force: true);
    }

    // 2. ADB Keyevent Fallback
    try {
      await Process.run(_adbPath, ['shell', 'telecom', 'end-call']);
    } catch (_) {
      try {
        await Process.run(_adbPath, ['shell', 'input', 'keyevent', '6']);
      } catch (_) {}
    }

    _durationTimer?.cancel();
    _activeDurationCounter = 0;
    currentCallState.value = CallStateData.idle();
  }

  static Future<void> toggleSpeaker() async {
    final curSpeaker = currentCallState.value.isSpeakerOn;
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 600)
      ..idleTimeout = Duration.zero;
    try {
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:8080/telephony/toggle_speaker'));
      req.headers.set('Connection', 'close');
      await req.close();
    } catch (_) {
    } finally {
      client.close(force: true);
    }

    currentCallState.value = CallStateData(
      state: currentCallState.value.state,
      name: currentCallState.value.name,
      number: currentCallState.value.number,
      location: currentCallState.value.location,
      durationSec: currentCallState.value.durationSec,
      isSpeakerOn: !curSpeaker,
    );
  }

  // Trigger simulated incoming call for testing
  static void triggerSimulatedCall(
      {String name = "Sophia", String location = "Shenzhen"}) {
    currentCallState.value = CallStateData(
      state: "RINGING",
      name: name,
      number: "+8613800000000",
      location: location,
      durationSec: 0,
    );
  }
}
