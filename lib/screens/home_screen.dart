import 'package:flutter/material.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import '../models/file_index.dart';
import '../screens/categories_tab.dart';
import '../screens/browse_tab.dart';
// import '../screens/cleanup_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _requestPermission();
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
    if (_isIndexing) return;

    setState(() {
      _isIndexing = true;
    });

    try {
      // Start with the most common directories
      await _fileIndex.indexDirectory('/storage/emulated/0/Download');
      await _fileIndex.indexDirectory('/storage/emulated/0/DCIM');
      await _fileIndex.indexDirectory('/storage/emulated/0/Pictures');
      await _fileIndex.indexDirectory('/storage/emulated/0/Documents');
      await _fileIndex.indexDirectory('/storage/emulated/0/Music');
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
          if (_isIndexing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
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
                items: const [
                  PopupMenuItem(
                    value: 'settings',
                    child: Text('Settings'),
                  ),
                  PopupMenuItem(
                    value: 'help',
                    child: Text('Help & feedback'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: _permissionGranted
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
      floatingActionButton: _permissionGranted
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.shadow.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FloatingActionButton(
                  onPressed: _showSearch,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.chat,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _permissionGranted
          ? BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8.0,
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Left side of FAB
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
                  // Right side of FAB
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.cleaning_services,
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

  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return const CategoriesTab();
      case 1:
        return const BrowseTab();
      // case 2:
      //   return const CleanupScreen();
      default:
        return const CategoriesTab();
    }
  }

  void _showSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(fileIndex: _fileIndex),
      ),
    );
  }
}
