import 'dart:io';
import 'dart:math';
import 'adb_device_scanner.dart';

enum FileCategory {
  directory,
  image,
  video,
  audio,
  document,
  code,
  archive,
  file,
}

class StorageInfo {
  final String total;
  final String used;
  final String available;
  final double percentage;

  StorageInfo({
    required this.total,
    required this.used,
    required this.available,
    required this.percentage,
  });
}

class PhoneFileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int sizeBytes;
  final String formattedSize;
  final String extension;
  final FileCategory category;
  final String modifiedDate;

  PhoneFileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.sizeBytes,
    required this.formattedSize,
    required this.extension,
    required this.category,
    this.modifiedDate = '',
  });
}

class FileManagerService {
  /// Helper to determine category from file extension
  static FileCategory determineCategory(String name, bool isDir) {
    if (isDir) return FileCategory.directory;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'].contains(ext)) {
      return FileCategory.image;
    }
    if (['mp4', 'mkv', 'webm', 'avi', 'mov', 'flv', '3gp'].contains(ext)) {
      return FileCategory.video;
    }
    if (['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'].contains(ext)) {
      return FileCategory.audio;
    }
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'rtf'].contains(ext)) {
      return FileCategory.document;
    }
    if (['json', 'xml', 'yaml', 'yml', 'dart', 'js', 'ts', 'html', 'css', 'py', 'sh', 'c', 'cpp', 'java', 'kt', 'txt', 'log', 'md'].contains(ext)) {
      return FileCategory.code;
    }
    if (['zip', 'tar', 'gz', '7z', 'rar', 'apk'].contains(ext)) {
      return FileCategory.archive;
    }
    return FileCategory.file;
  }

  /// Helper to format raw bytes into human readable format
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    if (i >= suffixes.length) i = suffixes.length - 1;
    double num = bytes / pow(1024, i);
    return '${num.toStringAsFixed(num < 10 && i > 0 ? 1 : 0)} ${suffixes[i]}';
  }

  /// Fetch storage information for a path (e.g. /sdcard)
  static Future<StorageInfo?> getStorageInfo([String path = '/sdcard']) async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      final result = await Process.run(adbPath, ['shell', 'df', '-h', path]);
      final lines = result.stdout.toString().trim().split('\n');

      if (lines.length >= 2) {
        // Last line usually contains the mount details
        final parts = lines.last.trim().split(RegExp(r'\s+'));
        if (parts.length >= 5) {
          final total = parts[1];
          final used = parts[2];
          final avail = parts[3];
          final pctStr = parts[4].replaceAll('%', '');
          final pct = (double.tryParse(pctStr) ?? 0.0) / 100.0;

          return StorageInfo(
            total: total,
            used: used,
            available: avail,
            percentage: pct.clamp(0.0, 1.0),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// List files in a directory on the connected Android phone
  static Future<List<PhoneFileItem>> listDirectory(String remotePath) async {
    final adbPath = await AdbDeviceScanner.getAdbPath();

    // First try ls -la for detailed list
    final result = await Process.run(adbPath, ['shell', 'ls', '-la', remotePath]);
    final stdout = result.stdout.toString();
    final lines = stdout.split('\n');

    final List<PhoneFileItem> items = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('total ')) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 4) continue;

      final permissions = parts[0];
      final isDir = permissions.startsWith('d');
      final isSymlink = permissions.startsWith('l');

      // In ls -la, filename is the last token (or multi-word if contains spaces, or symlink 'name -> target')
      // Standard android ls -la: [perms, links, owner, group, size, date, time, name]
      String rawName = '';
      int sizeBytes = 0;
      String dateStr = '';

      if (parts.length >= 8) {
        sizeBytes = int.tryParse(parts[4]) ?? 0;
        dateStr = '${parts[5]} ${parts[6]}';
        rawName = parts.sublist(7).join(' ');
      } else {
        rawName = parts.last;
      }

      // Handle symlinks target format "name -> target"
      if (isSymlink && rawName.contains(' -> ')) {
        rawName = rawName.split(' -> ').first;
      }

      if (rawName == '.' || rawName == '..') continue;

      final String cleanName = rawName.endsWith('/') ? rawName.substring(0, rawName.length - 1) : rawName;
      final String fullPath = remotePath.endsWith('/') ? '$remotePath$cleanName' : '$remotePath/$cleanName';
      final String ext = cleanName.contains('.') ? cleanName.split('.').last.toLowerCase() : '';
      final cat = determineCategory(cleanName, isDir);

      items.add(PhoneFileItem(
        name: cleanName,
        path: fullPath,
        isDirectory: isDir,
        sizeBytes: sizeBytes,
        formattedSize: isDir ? 'Folder' : formatBytes(sizeBytes),
        extension: ext,
        category: cat,
        modifiedDate: dateStr,
      ));
    }

    // Fallback if ls -la produced no items (e.g. restricted directory output)
    if (items.isEmpty) {
      final fallbackResult = await Process.run(adbPath, ['shell', 'ls', '-1', '-F', remotePath]);
      final fbLines = fallbackResult.stdout.toString().split('\n');
      for (final line in fbLines) {
        final t = line.trim();
        if (t.isEmpty || t == '.' || t == '..') continue;

        final bool isDir = t.endsWith('/');
        final String cleanName = isDir ? t.substring(0, t.length - 1) : t;
        final String fullPath = remotePath.endsWith('/') ? '$remotePath$cleanName' : '$remotePath/$cleanName';
        final String ext = cleanName.contains('.') ? cleanName.split('.').last.toLowerCase() : '';
        final cat = determineCategory(cleanName, isDir);

        items.add(PhoneFileItem(
          name: cleanName,
          path: fullPath,
          isDirectory: isDir,
          sizeBytes: 0,
          formattedSize: isDir ? 'Folder' : 'File',
          extension: ext,
          category: cat,
        ));
      }
    }

    // Sort: directories first, then files alphabetically
    items.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  /// Create a new folder on the remote path
  static Future<bool> createDirectory(String remotePath) async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    final res = await Process.run(adbPath, ['shell', 'mkdir', '-p', remotePath]);
    return res.exitCode == 0;
  }

  /// Delete a file or directory on the remote path
  static Future<bool> deleteItem(String remotePath) async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    final res = await Process.run(adbPath, ['shell', 'rm', '-rf', remotePath]);
    return res.exitCode == 0;
  }

  /// Fetch a temporary preview file on local machine
  static Future<String?> fetchPreviewFile(String remotePath) async {
    try {
      final adbPath = await AdbDeviceScanner.getAdbPath();
      final tempDir = Directory('/tmp/android_dex_previews');
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }

      final fileName = remotePath.split('/').last;
      final localPath = '${tempDir.path}/$fileName';

      final res = await Process.run(adbPath, ['pull', remotePath, localPath]);
      if (res.exitCode == 0 && await File(localPath).exists()) {
        return localPath;
      }
    } catch (_) {}
    return null;
  }

  /// Push a local file from PC to Android phone
  static Future<bool> pushFile(String localPath, String remoteDir) async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    final res = await Process.run(adbPath, ['push', localPath, remoteDir]);
    return res.exitCode == 0;
  }

  /// Pull a file from Android phone to PC
  static Future<bool> pullFile(String remotePath, String localDir) async {
    final adbPath = await AdbDeviceScanner.getAdbPath();
    final res = await Process.run(adbPath, ['pull', remotePath, localDir]);
    return res.exitCode == 0;
  }
}

