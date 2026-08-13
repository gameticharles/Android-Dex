import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:adb_device_manager/core/models/device_state.dart';
import 'package:adb_device_manager/core/adb/real_adb_sync_service.dart';

class DesktopShelfServer {
  final DeviceState deviceState;
  final int port;
  HttpServer? _server;
  final List<WebSocketChannel> _connectedSockets = [];

  DesktopShelfServer({required this.deviceState, this.port = 38947});

  Future<void> start() async {
    final router = Router();

    // Ping healthcheck
    router.get('/ping', (Request req) {
      return Response.ok(
        jsonEncode({'status': 'success'}),
        headers: {'content-type': 'application/json'},
      );
    });

    // Register Android Device
    router.post('/add_me_to_server', (Request req) async {
      final body = await req.readAsString();
      final json = jsonDecode(body);
      if (json.containsKey('android')) {
        final a = json['android'];
        deviceState.deviceName.value = a['device_name'] ?? 'Android Device';
        deviceState.deviceIp.value = a['ip_address'] ?? '127.0.0.1';
        deviceState.isAppConnected.value = true;
      }
      return Response.ok(
        jsonEncode({'status': 'success'}),
        headers: {'content-type': 'application/json'},
      );
    });

    // Run Audio Broadcast
    router.post('/Run_audio_bordcast', (Request req) async {
      return Response.ok(
        jsonEncode({
          'status': 'success',
          'message': 'Audio broadcast started',
          'mode': 'fast'
        }),
        headers: {'content-type': 'application/json'},
      );
    });

    // 1. File Upload Route: POST /remote/upload_file
    router.post('/remote/upload_file', (Request req) async {
      try {
        final filename = req.headers['x-file-name'] ??
            'received_file_${DateTime.now().millisecondsSinceEpoch}.bin';
        final home = Platform.environment['HOME'] ?? '/home/user';
        final downloadsDir = Directory('$home/Downloads');
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
        final targetFile = File('${downloadsDir.path}/$filename');
        final bytes = await req.read().expand((b) => b).toList();
        await targetFile.writeAsBytes(bytes);

        deviceState.notifications.value = [
          RealNotificationItem(
            id: 'file_${DateTime.now().millisecondsSinceEpoch}',
            packageName: 'com.androiddex.companion',
            appName: 'File Transfer',
            title: 'File Received from Phone',
            body: '$filename saved to Downloads',
            timestamp: DateTime.now().toIso8601String(),
          ),
          ...deviceState.notifications.value,
        ];

        return Response.ok(
            jsonEncode({'status': 'success', 'filename': filename}),
            headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(
            body: jsonEncode({'status': 'error', 'message': e.toString()}),
            headers: {'content-type': 'application/json'});
      }
    });

    // 2. Presentation Remote Route: POST /remote/presentation
    router.post('/remote/presentation', (Request req) async {
      try {
        final body = await req.readAsString();
        final json = jsonDecode(body);
        final action = json['action'];

        const pythonBin = '/home/charlesgameti/anaconda3/bin/python3';
        if (action == 'next') {
          Process.run(pythonBin, ['-c', "import pynput; k = pynput.keyboard.Controller(); Key = pynput.keyboard.Key; k.press(Key.page_down); k.release(Key.page_down)"]);
        } else if (action == 'prev') {
          Process.run(pythonBin, ['-c', "import pynput; k = pynput.keyboard.Controller(); Key = pynput.keyboard.Key; k.press(Key.page_up); k.release(Key.page_up)"]);
        } else if (action == 'start') {
          Process.run(pythonBin, ['-c', "import pynput; k = pynput.keyboard.Controller(); Key = pynput.keyboard.Key; k.press(Key.f5); k.release(Key.f5)"]);
        } else if (action == 'blank') {
          Process.run(pythonBin, ['-c', "import pynput; k = pynput.keyboard.Controller(); k.press('b'); k.release('b')"]);
        }

        return Response.ok(jsonEncode({'status': 'success', 'action': action}),
            headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(
            body: jsonEncode({'status': 'error', 'message': e.toString()}),
            headers: {'content-type': 'application/json'});
      }
    });

    // 3. Remote Mouse/Trackpad & Keyboard Route: POST /remote/input
    router.post('/remote/input', (Request req) async {
      try {
        final body = await req.readAsString();
        final json = jsonDecode(body);
        final type = json['type'];
        const pythonBin = '/home/charlesgameti/anaconda3/bin/python3';

        if (type == 'move') {
          final dx = (json['dx'] ?? 0).toInt();
          final dy = (json['dy'] ?? 0).toInt();
          Process.run(pythonBin, ['-c', "import pynput; m = pynput.mouse.Controller(); m.move($dx, $dy)"]);
        } else if (type == 'click') {
          Process.run(pythonBin, ['-c', "import pynput; m = pynput.mouse.Controller(); Button = pynput.mouse.Button; m.click(Button.left)"]);
        } else if (type == 'rclick') {
          Process.run(pythonBin, ['-c', "import pynput; m = pynput.mouse.Controller(); Button = pynput.mouse.Button; m.click(Button.right)"]);
        } else if (type == 'scroll') {
          final dy = (json['dy'] ?? 0).toInt();
          Process.run(pythonBin, ['-c', "import pynput; m = pynput.mouse.Controller(); m.scroll(0, $dy)"]);
        } else if (type == 'type') {
          final text = json['text'] ?? '';
          final safeText = jsonEncode(text);
          Process.run(pythonBin, ['-c', "import pynput; k = pynput.keyboard.Controller(); k.type($safeText)"]);
        }

        return Response.ok(jsonEncode({'status': 'success'}),
            headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(
            body: jsonEncode({'status': 'error', 'message': e.toString()}),
            headers: {'content-type': 'application/json'});
      }
    });

    // 4. Multimedia & Computer Control Route: POST /remote/media
    router.post('/remote/media', (Request req) async {
      try {
        final body = await req.readAsString();
        final json = jsonDecode(body);
        final action = json['action'];

        if (action == 'vol_up') {
          Process.run('wpctl', ['set-volume', '@DEFAULT_AUDIO_SINK@', '5%+']).catchError((_) => Process.run('pactl', ['set-sink-volume', '@DEFAULT_SINK@', '+5%']));
        } else if (action == 'vol_down') {
          Process.run('wpctl', ['set-volume', '@DEFAULT_AUDIO_SINK@', '5%-']).catchError((_) => Process.run('pactl', ['set-sink-volume', '@DEFAULT_SINK@', '-5%']));
        } else if (action == 'vol_mute') {
          Process.run('wpctl', ['set-mute', '@DEFAULT_AUDIO_SINK@', 'toggle']).catchError((_) => Process.run('pactl', ['set-sink-mute', '@DEFAULT_SINK@', 'toggle']));
        } else if (action == 'play_pause') {
          Process.run('dbus-send', ['--type=method_call', '--dest=org.mpris.MediaPlayer2.spotify', '/org/mpris/MediaPlayer2', 'org.mpris.MediaPlayer2.Player.PlayPause']).catchError((_) => Process.run('pactl', ['set-sink-volume', '@DEFAULT_SINK@', '5%+']));
        } else if (action == 'next') {
          Process.run('dbus-send', ['--type=method_call', '--dest=org.mpris.MediaPlayer2.spotify', '/org/mpris/MediaPlayer2', 'org.mpris.MediaPlayer2.Player.Next']);
        } else if (action == 'prev') {
          Process.run('dbus-send', ['--type=method_call', '--dest=org.mpris.MediaPlayer2.spotify', '/org/mpris/MediaPlayer2', 'org.mpris.MediaPlayer2.Player.Previous']);
        } else if (action == 'lock') {
          Process.run('loginctl', ['lock-session']);
        }

        return Response.ok(jsonEncode({'status': 'success', 'action': action}),
            headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(
            body: jsonEncode({'status': 'error', 'message': e.toString()}),
            headers: {'content-type': 'application/json'});
      }
    });

    // WebSocket Handler
    final wsHandler = webSocketHandler((WebSocketChannel webSocket) {
      _connectedSockets.add(webSocket);
      webSocket.stream.listen(
        (message) {
          try {
            final json = jsonDecode(message.toString());
            deviceState.updateFromTelemetry(json);
          } catch (_) {}
        },
        onDone: () => _connectedSockets.remove(webSocket),
      );
    });

    router.all('/ws', wsHandler);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    try {
      _server = await io.serve(handler, InternetAddress.anyIPv4, port, shared: true);
      debugPrint('Desktop Shelf Server listening on port ${_server?.port}');
    } catch (_) {
      // Fallback to random free port if 8080 is busy
      _server = await io.serve(handler, InternetAddress.anyIPv4, 0, shared: true);
      debugPrint('Desktop Shelf Server listening on fallback port ${_server?.port}');
    }
  }

  Future<void> stop() async {
    await _server?.close();
  }
}
