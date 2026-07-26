import 'dart:convert';
import 'dart:io';
import 'adb_device_scanner.dart';

class RealSmsMessage {
  final String address;
  final String body;
  final String date;

  RealSmsMessage({
    required this.address,
    required this.body,
    required this.date,
  });
}

class RealContactItem {
  final String id;
  final String name;
  final String number;

  RealContactItem({
    required this.id,
    required this.name,
    required this.number,
  });
}

class RealCallLogItem {
  final String name;
  final String number;
  final String type; // 1: Incoming, 2: Outgoing, 3: Missed
  final String duration;
  final String timestamp;

  RealCallLogItem({
    required this.name,
    required this.number,
    required this.type,
    required this.duration,
    required this.timestamp,
  });
}

class RealNotificationItem {
  final String id;
  final String packageName;
  final String title;
  final String body;
  final String timestamp;
  final String appName;
  final List<String> actions;

  RealNotificationItem({
    required this.id,
    required this.packageName,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.appName,
    this.actions = const [],
  });
}

class RealAdbSyncService {
  /// Normalize phone number to last 9 digits for cross-matching
  static String normalizeNumber(String raw) {
    String clean = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length > 9) {
      clean = clean.substring(clean.length - 9);
    }
    return clean;
  }

  /// Fetch real live SMS from Android phone
  static Future<List<RealSmsMessage>> fetchRealSms() async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    final result = await Process.run(
        adbPath, ['shell', 'content', 'query', '--uri', 'content://sms/inbox']);

    final blocks = result.stdout.toString().split('Row: ');
    final List<RealSmsMessage> messages = [];

    for (final block in blocks) {
      if (block.trim().isEmpty) continue;
      final single = block.replaceAll('\n', ' ');

      String address = 'Unknown';
      String body = '';
      String date = '';

      final addrMatch = RegExp(r'address=([^,]+)').firstMatch(single);
      if (addrMatch != null) address = addrMatch.group(1)?.trim() ?? 'Unknown';

      final bodyMatch = RegExp(
              r'body=(.*?)(,\s*service_center=|\,\s*locked=|\,\s*date=|\s*$)')
          .firstMatch(single);
      if (bodyMatch != null) body = bodyMatch.group(1)?.trim() ?? '';

      final dateMatch = RegExp(r'date=([0-9]+)').firstMatch(single);
      if (dateMatch != null) date = dateMatch.group(1)?.trim() ?? '';

      if (body.isNotEmpty) {
        messages.add(RealSmsMessage(address: address, body: body, date: date));
      }
    }

    return messages;
  }

  /// Fetch real live Contacts from Android phone (2,300+ contacts)
  static Future<List<RealContactItem>> fetchRealContacts() async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    final result = await Process.run(adbPath, [
      'shell',
      'content',
      'query',
      '--uri',
      'content://com.android.contacts/data/phones'
    ]);

    final blocks = result.stdout.toString().split('Row: ');
    final List<RealContactItem> contacts = [];
    final Set<String> seenNumbers = {};

    for (final block in blocks) {
      if (block.trim().isEmpty) continue;
      final single = block.replaceAll('\n', ' ');

      String name = '';
      String number = '';
      String id = '';

      final nameMatch = RegExp(r'display_name=([^,]+)').firstMatch(single);
      if (nameMatch != null) name = nameMatch.group(1)?.trim() ?? '';

      final numMatch = RegExp(r'data1=([^,]+)').firstMatch(single);
      if (numMatch != null) number = numMatch.group(1)?.trim() ?? '';

      final idMatch = RegExp(r'contact_id=([0-9]+)').firstMatch(single);
      if (idMatch != null) id = idMatch.group(1)?.trim() ?? '';

      final cleanNum = normalizeNumber(number);
      if (number.isNotEmpty &&
          name.isNotEmpty &&
          name != 'NULL' &&
          cleanNum.length >= 7 &&
          !seenNumbers.contains(cleanNum)) {
        seenNumbers.add(cleanNum);
        contacts.add(RealContactItem(
          id: id.isEmpty
              ? DateTime.now().millisecondsSinceEpoch.toString()
              : id,
          name: name,
          number: number,
        ));
      }
    }

    contacts
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return contacts;
  }

  /// Fetch real live Call Logs mapped to Contacts (2,000+ call logs)
  static Future<List<RealCallLogItem>> fetchRealCallLogs() async {
    final adbPath = await AdbDeviceScanner.getAdbPath();

    // 1. Fetch contacts dictionary for robust matching
    final contacts = await fetchRealContacts();
    final Map<String, String> phoneToName = {};
    for (final c in contacts) {
      final clean = normalizeNumber(c.number);
      if (clean.length >= 7) {
        phoneToName[clean] = c.name;
      }
    }

    // 2. Query call logs
    final result = await Process.run(adbPath,
        ['shell', 'content', 'query', '--uri', 'content://call_log/calls']);

    final blocks = result.stdout.toString().split('Row: ');
    final List<RealCallLogItem> calls = [];

    for (final block in blocks) {
      if (block.trim().isEmpty) continue;
      final single = block.replaceAll('\n', ' ');

      String name = '';
      String number = '';
      String type = '1';
      String duration = '0';
      String dateMs = '';

      final nameMatch = RegExp(r'name=([^,]+)').firstMatch(single);
      if (nameMatch != null) {
        final val = nameMatch.group(1)?.trim() ?? '';
        if (val.isNotEmpty && val != 'NULL' && !val.startsWith('com.android')) {
          name = val;
        }
      }

      final numMatch = RegExp(r'number=([^,]+)').firstMatch(single);
      if (numMatch != null) number = numMatch.group(1)?.trim() ?? '';

      final typeMatch = RegExp(r'type=([0-9]+)').firstMatch(single);
      if (typeMatch != null) type = typeMatch.group(1)?.trim() ?? '1';

      final durMatch = RegExp(r'duration=([0-9]+)').firstMatch(single);
      if (durMatch != null) duration = durMatch.group(1)?.trim() ?? '0';

      final dateMatch = RegExp(r'date=([0-9]+)').firstMatch(single);
      if (dateMatch != null) dateMs = dateMatch.group(1)?.trim() ?? '';

      if (number.isNotEmpty) {
        final cleanNum = normalizeNumber(number);
        if (name.isEmpty && phoneToName.containsKey(cleanNum)) {
          name = phoneToName[cleanNum]!;
        } else if (name.isEmpty) {
          name = number;
        }

        // Format time timestamp
        String formattedTime = "14:00";
        if (dateMs.isNotEmpty) {
          final dt =
              DateTime.fromMillisecondsSinceEpoch(int.tryParse(dateMs) ?? 0);
          formattedTime =
              "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        }

        calls.add(RealCallLogItem(
          name: name,
          number: number,
          type: type,
          duration: duration,
          timestamp: formattedTime,
        ));
      }
    }

    return calls;
  }

  /// Fetch real active notifications from connected Android phone
  static Future<List<RealNotificationItem>> fetchRealNotifications() async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      final result = await Process.run(adbPath, [
        'shell',
        'dumpsys',
        'notification',
        '--noredact',
      ]);

      final output = result.stdout.toString();
      final List<RealNotificationItem> items = [];

      final records = output.split('NotificationRecord(');

      for (int i = 1; i < records.length; i++) {
        final rec = records[i];

        final pkgMatch = RegExp(r'pkg=([^\s]+)').firstMatch(rec);
        final pkg = pkgMatch?.group(1) ?? 'android';

        // Ignore system noise
        if (pkg == 'com.android.systemui' && rec.contains('USB debugging'))
          continue;

        String title = '';
        String text = '';

        final titleMatch =
            RegExp(r'android\.title=(.*?)(?=\n|\r|android\.)').firstMatch(rec);
        if (titleMatch != null) {
          title = titleMatch
                  .group(1)
                  ?.replaceAll(RegExp(r'^"|"|\s+$'), '')
                  .trim() ??
              '';
        }

        final textMatch =
            RegExp(r'android\.text=(.*?)(?=\n|\r|android\.)').firstMatch(rec);
        if (textMatch != null) {
          text =
              textMatch.group(1)?.replaceAll(RegExp(r'^"|"|\s+$'), '').trim() ??
                  '';
        }

        if (title.isNotEmpty || text.isNotEmpty) {
          String appName = pkg.split('.').last;
          if (appName.isNotEmpty) {
            appName = appName[0].toUpperCase() + appName.substring(1);
          }

          final List<String> parsedActions = [];
          final actionMatches =
              RegExp(r'title="([^"]+)"|Action\(title=(.*?)(?:,|\))')
                  .allMatches(rec);
          for (final m in actionMatches) {
            final act = (m.group(1) ?? m.group(2))?.trim();
            if (act != null &&
                act.isNotEmpty &&
                act != title &&
                !parsedActions.contains(act) &&
                act.length < 30) {
              parsedActions.add(act);
            }
          }

          if (parsedActions.isEmpty) {
            if (pkg.contains('messaging') ||
                pkg.contains('sms') ||
                pkg.contains('whatsapp')) {
              parsedActions.addAll(['Reply', 'Mark as read']);
            } else if (pkg.contains('dialer') ||
                pkg.contains('telecom') ||
                pkg.contains('phone')) {
              parsedActions.addAll(['Callback', 'Message']);
            } else if (pkg.contains('mail') || pkg.contains('gmail')) {
              parsedActions.addAll(['Reply', 'Archive']);
            } else if (pkg.contains('youtube') ||
                pkg.contains('spotify') ||
                pkg.contains('music')) {
              parsedActions.addAll(['Pause', 'Next']);
            }
          }

          final now = DateTime.now();
          final timeStr =
              "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

          items.add(RealNotificationItem(
            id: 'notif_${i}_${pkg}',
            packageName: pkg,
            title: title.isNotEmpty ? title : appName,
            body: text.isNotEmpty ? text : 'New notification',
            timestamp: timeStr,
            appName: appName,
            actions: parsedActions,
          ));
        }
      }

      return items;
    } catch (_) {
      return [];
    }
  }

  /// Fetch real active media session state from connected Android phone
  static Future<RealMediaState> fetchRealMediaState(
      {RealMediaState? currentState}) async {
    // 1. Try fetching from Android Companion app HTTP route first
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 400);
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:8080/media'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final bodyStr = await res.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr) as Map<String, dynamic>;
        client.close();

        final title = json['title']?.toString() ?? '';
        final artist = json['artist']?.toString() ?? '';
        final album = json['album']?.toString() ?? '';
        final pkg = json['package_name']?.toString() ?? '';
        final isPlaying = json['is_playing'] == true;
        final posMs = (json['position_ms'] as num?)?.toInt() ?? 0;
        final durMs = (json['duration_ms'] as num?)?.toInt() ?? 0;
        final artBase64 = json['artwork_base64']?.toString();
        final artUrl = json['artwork_url']?.toString();

        if (title.isNotEmpty && title != "No Active Media") {
          return RealMediaState(
            title: title,
            artist: artist,
            album: album,
            packageName: pkg,
            isPlaying: isPlaying,
            positionMs: posMs,
            durationMs:
                durMs > 0 ? durMs : (currentState?.durationMs ?? 225000),
            artworkBase64: artBase64 ?? currentState?.artworkBase64,
            artworkUrl: artUrl ?? currentState?.artworkUrl,
          );
        }
      }
    } catch (_) {}

    // 2. Robust ADB dumpsys media_session parsing
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      final result = await Process.run(adbPath, [
        'shell',
        'dumpsys',
        'media_session',
      ]);

      final output = result.stdout.toString();

      final audioResult = await Process.run(adbPath, [
        'shell',
        'dumpsys',
        'audio',
      ]);
      final audioOutput = audioResult.stdout.toString();

      bool isPlaying = output.contains('state=PLAYING(3)') ||
          output.contains('state=3') ||
          output.contains('state=STATE_PLAYING') ||
          output.contains('PlaybackState {state=3') ||
          output.contains('PlaybackState {state=PLAYING') ||
          audioOutput.contains('isMusicActive()=true') ||
          audioOutput.contains('mIsMusicActive=true');

      // Target active session block under 'Sessions Stack'
      String targetOutput = output;
      final stackIdx = output.indexOf('Sessions Stack');
      if (stackIdx != -1) {
        targetOutput = output.substring(stackIdx);
      }

      String pkg = currentState?.packageName ?? '';
      String title = currentState?.title ?? '';
      String artist = currentState?.artist ?? '';
      String album = currentState?.album ?? '';
      int durationMs =
          (currentState?.durationMs != null && currentState!.durationMs > 0)
              ? currentState.durationMs
              : 225000;
      int positionMs = currentState?.positionMs ?? 0;
      String? artworkBase64 = currentState?.artworkBase64;
      String? artworkUrl = currentState?.artworkUrl;

      // Match active package under Sessions Stack
      final pkgMatch = RegExp(r'package=([^\s,]+)').firstMatch(targetOutput) ??
          RegExp(r'pkg=([^\s,]+)').firstMatch(targetOutput);
      if (pkgMatch != null) {
        final parsedPkg = pkgMatch.group(1) ?? '';
        if (parsedPkg.isNotEmpty && parsedPkg != 'com.android.server.telecom') {
          pkg = parsedPkg;
        }
      }

      // Parse metadata description line: "description=Title, Artist, Album"
      final descMatch =
          RegExp(r'description=(.*?)(?=\n|\r|queueTitle=|\s{2,}|$)')
              .firstMatch(targetOutput);
      if (descMatch != null) {
        final descStr = descMatch.group(1)?.trim() ?? '';
        if (descStr.isNotEmpty && descStr != 'null') {
          // Split specifically by ", " (comma space) as formatted by Android dumpsys
          final parts = descStr.split(RegExp(r',\s+'));
          if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
            title = parts[0].trim();
          }
          if (parts.length > 1 && parts[1].trim().isNotEmpty) {
            artist = parts[1].trim();
          }
          if (parts.length > 2 && parts[2].trim().isNotEmpty) {
            album = parts[2].trim();
          }
        }
      }

      // Check explicit metadata fields if available
      final metadataTitle =
          RegExp(r'android\.media\.metadata\.TITLE=(.*?)(?=\n|\r|android\.)')
              .firstMatch(targetOutput);
      if (metadataTitle != null) {
        final val =
            metadataTitle.group(1)?.replaceAll(RegExp(r'^"|"|\s+$'), '').trim();
        if (val != null && val.isNotEmpty && val != 'null') title = val;
      }

      final metadataArtist = RegExp(
                  r'android\.media\.metadata\.ARTIST=(.*?)(?=\n|\r|android\.)')
              .firstMatch(targetOutput) ??
          RegExp(r'android\.media\.metadata\.ALBUM_ARTIST=(.*?)(?=\n|\r|android\.)')
              .firstMatch(targetOutput);
      if (metadataArtist != null) {
        final val = metadataArtist
            .group(1)
            ?.replaceAll(RegExp(r'^"|"|\s+$'), '')
            .trim();
        if (val != null && val.isNotEmpty && val != 'null') artist = val;
      }

      final metadataAlbum =
          RegExp(r'android\.media\.metadata\.ALBUM=(.*?)(?=\n|\r|android\.)')
              .firstMatch(targetOutput);
      if (metadataAlbum != null) {
        final val =
            metadataAlbum.group(1)?.replaceAll(RegExp(r'^"|"|\s+$'), '').trim();
        if (val != null && val.isNotEmpty && val != 'null') album = val;
      }

      final durMatch = RegExp(r'android\.media\.metadata\.DURATION=([0-9]+)')
              .firstMatch(targetOutput) ??
          RegExp(r'\bduration=([0-9]+)').firstMatch(targetOutput) ??
          RegExp(r'durationMs=([0-9]+)').firstMatch(targetOutput);
      if (durMatch != null) {
        final parsedDur = int.tryParse(durMatch.group(1)!);
        if (parsedDur != null && parsedDur > 0) durationMs = parsedDur;
      }

      // Parse position accurately from PlaybackState
      final posMatch = RegExp(r'PlaybackState\s*\{[^}]*?\bposition=([0-9]+)')
              .firstMatch(targetOutput) ??
          RegExp(r'(?<!buffered\s)\bposition=([0-9]+)')
              .firstMatch(targetOutput);
      if (posMatch != null) {
        final parsedPos = int.tryParse(posMatch.group(1)!);
        if (parsedPos != null && parsedPos > 0) {
          positionMs = parsedPos;
        } else if (isPlaying && positionMs > 0) {
          // If dumpsys returns 0 while playing, increment position naturally
          positionMs += 1000;
        }
      } else if (isPlaying) {
        positionMs += 1000;
      }

      final artUriMatch = RegExp(
              r'android\.media\.metadata\.(?:ART_URI|ALBUM_ART_URI)=(.*?)(?=\n|\r|android\.)')
          .firstMatch(targetOutput);
      if (artUriMatch != null) {
        final uri =
            artUriMatch.group(1)?.replaceAll(RegExp(r'^"|"|\s+$'), '').trim();
        if (uri != null && uri.isNotEmpty) {
          artworkUrl = uri;
        }
      }

      if (title.isEmpty) {
        if (pkg.isNotEmpty) {
          final appName = pkg.split('.').last;
          if (appName.isNotEmpty) {
            title = appName[0].toUpperCase() + appName.substring(1);
          } else {
            title = "Dex Stream";
          }
        } else {
          title = "Dex Stream";
        }
      }

      if (artist.isEmpty) {
        artist = "Android Device Audio";
      }

      return RealMediaState(
        title: title,
        artist: artist,
        album: album,
        packageName: pkg,
        isPlaying: isPlaying,
        durationMs: durationMs,
        positionMs: positionMs,
        artworkBase64: artworkBase64,
        artworkUrl: artworkUrl,
      );
    } catch (_) {
      return currentState ?? const RealMediaState();
    }
  }

  /// Send seek command to active Android MediaSession
  static Future<void> seekMedia(int positionMs) async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      await Process.run(adbPath, [
        'shell',
        'cmd',
        'media_session',
        'seek',
        positionMs.toString(),
      ]);
    } catch (_) {}
  }
}

class RealMediaState {
  final String title;
  final String artist;
  final String album;
  final String packageName;
  final bool isPlaying;
  final int positionMs;
  final int durationMs;
  final String? artworkBase64;
  final String? artworkUrl;

  const RealMediaState({
    this.title = "No Active Media",
    this.artist = "Android DEX Audio Engine",
    this.album = "",
    this.packageName = "",
    this.isPlaying = false,
    this.positionMs = 0,
    this.durationMs = 225000,
    this.artworkBase64,
    this.artworkUrl,
  });

  double get positionProgress {
    if (durationMs <= 0) return 0.0;
    final double p = positionMs / durationMs;
    return p.clamp(0.0, 1.0);
  }

  RealMediaState copyWith({
    String? title,
    String? artist,
    String? album,
    String? packageName,
    bool? isPlaying,
    int? positionMs,
    int? durationMs,
    String? artworkBase64,
    String? artworkUrl,
  }) {
    return RealMediaState(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      packageName: packageName ?? this.packageName,
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
      artworkBase64: artworkBase64 ?? this.artworkBase64,
      artworkUrl: artworkUrl ?? this.artworkUrl,
    );
  }
}
