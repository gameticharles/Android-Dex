import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class Contact {
  final String id;
  final String name;
  final String number;
  Uint8List? photoBytes;

  Contact({
    required this.id,
    required this.name,
    required this.number,
    this.photoBytes,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      number: json['number'] ?? '',
    );
  }
}

/// Performance Fix #3 & #4: Paginated contacts client with lazy binary photo fetching.
class ContactsService {
  final String baseUrl;
  final String authToken;

  ContactsService({required this.baseUrl, required this.authToken});

  /// Fetch page of contacts without photos (fast first render)
  Future<List<Contact>> fetchContactsPage({int offset = 0, int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/contacts/get_all')
        .replace(queryParameters: {
      'token': authToken,
      'offset': offset.toString(),
      'limit': limit.toString(),
      'photos': 'false', // Exclude Base64 photos
    });

    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List rawList = data['contacts'] ?? [];
      return rawList.map((j) => Contact.fromJson(j)).toList();
    }
    return [];
  }

  /// Lazy-load raw binary JPEG/WebP photo for a visible contact (Performance Fix #4)
  Future<Uint8List?> fetchContactPhoto(String contactId) async {
    final uri = Uri.parse('$baseUrl/contacts/photo/$contactId')
        .replace(queryParameters: {'token': authToken});

    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return res.bodyBytes; // Raw binary JPEG — no Base64 decode overhead!
    }
    return null;
  }
}
