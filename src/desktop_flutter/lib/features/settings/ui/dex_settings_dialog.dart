import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:adb_device_manager/core/models/device_state.dart';
import 'package:adb_device_manager/features/wireless_adb/services/pairing_service.dart';
import 'package:adb_device_manager/core/services/desktop_identity_service.dart';
import 'package:adb_device_manager/features/settings/services/dex_settings_service.dart';

class DexSettingsDialog extends StatefulWidget {
  final bool isWindow;
  final DeviceState? deviceState;
  final VoidCallback? onClose;

  const DexSettingsDialog({
    super.key,
    this.isWindow = false,
    this.deviceState,
    this.onClose,
  });

  @override
  State<DexSettingsDialog> createState() => _DexSettingsDialogState();
}

class _DexSettingsDialogState extends State<DexSettingsDialog> {
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Settings State Variables
  bool _darkMode = true;
  bool _glassEffects = true;
  double _blurIntensity = 0.75;
  double _surfaceTransparency = 0.16;

  @override
  void initState() {
    super.initState();
    final cfg = DexSettingsService.notifier.value;
    _darkMode = cfg.darkMode;
    _glassEffects = cfg.glassEffects;
    _blurIntensity = cfg.blurIntensity;
    _surfaceTransparency = cfg.surfaceTransparency;
    _itemRounding = cfg.itemRounding;
    _displaySize = cfg.displaySize;
    _selectedLanguage = cfg.selectedLanguage;
    _selectedFont = cfg.selectedFont;
    _selectedWallpaperIdx = cfg.selectedWallpaperIdx;
    _darknessOverlay = cfg.darknessOverlay;
    _appOpeningMode = cfg.appOpeningMode;
    _appLaunchMode = cfg.appLaunchMode;
    _videoEncoder = cfg.videoEncoder;
    _syncClipboard = cfg.syncClipboard;
    _androidToLinux = cfg.androidToLinux;
    _linuxToAndroid = cfg.linuxToAndroid;
    _saveImagesAuto = cfg.saveImagesAuto;
    _autoOpenLinks = cfg.autoOpenLinks;
    _clipboardPreview = cfg.clipboardPreview;
  }

  void _updateSettings(VoidCallback action) {
    setState(action);
    final wpUrl = _wallpapers[_selectedWallpaperIdx]['url']!;
    final newConfig = DexSettingsConfig(
      darkMode: _darkMode,
      glassEffects: _glassEffects,
      blurIntensity: _blurIntensity,
      surfaceTransparency: _surfaceTransparency,
      itemRounding: _itemRounding,
      displaySize: _displaySize,
      selectedLanguage: _selectedLanguage,
      selectedFont: _selectedFont,
      selectedWallpaperIdx: _selectedWallpaperIdx,
      wallpaperUrl: wpUrl,
      darknessOverlay: _darknessOverlay,
      appOpeningMode: _appOpeningMode,
      appLaunchMode: _appLaunchMode,
      videoEncoder: _videoEncoder,
      syncClipboard: _syncClipboard,
      androidToLinux: _androidToLinux,
      linuxToAndroid: _linuxToAndroid,
      saveImagesAuto: _saveImagesAuto,
      autoOpenLinks: _autoOpenLinks,
      clipboardPreview: _clipboardPreview,
    );
    DexSettingsService.update(newConfig);
  }

  double _itemRounding = 0.08;
  String _displaySize = 'Default Screen';

  String _selectedLanguage = 'English';
  bool _isLanguageExtended = false;
  String _selectedFont = 'Default';

  int _selectedWallpaperIdx = 0;
  double _darknessOverlay = 0.0;

  String _appOpeningMode = 'Default opening';
  String _appLaunchMode = 'Resizable APP mode';
  String _videoEncoder = 'Auto';

  bool _syncClipboard = true;
  bool _androidToLinux = true;
  bool _linuxToAndroid = true;
  bool _saveImagesAuto = true;
  bool _autoOpenLinks = true;
  bool _clipboardPreview = true;

  final List<Map<String, String>> _wallpapers = [
    {
      'name': 'Deep Midnight',
      'url':
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'name': 'Nordic Aurora',
      'url':
          'https://images.unsplash.com/photo-1517411032315-54ef2cb783bb?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'name': 'Volcanic Sunset',
      'url':
          'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'name': 'Mist Canopy',
      'url':
          'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'name': 'Warm Sand',
      'url':
          'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?auto=format&fit=crop&w=1200&q=80',
    },
  ];

