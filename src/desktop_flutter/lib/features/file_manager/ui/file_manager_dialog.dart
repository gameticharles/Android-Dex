import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/file_manager_service.dart';

class FileManagerDialog extends StatefulWidget {
  final bool isWindow;
  const FileManagerDialog({super.key, this.isWindow = false});

  @override
  State<FileManagerDialog> createState() => _FileManagerDialogState();
}

class _FileManagerDialogState extends State<FileManagerDialog> {
  String _currentPath = '/sdcard';
  List<PhoneFileItem> _items = [];
  PhoneFileItem? _selectedItem;
  bool _isLoading = true;
  bool _isGridView = true;
  bool _showPreviewPanel = true;
  String _searchQuery = '';
  StorageInfo? _storageInfo;

  // History tracking for back/forward navigation
  final List<String> _history = ['/sdcard'];
  int _historyIndex = 0;

  // Preview state
  String? _previewLocalPath;
  String? _previewTextContent;
  bool _isFetchingPreview = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDirectory(_currentPath);
    _loadStorageInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStorageInfo() async {
    final info = await FileManagerService.getStorageInfo('/sdcard');
    if (mounted) {
      setState(() => _storageInfo = info);
    }
  }

  Future<void> _loadDirectory(String path, {bool addHistory = true}) async {
    setState(() {
      _isLoading = true;
      _selectedItem = null;
      _previewLocalPath = null;
      _previewTextContent = null;
    });

    final items = await FileManagerService.listDirectory(path);

    if (mounted) {
      setState(() {
        _currentPath = path;
        _items = items;
        _isLoading = false;

        if (addHistory) {
          if (_historyIndex < _history.length - 1) {
            _history.removeRange(_historyIndex + 1, _history.length);
          }
          _history.add(path);
          _historyIndex = _history.length - 1;
        }
      });
    }
  }

