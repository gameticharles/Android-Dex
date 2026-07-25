import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/device_state.dart';

class DesktopShelfServer {
  final DeviceState deviceState;
  final int port;
  HttpServer? _server;
  final List<WebSocketChannel> _connectedSockets = [];

  DesktopShelfServer({required this.deviceState, this.port = 8080});

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
      print('Desktop Shelf Server listening on port ${_server?.port}');
    } catch (_) {
      // Fallback to random free port if 8080 is busy
      _server = await io.serve(handler, InternetAddress.anyIPv4, 0, shared: true);
      print('Desktop Shelf Server listening on fallback port ${_server?.port}');
    }
  }

  Future<void> stop() async {
    await _server?.close();
  }
}