  final List<Map<String, String>> _categories = [
    {
      'title': 'Display & UI',
      'subtitle': 'Theme • Blur • Glass',
      'icon': 'palette',
    },
    {
      'title': 'Language & Font',
      'subtitle': 'Language • Font style',
      'icon': 'translate',
    },
    {
      'title': 'Wallpaper',
      'subtitle': 'Background • Darkness overlay',
      'icon': 'wallpaper',
    },
    {
      'title': 'Scrcpy Config',
      'subtitle': 'App mode • Resolution • Performance',
      'icon': 'settings',
    },
    {
      'title': 'Clipboard Manager',
      'subtitle': 'Sync • History • Preview',
      'icon': 'assignment',
    },
    {
      'title': 'Paired Devices',
      'subtitle': 'Security • Tokens • Auto-Connect',
      'icon': 'devices',
    },
    {
      'title': 'About System & Updates',
      'subtitle': 'System info • GitHub updates',
      'icon': 'info',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = Row(
      children: [
        _buildLeftSidebar(),
        Container(width: 1, color: Colors.white10),
        Expanded(child: _buildRightMainPanel()),
      ],
    );

    if (widget.isWindow) {
      return Container(
        color: const Color(0xFF0F172A).withValues(alpha: 0.65),
        child: bodyContent,
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _glassEffects ? (_blurIntensity * 30).clamp(5.0, 30.0) : 0,
            sigmaY: _glassEffects ? (_blurIntensity * 30).clamp(5.0, 30.0) : 0,
          ),
          child: Container(
            width: 960,
            height: 640,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A)
                  .withValues(alpha: _glassEffects ? 0.65 : 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 35,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              children: [
                // Window Header Bar
                _buildHeaderBar(),
                // Body Content (Sidebar + Main Panel)
                Expanded(child: bodyContent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.settings_suggest_rounded,
                  color: Color(0xFF6366F1), size: 20),
              SizedBox(width: 8),
              Text(
                "Dex Settings",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 20),
                onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0F172A).withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Dex Settings",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                ),
                Icon(Icons.search_rounded, color: Colors.white54, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, idx) {
                final cat = _categories[idx];
                final isSelected = _selectedCategoryIndex == idx;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _selectedCategoryIndex = idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E293B).withValues(alpha: 0.9)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.4))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                      .withValues(alpha: 0.25)
                                  : const Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getCategoryIcon(cat['icon']!),
                              color: isSelected
                                  ? const Color(0xFF818CF8)
                                  : Colors.white60,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat['title']!,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cat['subtitle']!,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Search Settings Input Box
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    color: Colors.white38, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: "Search settings",
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String iconKey) {
    switch (iconKey) {
      case 'palette':
        return Icons.palette_outlined;
      case 'translate':
        return Icons.translate_rounded;
      case 'wallpaper':
        return Icons.wallpaper_rounded;
      case 'settings':
        return Icons.settings_suggest_outlined;
      case 'assignment':
        return Icons.assignment_outlined;
      case 'devices':
        return Icons.devices_rounded;
      case 'info':
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _buildRightMainPanel() {
    switch (_selectedCategoryIndex) {
      case 0:
        return _buildDisplayAndUiCategory();
      case 1:
        return _buildLanguageAndFontCategory();
      case 2:
        return _buildWallpaperCategory();
      case 3:
        return _buildScrcpyConfigCategory();
      case 4:
        return _buildClipboardCategory();
      case 5:
        return _buildPairedDevicesCategory();
      case 6:
      default:
        return _buildAboutCategory();
    }
  }

  // --- Category 0: Display & UI ---
  Widget _buildDisplayAndUiCategory() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryHeader("Display & UI"),
          const SizedBox(height: 20),

          // Dark Mode Card
          _buildCardContainer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Dark mode",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    SizedBox(height: 2),
                    Text("Enjoy a more comfortable viewing experience",
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                Row(
                  children: [
                    Text(_darkMode ? "On" : "Off",
                        style: const TextStyle(
                            color: Color(0xFF60A5FA),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    const SizedBox(width: 8),
                    Switch(
                      value: _darkMode,
                      activeThumbColor: const Color(0xFF3B82F6),
                      onChanged: (v) => _updateSettings(() => _darkMode = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Glass Effects Card
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Glass effects",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        SizedBox(height: 2),
                        Text("Control background blur and surface transparency",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    Row(
                      children: [
                        Text(_glassEffects ? "On" : "Off",
                            style: const TextStyle(
                                color: Color(0xFF60A5FA),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(width: 8),
                        Switch(
                          value: _glassEffects,
                          activeThumbColor: const Color(0xFF3B82F6),
                          onChanged: (v) =>
                              _updateSettings(() => _glassEffects = v),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Blur Intensity
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Blur intensity",
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("${(_blurIntensity * 100).round()}%",
                        style: const TextStyle(
                            color: Color(0xFF60A5FA),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
                Slider(
                  value: _blurIntensity,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => _updateSettings(() => _blurIntensity = v),
                ),

                // Surface Transparency
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Surface transparency",
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("${(_surfaceTransparency * 100).round()}%",
                        style: const TextStyle(
                            color: Color(0xFF60A5FA),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
                Slider(
                  value: _surfaceTransparency,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) =>
                      _updateSettings(() => _surfaceTransparency = v),
                ),

                // Item Rounding
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Item rounding",
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("${(_itemRounding * 100).round()}%",
                        style: const TextStyle(
                            color: Color(0xFF60A5FA),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
                Slider(
                  value: _itemRounding,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => _updateSettings(() => _itemRounding = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Display Size Radio Card
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("DISPLAY SIZE",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                ...[
                  'Very Small Screen',
                  'Small Screen',
                  'Default Screen',
                  'Large Screen',
                  'Very Large Screen'
                ].map((opt) => RadioListTile<String>(
                      title: Text(opt,
                          style: TextStyle(
                              color: _displaySize == opt
                                  ? const Color(0xFF60A5FA)
                                  : Colors.white70,
                              fontWeight: _displaySize == opt
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13)),
                      value: opt,
                      groupValue: _displaySize,
                      activeColor: const Color(0xFF3B82F6),
                      onChanged: (v) =>
                          _updateSettings(() => _displaySize = v!),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Category 1: Language & Font ---
  Widget _buildLanguageAndFontCategory() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryHeader("Language & Font"),
          const SizedBox(height: 20),

          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("LANGUAGE",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                _buildLanguageOption("English", "🇬🇧", "English"),
                _buildLanguageOption("Hindi", "🇮🇳", "हिन्दी"),
                _buildLanguageOption("Gujarati", "🇮🇳", "ગુજરાતી"),
                _buildLanguageOption("Português", "🇧🇷", "Português"),
                if (_isLanguageExtended) ...[
                  _buildLanguageOption("Spanish", "🇪🇸", "Español"),
                  _buildLanguageOption("French", "🇫🇷", "Français"),
                  _buildLanguageOption("German", "🇩🇪", "Deutsch"),
                  _buildLanguageOption("Chinese", "🇨🇳", "中文"),
                  _buildLanguageOption("Japanese", "🇯🇵", "日本語"),
                  _buildLanguageOption("Arabic", "🇸🇦", "العربية"),
                ],
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(
                      () => _isLanguageExtended = !_isLanguageExtended),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _isLanguageExtended
                          ? "v Click here to collapse"
                          : "v Click here to extend (+10 more)",
                      style: const TextStyle(
                          color: Color(0xFF60A5FA), fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white38, size: 14),
              SizedBox(width: 6),
              Text("Some UI text will update on the next app launch.",
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 20),

          // Font Style Card
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("FONT STYLE",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  title: const Text("Default",
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: 'Default',
                  groupValue: _selectedFont,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => _updateSettings(() => _selectedFont = v!),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                RadioListTile<String>(
                  title: const Text("SamsungSharpSans",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'SansSerif')),
                  value: 'SamsungSharpSans',
                  groupValue: _selectedFont,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => _updateSettings(() => _selectedFont = v!),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(String key, String flag, String nativeName) {
    final isSelected = _selectedLanguage == key;
    return RadioListTile<String>(
      title: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(key,
                  style: TextStyle(
                      color:
                          isSelected ? const Color(0xFF60A5FA) : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13)),
              Text(nativeName,
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
      value: key,
      groupValue: _selectedLanguage,
      activeColor: const Color(0xFF3B82F6),
      onChanged: (v) => _updateSettings(() => _selectedLanguage = v!),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  // --- Category 2: Wallpaper ---
  Widget _buildWallpaperCategory() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryHeader("Wallpaper"),
          const SizedBox(height: 20),

          // Wallpaper Picker Grid Card
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CHOOSE WALLPAPER",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _wallpapers.length,
                  itemBuilder: (context, idx) {
                    final wp = _wallpapers[idx];
                    final isSelected = _selectedWallpaperIdx == idx;
                    return InkWell(
                      onTap: () =>
                          _updateSettings(() => _selectedWallpaperIdx = idx),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF10B981)
                                : Colors.white10,
                            width: isSelected ? 2.5 : 1.0,
                          ),
                          image: DecorationImage(
                            image: NetworkImage(wp['url']!),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.7)
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 10,
                              bottom: 10,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wp['name']!,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11),
                                  ),
                                  Text(
                                    isSelected
                                        ? "Currently Active"
                                        : "Tap to apply",
                                    style: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF34D399)
                                          : Colors.white54,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Darkness Overlay Slider Card
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("DARKNESS OVERLAY",
                        style: TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 1.2)),
                    Text("${(_darknessOverlay * 100).round()}%",
                        style: const TextStyle(
                            color: Color(0xFF60A5FA),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text("Adjust dark overlay intensity over your wallpaper",
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 12),

                Slider(
                  value: _darknessOverlay,
                  max: 0.8,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => _updateSettings(() => _darknessOverlay = v),
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("No overlay",
                        style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Text("Max dark (80%)",
                        style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 14),

                // Dynamic Live Preview Box
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(
                          _wallpapers[_selectedWallpaperIdx]['url']!),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black.withValues(alpha: _darknessOverlay),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _darknessOverlay == 0.0
                          ? "No overlay"
                          : "Overlay Applied (${(_darknessOverlay * 100).round()}%)",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Category 3: Scrcpy Config ---
  Widget _buildScrcpyConfigCategory() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryHeader("Scrcpy Config"),
          const SizedBox(height: 20),

          // App Opening Mode
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("APP OPENING MODE",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  title: const Text("Default opening",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  subtitle: const Text(
                      "Uses the built-in video pipeline (JAR-based). Supports Normal, Resizable, and Flex display modes with full control integration.",
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: 'Default opening',
                  groupValue: _appOpeningMode,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => _updateSettings(() => _appOpeningMode = v!),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: const Text("Scrcpy opening",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  subtitle: const Text(
                      "Launches apps directly using scrcpy.exe as a standalone process. Simpler but opens as a native OS window outside the desktop.",
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: 'Scrcpy opening',
                  groupValue: _appOpeningMode,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => _updateSettings(() => _appOpeningMode = v!),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // App Launch Mode
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("APP LAUNCH MODE",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  title: const Text("Normal APP mode",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  subtitle: const Text(
                      "Launch apps in a fixed-size window optimized for the selected resolution. Recommended for streaming and specific device layouts.",
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: 'Normal APP mode',
                  groupValue: _appLaunchMode,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => _updateSettings(() => _appLaunchMode = v!),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: const Text("Resizable APP mode",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  subtitle: const Text(
                      "Experimental: Launch apps with a flexible window that can be resized on the fly. Best for multitasking but may cause orientation issues in some apps.",
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: 'Resizable APP mode',
                  groupValue: _appLaunchMode,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => _updateSettings(() => _appLaunchMode = v!),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: const Text("Flex Display mode",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  subtitle: const Text(
                      "Faster resize — the virtual display automatically follows the window size in real-time with zero ADB overhead. Powered natively by scrcpy 4.0.",
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: 'Flex Display mode',
                  groupValue: _appLaunchMode,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (v) => _updateSettings(() => _appLaunchMode = v!),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Video Encoder
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("VIDEO ENCODER",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                ...[
                  'Auto',
                  'H.264 (Default)',
                  'H.265 (HEVC)',
                  'AV1 (High efficiency)'
                ].map((enc) => RadioListTile<String>(
                      title: Text(enc,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      value: enc.split(' ').first,
                      groupValue: _videoEncoder,
                      activeColor: const Color(0xFF3B82F6),
                      onChanged: (v) =>
                          _updateSettings(() => _videoEncoder = v!),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Category 4: Clipboard Flow ---
  Widget _buildClipboardCategory() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryHeader("Clipboard Flow"),
          const SizedBox(height: 20),

          // Clipboard Sharing Card
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CLIPBOARD SHARING",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Sync Across Devices",
                            style: TextStyle(
                                color: Color(0xFF60A5FA),
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        SizedBox(height: 2),
                        Text(
                            "Seamlessly share and manage clipboard content across your devices.",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    Row(
                      children: [
                        Text(_syncClipboard ? "On" : "Off",
                            style: const TextStyle(
                                color: Color(0xFF60A5FA),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        const SizedBox(width: 8),
                        Switch(
                          value: _syncClipboard,
                          activeThumbColor: const Color(0xFF3B82F6),
                          onChanged: (v) =>
                              _updateSettings(() => _syncClipboard = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Transfer Direction Card
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("TRANSFER DIRECTION",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Android -> Linux",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text(
                            "Send text and images from your phone to your Linux instantly.",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    Switch(
                      value: _androidToLinux,
                      activeThumbColor: const Color(0xFF3B82F6),
                      onChanged: (v) =>
                          _updateSettings(() => _androidToLinux = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Linux -> Android",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text(
                            "Send text and images from your Linux to your phone.",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    Switch(
                      value: _linuxToAndroid,
                      activeThumbColor: const Color(0xFF3B82F6),
                      onChanged: (v) =>
                          _updateSettings(() => _linuxToAndroid = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interface Preferences
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("INTERFACE PREFERENCES",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Save Images Automatically",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text("Store synced images in your Downloads folder.",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    Switch(
                      value: _saveImagesAuto,
                      activeThumbColor: const Color(0xFF3B82F6),
                      onChanged: (v) =>
                          _updateSettings(() => _saveImagesAuto = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Auto Open Links",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text(
                            "Open links instantly when copied to your clipboard.",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    Switch(
                      value: _autoOpenLinks,
                      activeThumbColor: const Color(0xFF3B82F6),
                      onChanged: (v) =>
                          _updateSettings(() => _autoOpenLinks = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Clipboard Preview",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text(
                            "Show a quick floating preview when content is copied.",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    Switch(
                      value: _clipboardPreview,
                      activeThumbColor: const Color(0xFF3B82F6),
                      onChanged: (v) =>
                          _updateSettings(() => _clipboardPreview = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Security & Storage Cards
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SECURITY & STORAGE",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.security_rounded,
                          color: Color(0xFF60A5FA), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Secure Local Connection",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text(
                            "All data stays within your local network for maximum privacy.",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_outlined,
                          color: Color(0xFF60A5FA), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Storage Location",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text(
                            "Synced images are saved to your default Downloads folder.",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Category 5: Paired Devices ---
  Widget _buildPairedDevicesCategory() {
    final computerName = DesktopIdentityService.getComputerName();
    final deviceId = DesktopIdentityService.cachedId ?? "desktop-uuid-charles";
    final token = DesktopIdentityService.activeAuthToken ??
        "d919769d2801490e9df5d4bc6fbf0bb7";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryHeader("Paired Devices"),
          const SizedBox(height: 20),

          // Current Paired Computer Card
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CURRENT DESKTOP IDENTITY",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.5)),
                      ),
                      child: const Icon(Icons.computer_rounded,
                          color: Color(0xFF34D399), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(computerName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(height: 2),
                          const Text(
                              "IP: 127.0.0.1 • Status: Paired & Approved",
                              style: TextStyle(
                                  color: Color(0xFF34D399), fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text("CONNECTED",
                          style: TextStyle(
                              color: Color(0xFF34D399),
                              fontWeight: FontWeight.bold,
                              fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow("Device ID", deviceId),
                const SizedBox(height: 8),
                _buildInfoRow("Security Token", "${token.substring(0, 12)}..."),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Security & Pairing Controls
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SECURITY & AUTOMATION",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                      "Re-authenticate Companion Security Handshake"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    PairingService.requestPairing();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text("Pairing security handshake requested!")),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Category 6: About System & Updates ---
  Widget _buildAboutCategory() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryHeader("About System & Updates"),
          const SizedBox(height: 20),

          // System Summary Card
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.desktop_windows_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Android DEX Desktop Shell",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        SizedBox(height: 2),
                        Text("Version 2.5.0 Pro (Build 2026.07)",
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                _buildInfoRow(
                    "Architecture", "Linux x86_64 / Flutter Desktop API"),
                const SizedBox(height: 8),
                _buildInfoRow(
                    "Companion Server API", "v2.0 (NanoHTTPD Port 8080)"),
                const SizedBox(height: 8),
                _buildInfoRow("Video Engine", "Scrcpy 4.0 Native Pipeline"),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // GitHub Updates Card
          _buildCardContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("UPDATES & REPOSITORY",
                    style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Check for Updates",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        SizedBox(height: 2),
                        Text("GitHub: gameticharles/Android-Dex",
                            style:
                                TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF60A5FA),
                        side: const BorderSide(color: Color(0xFF3B82F6)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {},
                      child: const Text("Check Now"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white70, size: 20),
          onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 12)),
      ],
    );
  }
}
