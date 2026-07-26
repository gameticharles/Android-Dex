import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class DexSettingsConfig {
  final bool darkMode;
  final bool glassEffects;
  final double blurIntensity;
  final double surfaceTransparency;
  final double itemRounding;
  final String displaySize;

  final String selectedLanguage;
  final String selectedFont;

  final int selectedWallpaperIdx;
  final String wallpaperUrl;
  final double darknessOverlay;

  final String appOpeningMode;
  final String appLaunchMode;
  final String videoEncoder;

  final bool syncClipboard;
  final bool androidToLinux;
  final bool linuxToAndroid;
  final bool saveImagesAuto;
  final bool autoOpenLinks;
  final bool clipboardPreview;

  const DexSettingsConfig({
    this.darkMode = true,
    this.glassEffects = true,
    this.blurIntensity = 0.75,
    this.surfaceTransparency = 0.16,
    this.itemRounding = 0.08,
    this.displaySize = 'Default Screen',
    this.selectedLanguage = 'English',
    this.selectedFont = 'Default',
    this.selectedWallpaperIdx = 0,
    this.wallpaperUrl =
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
    this.darknessOverlay = 0.0,
    this.appOpeningMode = 'Default opening',
    this.appLaunchMode = 'Resizable APP mode',
    this.videoEncoder = 'Auto',
    this.syncClipboard = true,
    this.androidToLinux = true,
    this.linuxToAndroid = true,
    this.saveImagesAuto = true,
    this.autoOpenLinks = true,
    this.clipboardPreview = true,
  });

  DexSettingsConfig copyWith({
    bool? darkMode,
    bool? glassEffects,
    double? blurIntensity,
    double? surfaceTransparency,
    double? itemRounding,
    String? displaySize,
    String? selectedLanguage,
    String? selectedFont,
    int? selectedWallpaperIdx,
    String? wallpaperUrl,
    double? darknessOverlay,
    String? appOpeningMode,
    String? appLaunchMode,
    String? videoEncoder,
    bool? syncClipboard,
    bool? androidToLinux,
    bool? linuxToAndroid,
    bool? saveImagesAuto,
    bool? autoOpenLinks,
    bool? clipboardPreview,
  }) {
    return DexSettingsConfig(
      darkMode: darkMode ?? this.darkMode,
      glassEffects: glassEffects ?? this.glassEffects,
      blurIntensity: blurIntensity ?? this.blurIntensity,
      surfaceTransparency: surfaceTransparency ?? this.surfaceTransparency,
      itemRounding: itemRounding ?? this.itemRounding,
      displaySize: displaySize ?? this.displaySize,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedFont: selectedFont ?? this.selectedFont,
      selectedWallpaperIdx: selectedWallpaperIdx ?? this.selectedWallpaperIdx,
      wallpaperUrl: wallpaperUrl ?? this.wallpaperUrl,
      darknessOverlay: darknessOverlay ?? this.darknessOverlay,
      appOpeningMode: appOpeningMode ?? this.appOpeningMode,
      appLaunchMode: appLaunchMode ?? this.appLaunchMode,
      videoEncoder: videoEncoder ?? this.videoEncoder,
      syncClipboard: syncClipboard ?? this.syncClipboard,
      androidToLinux: androidToLinux ?? this.androidToLinux,
      linuxToAndroid: linuxToAndroid ?? this.linuxToAndroid,
      saveImagesAuto: saveImagesAuto ?? this.saveImagesAuto,
      autoOpenLinks: autoOpenLinks ?? this.autoOpenLinks,
      clipboardPreview: clipboardPreview ?? this.clipboardPreview,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'darkMode': darkMode,
      'glassEffects': glassEffects,
      'blurIntensity': blurIntensity,
      'surfaceTransparency': surfaceTransparency,
      'itemRounding': itemRounding,
      'displaySize': displaySize,
      'selectedLanguage': selectedLanguage,
      'selectedFont': selectedFont,
      'selectedWallpaperIdx': selectedWallpaperIdx,
      'wallpaperUrl': wallpaperUrl,
      'darknessOverlay': darknessOverlay,
      'appOpeningMode': appOpeningMode,
      'appLaunchMode': appLaunchMode,
      'videoEncoder': videoEncoder,
      'syncClipboard': syncClipboard,
      'androidToLinux': androidToLinux,
      'linuxToAndroid': linuxToAndroid,
      'saveImagesAuto': saveImagesAuto,
      'autoOpenLinks': autoOpenLinks,
      'clipboardPreview': clipboardPreview,
    };
  }

  factory DexSettingsConfig.fromJson(Map<String, dynamic> json) {
    return DexSettingsConfig(
      darkMode: json['darkMode'] as bool? ?? true,
      glassEffects: json['glassEffects'] as bool? ?? true,
      blurIntensity: (json['blurIntensity'] as num?)?.toDouble() ?? 0.75,
      surfaceTransparency:
          (json['surfaceTransparency'] as num?)?.toDouble() ?? 0.16,
      itemRounding: (json['itemRounding'] as num?)?.toDouble() ?? 0.08,
      displaySize: json['displaySize'] as String? ?? 'Default Screen',
      selectedLanguage: json['selectedLanguage'] as String? ?? 'English',
      selectedFont: json['selectedFont'] as String? ?? 'Default',
      selectedWallpaperIdx: json['selectedWallpaperIdx'] as int? ?? 0,
      wallpaperUrl: json['wallpaperUrl'] as String? ??
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      darknessOverlay: (json['darknessOverlay'] as num?)?.toDouble() ?? 0.0,
      appOpeningMode: json['appOpeningMode'] as String? ?? 'Default opening',
      appLaunchMode: json['appLaunchMode'] as String? ?? 'Resizable APP mode',
      videoEncoder: json['videoEncoder'] as String? ?? 'Auto',
      syncClipboard: json['syncClipboard'] as bool? ?? true,
      androidToLinux: json['androidToLinux'] as bool? ?? true,
      linuxToAndroid: json['linuxToAndroid'] as bool? ?? true,
      saveImagesAuto: json['saveImagesAuto'] as bool? ?? true,
      autoOpenLinks: json['autoOpenLinks'] as bool? ?? true,
      clipboardPreview: json['clipboardPreview'] as bool? ?? true,
    );
  }
}

class DexSettingsService {
  static final ValueNotifier<DexSettingsConfig> notifier =
      ValueNotifier(const DexSettingsConfig());

  static File get _configFile {
    final home = Platform.environment['HOME'] ?? '.';
    return File(path.join(home, '.dex_settings.json'));
  }

  /// Initialize settings from disk persistence
  static Future<void> init() async {
    try {
      final file = _configFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final jsonMap = jsonDecode(content);
        if (jsonMap is Map<String, dynamic>) {
          notifier.value = DexSettingsConfig.fromJson(jsonMap);
        }
      }
    } catch (_) {}
  }

  /// Update current settings and persist to disk
  static Future<void> update(DexSettingsConfig newConfig) async {
    notifier.value = newConfig;
    try {
      final file = _configFile;
      await file.writeAsString(jsonEncode(newConfig.toJson()));
    } catch (_) {}
  }
}
