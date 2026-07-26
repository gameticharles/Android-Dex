import 'dart:convert';
import 'dart:io';
import 'desktop_identity_service.dart';

class PairingResult {
  final String status; // "APPROVED", "PENDING", "REJECTED", "FAILED"
  final String deviceId;
  final String computerName;
  final String? authToken;

  PairingResult({
    required this.status,
    required this.deviceId,
    required this.computerName,
    this.authToken,
  });
}

/**
 * Client service executing pairing protocol with Android Companion.
 */
class PairingService {
  static Future<PairingResult> requestPairing() async {
    final deviceId = await DesktopIdentityService.getDeviceId();
    final computerName = DesktopIdentityService.getComputerName();

    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1000)
      ..idleTimeout = Duration.zero;

    try {
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:8080/pairing/request'));
      req.headers.set('content-type', 'application/json');
      req.headers.set('Connection', 'close');
      req.add(utf8.encode(jsonEncode({
        'device_id': deviceId,
        'computer_name': computerName,
        'ip': '127.0.0.1',
      })));

      final res = await req.close();
      if (res.statusCode == 200) {
        final bodyStr = await res.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr) as Map<String, dynamic>;
        final status = json['status']?.toString() ?? 'FAILED';
        final token = json['auth_token']?.toString();
        if (status == 'APPROVED' && token != null) {
          DesktopIdentityService.activeAuthToken = token;
        }
        return PairingResult(
          status: status,
          deviceId: deviceId,
          computerName: computerName,
          authToken: token,
        );
      }
    } catch (_) {} finally {
      client.close(force: true);
    }
    return PairingResult(
      status: 'FAILED',
      deviceId: deviceId,
      computerName: computerName,
    );
  }

  static Future<PairingResult> checkPairingStatus() async {
    final deviceId = await DesktopIdentityService.getDeviceId();
    final computerName = DesktopIdentityService.getComputerName();

    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 800)
      ..idleTimeout = Duration.zero;

    try {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:8080/pairing/status?device_id=$deviceId'));
      req.headers.set('Connection', 'close');
      final res = await req.close();
      if (res.statusCode == 200) {
        final bodyStr = await res.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr) as Map<String, dynamic>;
        final status = json['status']?.toString() ?? 'UNKNOWN';
        final token = json['auth_token']?.toString();
        if (status == 'APPROVED' && token != null) {
          DesktopIdentityService.activeAuthToken = token;
        }
        return PairingResult(
          status: status,
          deviceId: deviceId,
          computerName: computerName,
          authToken: token,
        );
      }
    } catch (_) {} finally {
      client.close(force: true);
    }
    return PairingResult(
      status: 'FAILED',
      deviceId: deviceId,
      computerName: computerName,
    );
  }
}