  void _navigateBack() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _loadDirectory(_history[_historyIndex], addHistory: false);
    }
  }

  void _navigateForward() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _loadDirectory(_history[_historyIndex], addHistory: false);
    }
  }

  void _navigateUp() {
    if (_currentPath == '/' || _currentPath.isEmpty) return;
    final lastSlashIndex = _currentPath.lastIndexOf('/');
    if (lastSlashIndex <= 0) {
      _loadDirectory('/');
    } else {
      final parent = _currentPath.substring(0, lastSlashIndex);
      _loadDirectory(parent.isEmpty ? '/' : parent);
    }
  }

  void _selectItem(PhoneFileItem item) {
    setState(() {
      _selectedItem = item;
      _previewLocalPath = null;
      _previewTextContent = null;
    });

    if (!_showPreviewPanel) return;

    if (item.category == FileCategory.image || item.category == FileCategory.code || item.category == FileCategory.document) {
      _fetchPreview(item);
    }
  }

  Future<void> _fetchPreview(PhoneFileItem item) async {
    setState(() => _isFetchingPreview = true);

    final localPath = await FileManagerService.fetchPreviewFile(item.path);

    if (mounted && localPath != null) {
      String? textContent;
      if (item.category == FileCategory.code || (item.category == FileCategory.document && item.extension == 'txt')) {
        try {
          final file = File(localPath);
          if (await file.exists()) {
            final lines = await file.readAsString();
            textContent = lines.length > 2000 ? '${lines.substring(0, 2000)}\n\n[...Truncated...]' : lines;
          }
        } catch (_) {}
      }

      setState(() {
        _previewLocalPath = localPath;
        _previewTextContent = textContent;
        _isFetchingPreview = false;
      });
    } else if (mounted) {
      setState(() => _isFetchingPreview = false);
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      final paths =
          result.files.map((f) => f.path).whereType<String>().toList();
      await _uploadMultipleFiles(paths);
    }
  }

  Future<void> _uploadMultipleFiles(List<String> paths) async {
    int successCount = 0;
    for (final path in paths) {
      final ok = await FileManagerService.pushFile(path, _currentPath);
      if (ok) successCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Uploaded $successCount of ${paths.length} file(s) to $_currentPath"),
          backgroundColor: const Color(0xFF00BFA5),
        ),
      );
      _loadDirectory(_currentPath, addHistory: false);
    }
  }

  Future<void> _downloadFile(PhoneFileItem item) async {
    const downloadsDir = '/home/charlesgameti/Downloads';
    final success = await FileManagerService.pullFile(item.path, downloadsDir);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? "Downloaded ${item.name} to Downloads folder"
                : "Failed to download ${item.name}",
          ),
          backgroundColor: success ? const Color(0xFF00BFA5) : Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _createFolderDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Create New Folder", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Folder Name",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Create", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final targetPath = _currentPath.endsWith('/') ? '$_currentPath$name' : '$_currentPath/$name';
      final ok = await FileManagerService.createDirectory(targetPath);
      if (mounted) {
        if (ok) {
          _loadDirectory(_currentPath, addHistory: false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to create folder"), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  Future<void> _deleteItem(PhoneFileItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Delete", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to delete '${item.name}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await FileManagerService.deleteItem(item.path);
      if (mounted) {
        if (ok) {
          _loadDirectory(_currentPath, addHistory: false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete item"), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  IconData _getFileIcon(PhoneFileItem item) {
    if (item.isDirectory) return Icons.folder_rounded;
    switch (item.category) {
      case FileCategory.image:
        return Icons.image_rounded;
      case FileCategory.video:
        return Icons.movie_rounded;
      case FileCategory.audio:
        return Icons.audiotrack_rounded;
      case FileCategory.document:
        return Icons.description_rounded;
      case FileCategory.code:
        return Icons.code_rounded;
      case FileCategory.archive:
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileColor(PhoneFileItem item) {
    if (item.isDirectory) return const Color(0xFFFFC107); // Amber
    switch (item.category) {
      case FileCategory.image:
        return Colors.purpleAccent;
      case FileCategory.video:
        return Colors.redAccent;
      case FileCategory.audio:
        return Colors.pinkAccent;
      case FileCategory.document:
        return Colors.lightBlueAccent;
      case FileCategory.code:
        return const Color(0xFF00BFA5);
      case FileCategory.archive:
        return Colors.orangeAccent;
      default:
        return Colors.blueGrey.shade200;
    }
  }

  List<PhoneFileItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          // Top Window Title Bar (only shown when rendered as standalone modal dialog)
          if (!widget.isWindow) _buildTitleBar(),

          // Toolbar: Navigation, Path Breadcrumbs, Search, View Controls
          _buildToolbar(),

          // Main Body: Left Panel (Sidebar), Center Content (Grid/List), Right Preview Panel
          Expanded(
            child: Row(
              children: [
                // Left Navigation Panel
                _buildSidebar(),

                const VerticalDivider(width: 1, color: Colors.white10),

                // Center File & Directory Content Area
                Expanded(
                  child: _buildMainContent(),
                ),

                // Right Preview & Detail Inspector Panel
                if (_showPreviewPanel) ...[
                  const VerticalDivider(width: 1, color: Colors.white10),
                  _buildPreviewPanel(),
                ],
              ],
            ),
          ),

          // Bottom Status Bar
          _buildStatusBar(),
        ],
      ),
    );

    if (widget.isWindow) return body;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.98),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 1050,
        height: 680,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 30, spreadRadius: 5),
          ],
        ),
        child: body,
      ),
    );
  }

  // --- Title Bar Widget ---
  Widget _buildTitleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_special_rounded, color: Color(0xFF00BFA5), size: 22),
          const SizedBox(width: 10),
          const Text(
            "File Explorer",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined, color: Colors.white70, size: 20),
            tooltip: "New Folder",
            onPressed: _createFolderDialog,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded, color: Colors.white70, size: 20),
            tooltip: "Upload File to Phone",
            onPressed: _uploadFile,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            tooltip: "Refresh Directory",
            onPressed: () {
              _loadDirectory(_currentPath, addHistory: false);
              _loadStorageInfo();
            },
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white70, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  // --- Toolbar Widget ---
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF111827),
      child: Row(
        children: [
          // Navigation Back & Forward & Up
          IconButton(
            icon: Icon(Icons.arrow_back, color: _historyIndex > 0 ? Colors.white : Colors.white24, size: 18),
            onPressed: _historyIndex > 0 ? _navigateBack : null,
            tooltip: "Back",
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward, color: _historyIndex < _history.length - 1 ? Colors.white : Colors.white24, size: 18),
            onPressed: _historyIndex < _history.length - 1 ? _navigateForward : null,
            tooltip: "Forward",
          ),
          IconButton(
            icon: Icon(Icons.arrow_upward, color: _currentPath != '/' ? Colors.white : Colors.white24, size: 18),
            onPressed: _currentPath != '/' ? _navigateUp : null,
            tooltip: "Up Directory",
          ),
          const SizedBox(width: 8),

          // Path Breadcrumbs Bar
          Expanded(
            child: _buildBreadcrumbs(),
          ),
          const SizedBox(width: 12),

          // Search Field
          SizedBox(
            width: 180,
            height: 34,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: "Search folder...",
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 16),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.clear, color: Colors.white38, size: 14),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1F2937),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // View Mode Switcher
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.grid_view_rounded, color: _isGridView ? const Color(0xFF00BFA5) : Colors.white38, size: 18),
                  onPressed: () => setState(() => _isGridView = true),
                  tooltip: "Grid View",
                ),
                IconButton(
                  icon: Icon(Icons.view_list_rounded, color: !_isGridView ? const Color(0xFF00BFA5) : Colors.white38, size: 18),
                  onPressed: () => setState(() => _isGridView = false),
                  tooltip: "List View",
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Toggle Preview Panel Button
          IconButton(
            icon: Icon(Icons.vertical_split_rounded, color: _showPreviewPanel ? const Color(0xFF00BFA5) : Colors.white38, size: 20),
            onPressed: () => setState(() => _showPreviewPanel = !_showPreviewPanel),
            tooltip: "Toggle Preview Panel",
          ),
        ],
      ),
    );
  }

  // --- Interactive Breadcrumb Path Widget ---
  Widget _buildBreadcrumbs() {
    final segments = _currentPath.split('/').where((s) => s.isNotEmpty).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            InkWell(
              onTap: () => _loadDirectory('/sdcard'),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.phone_android_rounded, color: Color(0xFF00BFA5), size: 16),
                    SizedBox(width: 4),
                    Text("Storage", style: TextStyle(color: Color(0xFF00BFA5), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
            ...segments.asMap().entries.map((entry) {
              final index = entry.key;
              final seg = entry.value;
              final targetPath = '/${segments.sublist(0, index + 1).join('/')}';

              return Row(
                children: [
                  const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
                  InkWell(
                    onTap: () => _loadDirectory(targetPath),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        seg,
                        style: TextStyle(
                          color: targetPath == _currentPath ? Colors.white : Colors.white70,
                          fontWeight: targetPath == _currentPath ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- Left Sidebar (Storage & Shortcuts) ---
  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Storage Card
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text("STORAGES", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  _buildSidebarItem(
                    icon: Icons.phone_android_rounded,
                    iconColor: const Color(0xFF00BFA5),
                    label: "Internal Storage",
                    path: "/sdcard",
                    subtitle: _storageInfo != null ? "${_storageInfo!.available} free of ${_storageInfo!.total}" : null,
                  ),
                  _buildSidebarItem(
                    icon: Icons.sd_storage_rounded,
                    iconColor: Colors.amberAccent,
                    label: "External Storage",
                    path: "/storage",
                  ),
                  _buildSidebarItem(
                    icon: Icons.developer_board_rounded,
                    iconColor: Colors.lightBlueAccent,
                    label: "Root System",
                    path: "/",
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Divider(color: Colors.white10),
                  ),

                  // Important Shortcuts / Directories
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Text("SHORTCUTS", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  _buildSidebarItem(
                    icon: Icons.download_rounded,
                    iconColor: Colors.blueAccent,
                    label: "Downloads",
                    path: "/sdcard/Download",
                  ),
                  _buildSidebarItem(
                    icon: Icons.photo_library_rounded,
                    iconColor: Colors.purpleAccent,
                    label: "Pictures",
                    path: "/sdcard/Pictures",
                  ),
                  _buildSidebarItem(
                    icon: Icons.camera_alt_rounded,
                    iconColor: Colors.pinkAccent,
                    label: "DCIM (Camera)",
                    path: "/sdcard/DCIM",
                  ),
                  _buildSidebarItem(
                    icon: Icons.description_rounded,
                    iconColor: Colors.tealAccent,
                    label: "Documents",
                    path: "/sdcard/Documents",
                  ),
                  _buildSidebarItem(
                    icon: Icons.library_music_rounded,
                    iconColor: Colors.orangeAccent,
                    label: "Music",
                    path: "/sdcard/Music",
                  ),
                  _buildSidebarItem(
                    icon: Icons.video_library_rounded,
                    iconColor: Colors.redAccent,
                    label: "Movies",
                    path: "/sdcard/Movies",
                  ),
                ],
              ),
            ),
          ),

          // Storage usage indicator bar if available
          if (_storageInfo != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Device Storage", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text("${(_storageInfo!.percentage * 100).toInt()}%", style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _storageInfo!.percentage,
                      backgroundColor: Colors.white10,
                      color: _storageInfo!.percentage > 0.9 ? Colors.redAccent : const Color(0xFF00BFA5),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${_storageInfo!.used} used / ${_storageInfo!.total}",
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String path,
    String? subtitle,
  }) {
    final bool isSelected = _currentPath == path || _currentPath.startsWith('$path/');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: InkWell(
        onTap: () => _loadDirectory(path),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00BFA5).withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: const Color(0xFF00BFA5).withValues(alpha: 0.3)) : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF00BFA5) : iconColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Center File & Directory Content Area ---
  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00BFA5)),
            SizedBox(height: 16),
            Text("Fetching files from device...", style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
    }

    final items = _filteredItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.folder_open_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty ? "No files match '$_searchQuery'" : "This folder is empty",
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return _isGridView ? _buildGridView(items) : _buildListView(items);
  }

  // --- Grid Display View ---
  Widget _buildGridView(List<PhoneFileItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        childAspectRatio: 0.78,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedItem?.path == item.path;

        return InkWell(
          onTap: () => _selectItem(item),
          onDoubleTap: () {
            if (item.isDirectory) {
              _loadDirectory(item.path);
            } else {
              _selectItem(item);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF00BFA5).withValues(alpha: 0.2) : const Color(0xFF1E293B).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF00BFA5) : Colors.white10,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 2),
                Icon(_getFileIcon(item), size: 36, color: _getFileColor(item)),
                const SizedBox(height: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500, height: 1.15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      if (item.formattedSize.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.formattedSize,
                          style: const TextStyle(color: Colors.white38, fontSize: 9),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- List Display View ---
  Widget _buildListView(List<PhoneFileItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedItem?.path == item.path;

        return GestureDetector(
          onDoubleTap: () {
            if (item.isDirectory) {
              _loadDirectory(item.path);
            }
          },
          child: ListTile(
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: isSelected ? const Color(0xFF00BFA5).withValues(alpha: 0.15) : Colors.transparent,
            leading: Icon(_getFileIcon(item), color: _getFileColor(item), size: 22),
            title: Text(
              item.name,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00BFA5) : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: item.modifiedDate.isNotEmpty
                ? Text(
                    item.modifiedDate,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.formattedSize, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(width: 12),
                if (!item.isDirectory)
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 18),
                    tooltip: "Download to PC",
                    onPressed: () => _downloadFile(item),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 18),
                  tooltip: "Delete",
                  onPressed: () => _deleteItem(item),
                ),
              ],
            ),
            onTap: () => _selectItem(item),
          ),
        );
      },
    );
  }

  // --- Right Preview & Detail Inspector Panel ---
  Widget _buildPreviewPanel() {
    return Container(
      width: 270,
      color: const Color(0xFF111827),
      padding: const EdgeInsets.all(16),
      child: _selectedItem != null ? _buildItemPreview(_selectedItem!) : _buildFolderSummary(),
    );
  }

  Widget _buildFolderSummary() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.info_outline_rounded, size: 48, color: Colors.white24),
        const SizedBox(height: 12),
        const Text("Folder Details", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Text("Path: $_currentPath", style: const TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text("${_items.length} items in current directory", style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 12)),
      ],
    );
  }

  Widget _buildItemPreview(PhoneFileItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview Header / Canvas
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: _isFetchingPreview
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00BFA5)))
              : _previewLocalPath != null && item.category == FileCategory.image
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_previewLocalPath!),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.white38, size: 40)),
                      ),
                    )
                  : _previewTextContent != null
                      ? Container(
                          padding: const EdgeInsets.all(8),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _previewTextContent!,
                              style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 10),
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(_getFileIcon(item), size: 56, color: _getFileColor(item)),
                        ),
        ),
        const SizedBox(height: 16),

        // Item Metadata Title
        SelectableText(
          item.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          item.isDirectory ? "Directory" : "${item.extension.toUpperCase()} File",
          style: TextStyle(color: _getFileColor(item), fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),

        const Divider(color: Colors.white10),

        // Metadata Key-Values
        _buildMetaRow("Path", item.path),
        _buildMetaRow("Size", item.formattedSize),
        if (item.sizeBytes > 0) _buildMetaRow("Raw Bytes", "${item.sizeBytes} B"),
        if (item.modifiedDate.isNotEmpty) _buildMetaRow("Modified", item.modifiedDate),

        const Spacer(),

        // Quick Actions
        Row(
          children: [
            if (!item.isDirectory)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download_rounded, color: Colors.black, size: 16),
                  label: const Text("Download", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _downloadFile(item),
                ),
              ),
            if (!item.isDirectory) const SizedBox(width: 8),
            IconButton(
              style: IconButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2)),
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
              tooltip: "Delete Item",
              onPressed: () => _deleteItem(item),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // --- Bottom Status Bar ---
  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Text(
            "${_filteredItems.length} items",
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          if (_selectedItem != null) ...[
            const SizedBox(width: 12),
            const Text("|", style: TextStyle(color: Colors.white24, fontSize: 11)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Selected: ${_selectedItem!.name} (${_selectedItem!.formattedSize})",
                style: const TextStyle(color: Color(0xFF00BFA5), fontSize: 11, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
