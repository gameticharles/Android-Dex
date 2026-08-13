import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class DexSettingsConfig {
  // Display & UI
  final bool darkMode;
  final bool glassEffects;
  final double blurIntensity;
  final double surfaceTransparency;
  final double itemRounding;
  final int accentColor;
  final String displaySize;
  final double fontSizeScale;

  // Language & Font
  final String selectedLanguage;
  final String selectedFont;

  // Wallpaper & Desktop
  final int selectedWallpaperIdx;
  final String wallpaperUrl;
  final bool isCustomWallpaper;
  final double darknessOverlay;
  final String desktopGridSize;
  final bool showDesktopShortcuts;
  final bool autoHideTaskbar;

  // Scrcpy & Mirroring
  final String appOpeningMode;
  final String appLaunchMode;
  final String videoEncoder;
  final String scrcpyBitrate;
  final String scrcpyMaxResolution;
  final int scrcpyMaxFps;
  final bool turnScreenOffOnMirror;
  final bool stayAwakeOnMirror;
  final bool forwardAudio;

  // Clipboard Flow
  final bool syncClipboard;
  final bool androidToLinux;
  final bool linuxToAndroid;
  final bool saveImagesAuto;
  final bool autoOpenLinks;
  final bool clipboardPreview;
  final int clipboardMaxHistory;

  // Paired Devices
  final bool autoConnectKnownDevices;

  // Audio & Sound System
  final double masterVolume;
  final double mediaVolume;
  final double ringVolume;
  final double notificationVolume;
  final double alarmVolume;
  final double callVolume;
  final String audioOutputTarget;
  final String soundProfile;

  const DexSettingsConfig({
    this.darkMode = true,
    this.glassEffects = true,
    this.blurIntensity = 0.75,
    this.surfaceTransparency = 0.16,
    this.itemRounding = 0.08,
    this.accentColor = 0xFF6366F1,
    this.displaySize = 'Default Screen',
    this.fontSizeScale = 1.0,
    this.selectedLanguage = 'English',
    this.selectedFont = 'Default',
    this.selectedWallpaperIdx = 0,
    this.wallpaperUrl =
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
    this.isCustomWallpaper = false,
    this.darknessOverlay = 0.0,
    this.desktopGridSize = '5x5',
    this.showDesktopShortcuts = true,
    this.autoHideTaskbar = false,
    this.appOpeningMode = 'Default opening',
    this.appLaunchMode = 'Resizable APP mode',
    this.videoEncoder = 'Auto',
    this.scrcpyBitrate = '8M',
    this.scrcpyMaxResolution = '1080',
    this.scrcpyMaxFps = 60,
    this.turnScreenOffOnMirror = false,
    this.stayAwakeOnMirror = true,
    this.forwardAudio = true,
    this.syncClipboard = true,
    this.androidToLinux = true,
    this.linuxToAndroid = true,
    this.saveImagesAuto = true,
    this.autoOpenLinks = false,
    this.clipboardPreview = true,
    this.clipboardMaxHistory = 30,
    this.autoConnectKnownDevices = true,
    this.masterVolume = 0.80,
    this.mediaVolume = 0.75,
    this.ringVolume = 0.80,
    this.notificationVolume = 0.70,
    this.alarmVolume = 0.65,
    this.callVolume = 0.85,
    this.audioOutputTarget = 'Android Speaker',
    this.soundProfile = 'Sound',
  });

  /// Calculate effective desktop scale factor
  double get scaleFactor {
    switch (displaySize) {
      case 'Very Small Screen':
        return 0.85;
      case 'Small Screen':
        return 0.92;
      case 'Large Screen':
        return 1.10;
      case 'Very Large Screen':
        return 1.20;
      case 'Default Screen':
      default:
        return 1.0;
    }
  }

  /// Calculate effective corner radius for widgets/cards
  double get effectiveBorderRadius => 4.0 + (itemRounding * 24.0);

  /// Calculate effective blur sigma
  double get effectiveBlurSigma => glassEffects ? (blurIntensity * 30.0).clamp(4.0, 36.0) : 0.0;

  /// Calculate effective surface opacity
  double get effectiveSurfaceAlpha => glassEffects ? (0.45 + (1.0 - surfaceTransparency) * 0.5).clamp(0.2, 0.98) : 0.96;

  Color get activeAccentColor => Color(accentColor);

  DexSettingsConfig copyWith({
    bool? darkMode,
    bool? glassEffects,
    double? blurIntensity,
    double? surfaceTransparency,
    double? itemRounding,
    int? accentColor,
    String? displaySize,
    double? fontSizeScale,
    String? selectedLanguage,
    String? selectedFont,
    int? selectedWallpaperIdx,
    String? wallpaperUrl,
    bool? isCustomWallpaper,
    double? darknessOverlay,
    String? desktopGridSize,
    bool? showDesktopShortcuts,
    bool? autoHideTaskbar,
    String? appOpeningMode,
    String? appLaunchMode,
    String? videoEncoder,
    String? scrcpyBitrate,
    String? scrcpyMaxResolution,
    int? scrcpyMaxFps,
    bool? turnScreenOffOnMirror,
    bool? stayAwakeOnMirror,
    bool? forwardAudio,
    bool? syncClipboard,
    bool? androidToLinux,
    bool? linuxToAndroid,
    bool? saveImagesAuto,
    bool? autoOpenLinks,
    bool? clipboardPreview,
    int? clipboardMaxHistory,
    bool? autoConnectKnownDevices,
    double? masterVolume,
    double? mediaVolume,
    double? ringVolume,
    double? notificationVolume,
    double? alarmVolume,
    double? callVolume,
    String? audioOutputTarget,
    String? soundProfile,
  }) {
    return DexSettingsConfig(
      darkMode: darkMode ?? this.darkMode,
      glassEffects: glassEffects ?? this.glassEffects,
      blurIntensity: blurIntensity ?? this.blurIntensity,
      surfaceTransparency: surfaceTransparency ?? this.surfaceTransparency,
      itemRounding: itemRounding ?? this.itemRounding,
      accentColor: accentColor ?? this.accentColor,
      displaySize: displaySize ?? this.displaySize,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedFont: selectedFont ?? this.selectedFont,
      selectedWallpaperIdx: selectedWallpaperIdx ?? this.selectedWallpaperIdx,
      wallpaperUrl: wallpaperUrl ?? this.wallpaperUrl,
      isCustomWallpaper: isCustomWallpaper ?? this.isCustomWallpaper,
      darknessOverlay: darknessOverlay ?? this.darknessOverlay,
      desktopGridSize: desktopGridSize ?? this.desktopGridSize,
      showDesktopShortcuts: showDesktopShortcuts ?? this.showDesktopShortcuts,
      autoHideTaskbar: autoHideTaskbar ?? this.autoHideTaskbar,
      appOpeningMode: appOpeningMode ?? this.appOpeningMode,
      appLaunchMode: appLaunchMode ?? this.appLaunchMode,
      videoEncoder: videoEncoder ?? this.videoEncoder,
      scrcpyBitrate: scrcpyBitrate ?? this.scrcpyBitrate,
      scrcpyMaxResolution: scrcpyMaxResolution ?? this.scrcpyMaxResolution,
      scrcpyMaxFps: scrcpyMaxFps ?? this.scrcpyMaxFps,
      turnScreenOffOnMirror: turnScreenOffOnMirror ?? this.turnScreenOffOnMirror,
      stayAwakeOnMirror: stayAwakeOnMirror ?? this.stayAwakeOnMirror,
      forwardAudio: forwardAudio ?? this.forwardAudio,
      syncClipboard: syncClipboard ?? this.syncClipboard,
      androidToLinux: androidToLinux ?? this.androidToLinux,
      linuxToAndroid: linuxToAndroid ?? this.linuxToAndroid,
      saveImagesAuto: saveImagesAuto ?? this.saveImagesAuto,
      autoOpenLinks: autoOpenLinks ?? this.autoOpenLinks,
      clipboardPreview: clipboardPreview ?? this.clipboardPreview,
      clipboardMaxHistory: clipboardMaxHistory ?? this.clipboardMaxHistory,
      autoConnectKnownDevices: autoConnectKnownDevices ?? this.autoConnectKnownDevices,
      masterVolume: masterVolume ?? this.masterVolume,
      mediaVolume: mediaVolume ?? this.mediaVolume,
      ringVolume: ringVolume ?? this.ringVolume,
      notificationVolume: notificationVolume ?? this.notificationVolume,
      alarmVolume: alarmVolume ?? this.alarmVolume,
      callVolume: callVolume ?? this.callVolume,
      audioOutputTarget: audioOutputTarget ?? this.audioOutputTarget,
      soundProfile: soundProfile ?? this.soundProfile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'darkMode': darkMode,
      'glassEffects': glassEffects,
      'blurIntensity': blurIntensity,
      'surfaceTransparency': surfaceTransparency,
      'itemRounding': itemRounding,
      'accentColor': accentColor,
      'displaySize': displaySize,
      'fontSizeScale': fontSizeScale,
      'selectedLanguage': selectedLanguage,
      'selectedFont': selectedFont,
      'selectedWallpaperIdx': selectedWallpaperIdx,
      'wallpaperUrl': wallpaperUrl,
      'isCustomWallpaper': isCustomWallpaper,
      'darknessOverlay': darknessOverlay,
      'desktopGridSize': desktopGridSize,
      'showDesktopShortcuts': showDesktopShortcuts,
      'autoHideTaskbar': autoHideTaskbar,
      'appOpeningMode': appOpeningMode,
      'appLaunchMode': appLaunchMode,
      'videoEncoder': videoEncoder,
      'scrcpyBitrate': scrcpyBitrate,
      'scrcpyMaxResolution': scrcpyMaxResolution,
      'scrcpyMaxFps': scrcpyMaxFps,
      'turnScreenOffOnMirror': turnScreenOffOnMirror,
      'stayAwakeOnMirror': stayAwakeOnMirror,
      'forwardAudio': forwardAudio,
      'syncClipboard': syncClipboard,
      'androidToLinux': androidToLinux,
      'linuxToAndroid': linuxToAndroid,
      'saveImagesAuto': saveImagesAuto,
      'autoOpenLinks': autoOpenLinks,
      'clipboardPreview': clipboardPreview,
      'clipboardMaxHistory': clipboardMaxHistory,
      'autoConnectKnownDevices': autoConnectKnownDevices,
      'masterVolume': masterVolume,
      'mediaVolume': mediaVolume,
      'ringVolume': ringVolume,
      'notificationVolume': notificationVolume,
      'alarmVolume': alarmVolume,
      'callVolume': callVolume,
      'audioOutputTarget': audioOutputTarget,
      'soundProfile': soundProfile,
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
      accentColor: json['accentColor'] as int? ?? 0xFF6366F1,
      displaySize: json['displaySize'] as String? ?? 'Default Screen',
      fontSizeScale: (json['fontSizeScale'] as num?)?.toDouble() ?? 1.0,
      selectedLanguage: json['selectedLanguage'] as String? ?? 'English',
      selectedFont: json['selectedFont'] as String? ?? 'Default',
      selectedWallpaperIdx: json['selectedWallpaperIdx'] as int? ?? 0,
      wallpaperUrl: json['wallpaperUrl'] as String? ??
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      isCustomWallpaper: json['isCustomWallpaper'] as bool? ?? false,
      darknessOverlay: (json['darknessOverlay'] as num?)?.toDouble() ?? 0.0,
      desktopGridSize: json['desktopGridSize'] as String? ?? '5x5',
      showDesktopShortcuts: json['showDesktopShortcuts'] as bool? ?? true,
      autoHideTaskbar: json['autoHideTaskbar'] as bool? ?? false,
      appOpeningMode: json['appOpeningMode'] as String? ?? 'Default opening',
      appLaunchMode: json['appLaunchMode'] as String? ?? 'Resizable APP mode',
      videoEncoder: json['videoEncoder'] as String? ?? 'Auto',
      scrcpyBitrate: json['scrcpyBitrate'] as String? ?? '8M',
      scrcpyMaxResolution: json['scrcpyMaxResolution'] as String? ?? '1080',
      scrcpyMaxFps: json['scrcpyMaxFps'] as int? ?? 60,
      turnScreenOffOnMirror: json['turnScreenOffOnMirror'] as bool? ?? false,
      stayAwakeOnMirror: json['stayAwakeOnMirror'] as bool? ?? true,
      forwardAudio: json['forwardAudio'] as bool? ?? true,
      syncClipboard: json['syncClipboard'] as bool? ?? true,
      androidToLinux: json['androidToLinux'] as bool? ?? true,
      linuxToAndroid: json['linuxToAndroid'] as bool? ?? true,
      saveImagesAuto: json['saveImagesAuto'] as bool? ?? true,
      autoOpenLinks: json['autoOpenLinks'] as bool? ?? false,
      clipboardPreview: json['clipboardPreview'] as bool? ?? true,
      clipboardMaxHistory: json['clipboardMaxHistory'] as int? ?? 30,
      autoConnectKnownDevices: json['autoConnectKnownDevices'] as bool? ?? true,
      masterVolume: (json['masterVolume'] as num?)?.toDouble() ?? 0.80,
      mediaVolume: (json['mediaVolume'] as num?)?.toDouble() ?? 0.75,
      ringVolume: (json['ringVolume'] as num?)?.toDouble() ?? 0.80,
      notificationVolume: (json['notificationVolume'] as num?)?.toDouble() ?? 0.70,
      alarmVolume: (json['alarmVolume'] as num?)?.toDouble() ?? 0.65,
      callVolume: (json['callVolume'] as num?)?.toDouble() ?? 0.85,
      audioOutputTarget: json['audioOutputTarget'] as String? ?? 'Android Speaker',
      soundProfile: json['soundProfile'] as String? ?? 'Sound',
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

  /// Reset settings to factory defaults and persist
  static Future<void> resetToDefaults() async {
    const defaultConfig = DexSettingsConfig();
    await update(defaultConfig);
  }
}
