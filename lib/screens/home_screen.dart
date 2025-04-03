import 'package:flutter/material.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import '../models/file_index.dart';
import '../screens/categories_tab.dart';
import '../screens/browse_tab.dart';
// import '../screens/cleanup_screen.dart';
import '../screens/events_screen.dart';
import '../screens/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _permissionGranted = false;
  int _selectedIndex = 0; // For bottom navigation
  final FileIndex _fileIndex = FileIndex();
  bool _isIndexing = false;
  double _indexingProgress = 0.0;
  String _currentFileBeingIndexed = "";
  int _totalFiles = 0;
  int _processedFiles = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedIndexData();
    _requestPermission();

    // Set progress callback
    _fileIndex.onIndexingProgress = _updateProgress;
  }

  void _updateProgress(double progress, String currentFile) {
    setState(() {
      _indexingProgress = progress;
      _currentFileBeingIndexed = currentFile;
      _processedFiles = _fileIndex.filesIndexed;
      _totalFiles = _fileIndex.totalFilesToIndex;
      _isIndexing = _fileIndex.isIndexing;
    });
  }

  Future<void> _loadSavedIndexData() async {
    try {
      final bool hasData = await _fileIndex.loadIndexedData();
      if (hasData) {
        // Validate that the indexed files still exist
        final bool isValid = await _fileIndex.validateIndex();
        if (!isValid) {
          // If invalid, we'll reindex when permissions are granted
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Index data has changed, reindexing files...')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Loaded indexed data from storage')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading saved index data: $e');
    }
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ (API 33+)
        // For Android 13 and above, request specific media permissions
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        final audio = await Permission.audio.request();

        setState(() {
          _permissionGranted =
              photos.isGranted || videos.isGranted || audio.isGranted;
        });

        if (androidInfo.version.sdkInt >= 34) {
          // Android 14+ (API 34+)
          final manageMedia = await Permission.manageExternalStorage.request();
          setState(() {
            _permissionGranted = _permissionGranted || manageMedia.isGranted;
          });
        }
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11 and 12
        final status = await Permission.manageExternalStorage.request();
        setState(() {
          _permissionGranted = status.isGranted;
        });
      } else {
        // Android 10 and below
        final status = await Permission.storage.request();
        setState(() {
          _permissionGranted = status.isGranted;
        });
      }

      // If permission still not granted
      if (!_permissionGranted) {
        _showPermissionDialog();
      }
    } else {
      // For iOS or other platforms
      final status = await Permission.storage.request();
      setState(() {
        _permissionGranted = status.isGranted;
      });
    }

    // After permissions are granted, start indexing
    if (_permissionGranted) {
      _startFileIndexing();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Storage Permission Required'),
          content: const Text(
            'This app needs full storage access to manage your files. Please enable "Allow management of all files" in the next screen.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(context).pop();
                AppSettings.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _startFileIndexing() async {
    if (_fileIndex.isIndexing) return;

    // Reset progress tracking
    _fileIndex.resetIndexingProgress();

    setState(() {
      _isIndexing = true;
      _indexingProgress = 0.0;
      _currentFileBeingIndexed = "";
      _processedFiles = 0;
      _totalFiles = 0;
    });

    try {
      // Start with the most common directories
      await _fileIndex.indexDirectory('/storage/emulated/0/Download');
      await _fileIndex.indexDirectory('/storage/emulated/0/DCIM');
      await _fileIndex.indexDirectory('/storage/emulated/0/Pictures');
      await _fileIndex.indexDirectory('/storage/emulated/0/Documents');
      await _fileIndex.indexDirectory('/storage/emulated/0/Music');

      // Save indexed data when complete
      await _fileIndex.saveIndexedData();
    } catch (e) {
      debugPrint('Error during file indexing: $e');
    } finally {
      setState(() {
        _isIndexing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Files'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          if (_isIndexing) _buildIndexingIndicator(),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearch,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showMenu(
                context: context,
                position: const RelativeRect.fromLTRB(100, 100, 0, 0),
                items: [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Text('Settings'),
                  ),
                  PopupMenuItem(
                    value: 'reindex',
                    child: Row(
                      children: const [
                        Icon(Icons.refresh, size: 20),
                        SizedBox(width: 8),
                        Text('Reindex files'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'help',
                    child: Text('Help & feedback'),
                  ),
                ],
                elevation: 8,
              ).then((value) {
                if (value == 'reindex') {
                  _startFileIndexing();
                } else if (value == 'settings') {
                  // TODO: Show settings
                } else if (value == 'help') {
                  // TODO: Show help
                }
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          _permissionGranted
              ? _getSelectedPage()
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_off,
                        size: 72,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Storage permission is required',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _requestPermission,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Grant Permission'),
                      ),
                    ],
                  ),
                ),

          // Indexing overlay
          if (_isIndexing && _indexingProgress > 0) _buildIndexingOverlay(),
        ],
      ),
      floatingActionButton: null,
      floatingActionButtonLocation: null,
      bottomNavigationBar: _permissionGranted
          ? BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8.0,
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Left side buttons
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.home_filled,
                            color: _selectedIndex == 0
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => _selectedIndex = 0),
                          tooltip: 'Home',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.folder,
                            color: _selectedIndex == 1
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => _selectedIndex = 1),
                          tooltip: 'Browse',
                        ),
                      ],
                    ),
                  ),

                  // Center button (Chat)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .shadow
                              .withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Material(
                        color: Theme.of(context).colorScheme.primary,
                        child: InkWell(
                          onTap: _showSearch,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Chat',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Right side buttons
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.local_activity,
                            color: _selectedIndex == 2
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => _selectedIndex = 2),
                          tooltip: 'Clean',
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () {
                            // Implement settings navigation
                          },
                          tooltip: 'Settings',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildIndexingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: _indexingProgress > 0 ? _indexingProgress : null,
              color: Colors.white,
            ),
          ),
          if (_processedFiles > 0)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                "$_processedFiles",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIndexingOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Indexing Files',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_processedFiles / $_totalFiles',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: _indexingProgress,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _currentFileBeingIndexed,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return const CategoriesTab();
      case 1:
        return const BrowseTab();
      case 2:
        return const EventsScreen();
      default:
        return const CategoriesTab();
    }
  }

  void _showSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          fileIndex: _fileIndex,
          apiKey: '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',
        ),
      ),
    );
  }
}
