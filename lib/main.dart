import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:app_settings/app_settings.dart';
import 'package:open_file/open_file.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:flutter/services.dart'; // For ImageByteFormat

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Files App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: ThemeMode.system, // This will follow the system theme
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  Future<bool> _isAndroid11OrHigher() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 30; // Android 11 is API 30
    }
    return false;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Storage Permission Required'),
          content: Text(
            'This app needs full storage access to manage your files. Please enable "Allow management of all files" in the next screen.',
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Open Settings'),
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

      // If time allows, index the entire storage (this could take a while)
      // This is optional, but would provide the most complete search
      // await _fileIndex.indexDirectory('/storage/emulated/0', recursive: true);
    } catch (e) {
      print('Error during file indexing: $e');
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
        title: Text('Files'),
        elevation: 0,
        actions: [
          _isIndexing
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : SizedBox.shrink(),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: _showSearch,
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // Show settings menu
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(100, 100, 0, 0),
                items: [
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
                  Icon(
                    Icons.folder_off,
                    size: 72,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Storage permission is required',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _requestPermission,
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text('Grant Permission'),
                  ),
                ],
              ),
            ),
      floatingActionButton: _permissionGranted
          ? FloatingActionButton(
              onPressed: _showSearch,
              child: Icon(Icons.chat),
              tooltip: 'Chat with AI Assistant',
            )
          : null,
      bottomNavigationBar: _permissionGranted
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.folder),
                  label: 'Browse',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.cleaning_services),
                  label: 'Clean',
                ),
              ],
            )
          : null,
    );
  }

  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return CategoriesTab();
      case 1:
        return BrowseTab();
      case 2:
        return CleanupScreen();
      default:
        return CategoriesTab();
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

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        CleanupCard(),
        SizedBox(height: 16),
        CategorySection(
          title: 'Storage',
          items: [
            CategoryItem(
              title: 'Downloads',
              icon: Icons.download,
              color: Colors.blue,
              onTap: () {
                // Navigate to downloads directory
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FileListScreen(
                      title: 'Downloads',
                      directoryPath: '/storage/emulated/0/Download',
                    ),
                  ),
                );
              },
            ),
            CategoryItem(
              title: 'Images',
              icon: Icons.image,
              color: Colors.purple,
              onTap: () {
                // Navigate to images directory
              },
            ),
            CategoryItem(
              title: 'Videos',
              icon: Icons.video_library,
              color: Colors.red,
              onTap: () {
                // Navigate to videos directory
              },
            ),
            CategoryItem(
              title: 'Audio',
              icon: Icons.music_note,
              color: Colors.orange,
              onTap: () {
                // Navigate to audio directory
              },
            ),
          ],
        ),
        SizedBox(height: 16),
        CategorySection(
          title: 'Categories',
          items: [
            CategoryItem(
              title: 'Documents',
              icon: Icons.description,
              color: Colors.teal,
              onTap: () {
                // Navigate to documents collection
              },
            ),
            CategoryItem(
              title: 'Archives',
              icon: Icons.archive,
              color: Colors.brown,
              onTap: () {
                // Navigate to archives collection
              },
            ),
          ],
        ),
      ],
    );
  }
}

class CleanupCard extends StatelessWidget {
  const CleanupCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Free up space',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: 0.7,
                    backgroundColor: Colors.grey[300],
                  ),
                ),
                SizedBox(width: 16),
                Text('70% full'),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Show cleanup suggestions
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CleanupScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Clean'),
            ),
          ],
        ),
      ),
    );
  }
}

class CategorySection extends StatelessWidget {
  final String title;
  final List<CategoryItem> items;

  const CategorySection({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: items,
        ),
      ],
    );
  }
}

class CategoryItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CategoryItem({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: color,
                size: 32,
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BrowseTab extends StatefulWidget {
  const BrowseTab({super.key});

  @override
  _BrowseTabState createState() => _BrowseTabState();
}

class _BrowseTabState extends State<BrowseTab> {
  String _currentPath = '';
  List<FileSystemEntity> _items = [];
  bool _isLoading = true;
  bool _pathInitialized = false;
  bool _showHiddenFiles = false;
  List<String> _navigationHistory = [];

  @override
  void initState() {
    super.initState();
    _initPath();
  }

  Future<void> _initPath() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // For Android 11+ access to common directories
      String path;
      if (Platform.isAndroid) {
        // Try to get the external storage first
        Directory? externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navigate to root Android folder for better access
          // This gets us closer to the root of the device storage
          path = externalDir.path.split('Android')[0];
        } else {
          // If unable to get external directory, use fallback
          path = '/storage/emulated/0';
        }
      } else {
        // iOS or other platforms
        Directory? docDir = await getApplicationDocumentsDirectory();
        path = docDir?.path ?? '';
      }

      setState(() {
        _currentPath = path;
        _pathInitialized = true;
        _isLoading = false;
      });

      // After setting the path, load files
      _loadFiles();
    } catch (e) {
      print("Error initializing path: $e");
      // Fallback
      setState(() {
        _currentPath = '/storage/emulated/0';
        _pathInitialized = true;
        _isLoading = false;
      });
      _loadFiles();
    }
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dir = Directory(_currentPath);
      final entities = await dir.list().toList();

      // Filter hidden files if needed
      final filteredEntities = _showHiddenFiles
          ? entities
          : entities
              .where((e) => !e.path.split('/').last.startsWith('.'))
              .toList();

      // Sort as before
      filteredEntities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      setState(() {
        _items = filteredEntities;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading files: $e");
      setState(() {
        _items = [];
        _isLoading = false;
      });
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading files: ${e.toString()}')),
      );
    }
  }

  void _navigateToDirectory(String path) {
    if (_currentPath.isNotEmpty) {
      _navigationHistory.add(_currentPath);
    }

    setState(() {
      _currentPath = path;
    });
    _loadFiles();
  }

  bool handleBackPress() {
    if (_navigationHistory.isNotEmpty) {
      String previousPath = _navigationHistory.removeLast();
      setState(() {
        _currentPath = previousPath;
      });
      _loadFiles();
      return true;
    }
    return false;
  }

  void _openFile(String path) {
    try {
      OpenFile.open(path).then((result) {
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  void _openImage(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(imagePath: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return !handleBackPress();
      },
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            margin: EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_upward),
                  onPressed: _currentPath == '/storage/emulated/0'
                      ? null
                      : () {
                          final parentDir = Directory(_currentPath).parent;
                          setState(() {
                            if (_navigationHistory.isNotEmpty) {
                              _currentPath = _navigationHistory.removeLast();
                            } else {
                              _currentPath = parentDir.path;
                            }
                          });
                          _loadFiles();
                        },
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPath,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(_showHiddenFiles
                      ? Icons.visibility
                      : Icons.visibility_off),
                  tooltip: _showHiddenFiles
                      ? 'Hide hidden files'
                      : 'Show hidden files',
                  onPressed: () {
                    setState(() {
                      _showHiddenFiles = !_showHiddenFiles;
                    });
                    _loadFiles();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? _buildEmptyState()
                    : _buildFileListWithCategories(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 72,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No files found in this directory',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFileListWithCategories() {
    // Group files by type
    Map<String, List<FileSystemEntity>> categorizedFiles = {
      'Folders': _items.where((item) => item is Directory).toList(),
      'Images': _items
          .where((item) =>
              item is File &&
              ['.jpg', '.jpeg', '.png', '.gif']
                  .any((ext) => item.path.toLowerCase().endsWith(ext)))
          .toList(),
      'Videos': _items
          .where((item) =>
              item is File &&
              ['.mp4', '.avi', '.mov', '.mkv']
                  .any((ext) => item.path.toLowerCase().endsWith(ext)))
          .toList(),
      'Audio': _items
          .where((item) =>
              item is File &&
              ['.mp3', '.wav', '.aac', '.ogg']
                  .any((ext) => item.path.toLowerCase().endsWith(ext)))
          .toList(),
      'Documents': _items
          .where((item) =>
              item is File &&
              [
                '.pdf',
                '.doc',
                '.docx',
                '.txt',
                '.xls',
                '.xlsx',
                '.ppt',
                '.pptx'
              ].any((ext) => item.path.toLowerCase().endsWith(ext)))
          .toList(),
      'Others': _items
          .where((item) =>
              item is File &&
              ![
                '.jpg',
                '.jpeg',
                '.png',
                '.gif',
                '.mp4',
                '.avi',
                '.mov',
                '.mkv',
                '.mp3',
                '.wav',
                '.aac',
                '.ogg',
                '.pdf',
                '.doc',
                '.docx',
                '.txt',
                '.xls',
                '.xlsx',
                '.ppt',
                '.pptx'
              ].any((ext) => item.path.toLowerCase().endsWith(ext)))
          .toList(),
    };

    // Remove empty categories
    categorizedFiles.removeWhere((key, value) => value.isEmpty);

    return ListView.builder(
      itemCount: categorizedFiles.keys.length,
      itemBuilder: (context, index) {
        String category = categorizedFiles.keys.elementAt(index);
        List<FileSystemEntity> files = categorizedFiles[category]!;

        return ExpansionTile(
          title: Text(
            category,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
          collapsedBackgroundColor:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.black
                  : Colors.white,
          iconColor: Theme.of(context).colorScheme.primary,
          collapsedIconColor: Theme.of(context).colorScheme.primary,
          initiallyExpanded: true,
          children: files.map((item) => _buildFileListItem(item)).toList(),
        );
      },
    );
  }

  Widget _buildFileListItem(FileSystemEntity item) {
    final fileName = item.path.split('/').last;
    final isDirectory = item is Directory;
    final isImage = !isDirectory &&
        ['.jpg', '.jpeg', '.png', '.gif', '.webp']
            .any((ext) => fileName.toLowerCase().endsWith(ext));

    return ListTile(
      leading: isDirectory
          ? Icon(Icons.folder, color: Colors.amber, size: 40)
          : isImage
              ? Container(
                  width: 40,
                  height: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      File(item.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(_getFileIcon(fileName), color: Colors.blue);
                      },
                    ),
                  ),
                )
              : Icon(_getFileIcon(fileName), color: Colors.blue, size: 40),
      title: Text(fileName),
      subtitle: FutureBuilder<FileStat>(
        future: item.stat(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Text('Loading...');
          }

          final stat = snapshot.data!;
          final modified = DateFormat('MMM dd, yyyy').format(stat.modified);
          final size = isDirectory ? '' : _formatSize(stat.size);

          return Text('$modified${size.isNotEmpty ? ' • $size' : ''}');
        },
      ),
      onTap: () {
        if (isDirectory) {
          _navigateToDirectory(item.path);
        } else if (isImage) {
          _openImage(item.path);
        } else {
          _openFile(item.path);
        }
      },
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'share',
            child: Text('Share'),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text('Delete'),
          ),
          PopupMenuItem(
            value: 'info',
            child: Text('Info'),
          ),
        ],
        onSelected: (value) {
          // Handle menu actions
          if (value == 'delete') {
            _showDeleteDialog(item);
          } else if (value == 'info') {
            _showFileInfo(item);
          }
        },
      ),
      tileColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      shape: Border(
        bottom: BorderSide(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    String lowercaseName = fileName.toLowerCase();
    if (lowercaseName.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    } else if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.image;
    } else if (['.mp3', '.wav', '.aac', '.ogg', '.flac', '.m4a']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.music_note;
    } else if (['.mp4', '.avi', '.mov', '.mkv', '.webm', '.flv', '.3gp']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.video_library;
    } else if (['.doc', '.docx', '.txt', '.rtf', '.odt', '.md']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.description;
    } else if (['.xls', '.xlsx', '.csv', '.ods']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.table_chart;
    } else if (['.ppt', '.pptx', '.odp']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.slideshow;
    } else if (['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.archive;
    } else if (['.apk', '.xapk'].any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.android;
    }

    return Icons.insert_drive_file;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  void _showDeleteDialog(FileSystemEntity item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${item.path.split('/').last}?'),
        content: Text('This item will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await item.delete(recursive: true);
                _loadFiles(); // Refresh file list
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Item deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error deleting item: ${e.toString()}')),
                );
              }
            },
            child: Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _showFileInfo(FileSystemEntity item) {
    // Implement file info dialog
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<FileStat>(
        future: item.stat(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return AlertDialog(
              title: Text('Loading...'),
              content: Center(child: CircularProgressIndicator()),
            );
          }

          final stat = snapshot.data!;
          final fileName = item.path.split('/').last;
          final modified =
              DateFormat('MMM dd, yyyy HH:mm').format(stat.modified);
          final size = item is File ? _formatSize(stat.size) : 'Directory';

          return AlertDialog(
            title: Text(fileName),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text('Path'),
                  subtitle: Text(item.path),
                ),
                ListTile(
                  title: Text('Size'),
                  subtitle: Text(size),
                ),
                ListTile(
                  title: Text('Modified'),
                  subtitle: Text(modified),
                ),
                ListTile(
                  title: Text('Type'),
                  subtitle: Text(item is Directory ? 'Directory' : 'File'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CLOSE'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FileListScreen extends StatefulWidget {
  final String title;
  final String directoryPath;

  const FileListScreen({
    super.key,
    required this.title,
    required this.directoryPath,
  });

  @override
  _FileListScreenState createState() => _FileListScreenState();
}

class _FileListScreenState extends State<FileListScreen> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dir = Directory(widget.directoryPath);
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        entities.sort((a, b) {
          final aIsDir = a is Directory;
          final bIsDir = b is Directory;
          if (aIsDir && !bIsDir) return -1;
          if (!aIsDir && bIsDir) return 1;
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });

        setState(() {
          _files = entities;
          _isLoading = false;
        });
      } else {
        setState(() {
          _files = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _files = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: () {
              // Show sort options
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(child: Text('No files found'))
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final fileName = file.path.split('/').last;
                    final isDirectory = file is Directory;

                    return ListTile(
                      leading: Icon(
                        isDirectory ? Icons.folder : _getFileIcon(fileName),
                        color: isDirectory ? Colors.amber : Colors.blue,
                      ),
                      title: Text(fileName),
                      subtitle: FutureBuilder<FileStat>(
                        future: file.stat(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Text('Loading...');
                          }

                          final stat = snapshot.data!;
                          final modified =
                              DateFormat('MMM dd, yyyy').format(stat.modified);
                          final size =
                              isDirectory ? '' : _formatSize(stat.size);

                          return Text(
                              '$modified${size.isNotEmpty ? ' • $size' : ''}');
                        },
                      ),
                      // Rest of the implementation similar to BrowseTab
                    );
                  },
                ),
    );
  }

  IconData _getFileIcon(String fileName) {
    String lowercaseName = fileName.toLowerCase();
    if (lowercaseName.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    } else if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.image;
    } else if (['.mp3', '.wav', '.aac', '.ogg', '.flac', '.m4a']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.music_note;
    } else if (['.mp4', '.avi', '.mov', '.mkv', '.webm', '.flv', '.3gp']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.video_library;
    } else if (['.doc', '.docx', '.txt', '.rtf', '.odt', '.md']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.description;
    } else if (['.xls', '.xlsx', '.csv', '.ods']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.table_chart;
    } else if (['.ppt', '.pptx', '.odp']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.slideshow;
    } else if (['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.archive;
    } else if (['.apk', '.xapk'].any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.android;
    }

    return Icons.insert_drive_file;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

class CleanupScreen extends StatelessWidget {
  const CleanupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Clean up'),
      ),
      body: ListView(
        children: [
          CleanupCategory(
            title: 'Junk files',
            subtitle: 'Temporary files, cache',
            icon: Icons.delete_outline,
            size: '1.2 GB',
          ),
          CleanupCategory(
            title: 'Duplicate files',
            subtitle: 'Files that appear more than once',
            icon: Icons.file_copy,
            size: '450 MB',
          ),
          CleanupCategory(
            title: 'Large files',
            subtitle: 'Files larger than 100 MB',
            icon: Icons.save,
            size: '2.3 GB',
          ),
        ],
      ),
    );
  }
}

class CleanupCategory extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String size;

  const CleanupCategory({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            size,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          Text('Select'),
        ],
      ),
      onTap: () {
        // Navigate to specific cleanup screen
      },
    );
  }
}

class FileSearchDelegate extends SearchDelegate<String> {
  final FileIndex fileIndex;
  final List<String> recentSearches = [];
  bool _isSearching = false;
  List<String> _searchResults = [];
  BuildContext? _context;

  FileSearchDelegate({required this.fileIndex});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
          _searchResults.clear();
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    _context = context;

    if (query.isEmpty) {
      return Center(
        child: Text('Enter something to search'),
      );
    }

    if (!_isSearching && _searchResults.isEmpty) {
      _performSearch();
    }

    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching...'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text('No results found for "$query"'),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final filePath = _searchResults[index];
        final fileName = filePath.split('/').last;
        final isDirectory = FileSystemEntity.isDirectorySync(filePath);

        return ListTile(
          leading: Icon(
            isDirectory ? Icons.folder : _getFileIcon(fileName),
            color: isDirectory ? Colors.amber : Colors.blue,
          ),
          title: Text(fileName),
          subtitle: Text(filePath),
          onTap: () {
            if (isDirectory) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FileListScreen(
                    title: fileName,
                    directoryPath: filePath,
                  ),
                ),
              );
            } else {
              _openFile(context, filePath);
            }
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Show recent searches and search suggestions
    if (query.isEmpty) {
      return ListView.builder(
        itemCount: recentSearches.length,
        itemBuilder: (context, index) {
          final search = recentSearches[index];
          return ListTile(
            leading: Icon(Icons.history),
            title: Text(search),
            onTap: () {
              query = search;
              showResults(context);
            },
          );
        },
      );
    }

    // Show matching recent searches as suggestions
    final suggestions = recentSearches
        .where((search) => search.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final search = suggestions[index];
        return ListTile(
          leading: Icon(Icons.history),
          title: RichText(
            text: TextSpan(
              text: search.substring(
                  0, search.toLowerCase().indexOf(query.toLowerCase())),
              style: TextStyle(color: Colors.grey),
              children: [
                TextSpan(
                  text: search.substring(
                    search.toLowerCase().indexOf(query.toLowerCase()),
                    search.toLowerCase().indexOf(query.toLowerCase()) +
                        query.length,
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: search.substring(
                    search.toLowerCase().indexOf(query.toLowerCase()) +
                        query.length,
                  ),
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          onTap: () {
            query = search;
            showResults(context);
          },
        );
      },
    );
  }

  void _performSearch() async {
    if (query.isEmpty || _context == null) return;

    _isSearching = true;
    _searchResults = [];

    // Add to recent searches
    if (!recentSearches.contains(query)) {
      recentSearches.insert(0, query);
      // Limit the number of recent searches
      if (recentSearches.length > 10) {
        recentSearches.removeLast();
      }
    }

    try {
      // Use file index to search
      final results = fileIndex.semanticSearch(query);
      _searchResults = results;
      _isSearching = false;

      // Force refresh UI
      if (_context != null) {
        showResults(_context!);
      }
    } catch (e) {
      print('Search error: $e');
      _isSearching = false;
    }
  }

  void _openFile(BuildContext context, String path) {
    try {
      OpenFile.open(path).then((result) {
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }
}

class ImageViewerScreen extends StatelessWidget {
  final String imagePath;

  const ImageViewerScreen({required this.imagePath, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(imagePath.split('/').last),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              // Implement sharing
            },
          ),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              // Open in external editor
              OpenFile.open(imagePath);
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Unable to load image'),
                  TextButton(
                    onPressed: () {
                      OpenFile.open(imagePath);
                    },
                    child: Text('Open with external app'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

IconData _getFileIcon(String fileName) {
  String lowercaseName = fileName.toLowerCase();
  if (lowercaseName.endsWith('.pdf')) {
    return Icons.picture_as_pdf;
  } else if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif']
      .any((ext) => lowercaseName.endsWith(ext))) {
    return Icons.image;
  } else if (['.mp3', '.wav', '.aac', '.ogg', '.flac', '.m4a']
      .any((ext) => lowercaseName.endsWith(ext))) {
    return Icons.music_note;
  } else if (['.mp4', '.avi', '.mov', '.mkv', '.webm', '.flv', '.3gp']
      .any((ext) => lowercaseName.endsWith(ext))) {
    return Icons.video_library;
  } else if (['.doc', '.docx', '.txt', '.rtf', '.odt', '.md']
      .any((ext) => lowercaseName.endsWith(ext))) {
    return Icons.description;
  } else if (['.xls', '.xlsx', '.csv', '.ods']
      .any((ext) => lowercaseName.endsWith(ext))) {
    return Icons.table_chart;
  } else if (['.ppt', '.pptx', '.odp']
      .any((ext) => lowercaseName.endsWith(ext))) {
    return Icons.slideshow;
  } else if (['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2']
      .any((ext) => lowercaseName.endsWith(ext))) {
    return Icons.archive;
  } else if (['.apk', '.xapk'].any((ext) => lowercaseName.endsWith(ext))) {
    return Icons.android;
  }

  return Icons.insert_drive_file;
}

class FileIndex {
  // Map to store file paths indexed by filename
  Map<String, List<String>> _fileNameIndex = {};
  // Map to store file paths indexed by file extension
  Map<String, List<String>> _fileExtensionIndex = {};
  // Set to track indexed directories to avoid duplicates
  Set<String> _indexedDirectories = {};

  // Track common words to ignore in semantic search
  final Set<String> _stopWords = {
    'the',
    'a',
    'an',
    'and',
    'or',
    'but',
    'is',
    'are',
    'in',
    'to',
    'of',
    'for',
    'with',
    'on',
    'at',
    'by',
    'from',
    'up',
    'about',
    'into',
    'over',
    'after'
  };

  // Map to store semantic keywords extracted from filenames
  Map<String, List<String>> _semanticIndex = {};

  // Process filename to extract semantic keywords
  void _extractKeywords(String fileName, String path) {
    // Remove extension
    String nameWithoutExt = fileName;
    if (fileName.contains('.')) {
      nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
    }

    // Split into words and normalize
    final words = nameWithoutExt
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ') // Remove special chars
        .split(RegExp(r'\s+')) // Split on whitespace
        .map((word) => word.toLowerCase()) // Convert to lowercase
        .where((word) =>
            word.isNotEmpty &&
            word.length > 1 &&
            !_stopWords.contains(word)) // Filter stop words
        .toList();

    // Add each word to semantic index
    for (var word in words) {
      if (!_semanticIndex.containsKey(word)) {
        _semanticIndex[word] = [];
      }
      _semanticIndex[word]!.add(path);
    }
  }

  // Check if a directory has been indexed
  bool isDirectoryIndexed(String path) {
    return _indexedDirectories.contains(path);
  }

  // Add a file to the index
  void addFile(FileSystemEntity entity) {
    if (entity is! File) return;

    final String path = entity.path;
    final String fileName = path.split('/').last.toLowerCase();
    final String fileNameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final String extension = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.') + 1)
        : '';

    // Index by filename
    if (!_fileNameIndex.containsKey(fileNameWithoutExt)) {
      _fileNameIndex[fileNameWithoutExt] = [];
    }
    _fileNameIndex[fileNameWithoutExt]!.add(path);

    // Index by extension
    if (extension.isNotEmpty) {
      if (!_fileExtensionIndex.containsKey(extension)) {
        _fileExtensionIndex[extension] = [];
      }
      _fileExtensionIndex[extension]!.add(path);
    }

    // Add semantic indexing
    _extractKeywords(fileName, path);
  }

  // Index all files in a directory recursively
  Future<void> indexDirectory(String dirPath, {bool recursive = true}) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;

      _indexedDirectories.add(dirPath);

      final List<FileSystemEntity> entities = await dir.list().toList();

      for (var entity in entities) {
        if (entity is File) {
          addFile(entity);
        } else if (recursive && entity is Directory) {
          await indexDirectory(entity.path);
        }
      }
    } catch (e) {
      print('Error indexing directory: $e');
    }
  }

  // Search files by name (partial match)
  List<String> searchByName(String query) {
    query = query.toLowerCase();
    final results = <String>{};

    _fileNameIndex.forEach((fileName, paths) {
      if (fileName.contains(query)) {
        results.addAll(paths);
      }
    });

    return results.toList();
  }

  // Search files by extension
  List<String> searchByExtension(String extension) {
    extension = extension.toLowerCase();
    return _fileExtensionIndex[extension] ?? [];
  }

  // Search files by combined criteria
  List<String> search(String query, {String? extension}) {
    query = query.toLowerCase();
    final nameResults = searchByName(query);

    // If extension filter is provided, filter by that too
    if (extension != null && extension.isNotEmpty) {
      final extensionResults = searchByExtension(extension);
      return nameResults
          .where((path) => extensionResults.contains(path))
          .toList();
    }

    return nameResults;
  }

  // Clear the index
  void clear() {
    _fileNameIndex.clear();
    _fileExtensionIndex.clear();
    _indexedDirectories.clear();
  }

  // Add this method for semantic search
  List<String> semanticSearch(String query) {
    query = query.toLowerCase();

    // Split query into words
    final queryWords = query
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .map((word) => word.toLowerCase())
        .where((word) =>
            word.isNotEmpty && word.length > 1 && !_stopWords.contains(word))
        .toList();

    // Score system: map of file path to its relevance score
    final Map<String, double> scores = {};

    // Calculate scores for each file based on matching words
    for (var word in queryWords) {
      // First, look for exact matches
      if (_semanticIndex.containsKey(word)) {
        for (var path in _semanticIndex[word]!) {
          scores[path] =
              (scores[path] ?? 0) + 1.0; // Full weight for exact match
        }
      }

      // Then look for partial matches (prefix)
      _semanticIndex.keys
          .where((key) => key.startsWith(word))
          .forEach((matchedWord) {
        for (var path in _semanticIndex[matchedWord]!) {
          scores[path] =
              (scores[path] ?? 0) + 0.7; // Lower weight for partial match
        }
      });

      // Finally, look for contains matches
      _semanticIndex.keys
          .where((key) => key.contains(word) && !key.startsWith(word))
          .forEach((matchedWord) {
        for (var path in _semanticIndex[matchedWord]!) {
          scores[path] =
              (scores[path] ?? 0) + 0.3; // Lowest weight for contains match
        }
      });
    }

    // Sort results by score (descending)
    final sortedResults = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return the paths, sorted by relevance
    return sortedResults.map((entry) => entry.key).toList();
  }
}

// AI assistant for file management
class FileAssistant {
  final FileIndex fileIndex;
  final FlutterTts flutterTts = FlutterTts();

  // Simple intent patterns for command recognition
  final Map<String, List<RegExp>> _intentPatterns = {
    'search': [
      RegExp(r'find\s+(.+)', caseSensitive: false),
      RegExp(r'search\s+(?:for\s+)?(.+)', caseSensitive: false),
      RegExp(r'look\s+for\s+(.+)', caseSensitive: false),
      RegExp(r'where\s+(?:is|are)\s+(?:my|the)?\s+(.+)', caseSensitive: false),
    ],
    'open': [
      RegExp(r'open\s+(?:the\s+)?(.+)', caseSensitive: false),
      RegExp(r'show\s+(?:me\s+)?(?:the\s+)?(.+)', caseSensitive: false),
      RegExp(r'display\s+(?:the\s+)?(.+)', caseSensitive: false),
    ],
    'convert_pdf_to_image': [
      RegExp(r'convert\s+(?:the\s+)?(.+\.pdf)\s+(?:to|into)\s+(?:an\s+)?image',
          caseSensitive: false),
      RegExp(r'change\s+(?:the\s+)?(.+\.pdf)\s+(?:to|into)\s+(?:an\s+)?image',
          caseSensitive: false),
      RegExp(
          r'transform\s+(?:the\s+)?(.+\.pdf)\s+(?:to|into)\s+(?:an\s+)?image',
          caseSensitive: false),
      RegExp(r'make\s+(?:an\s+)?image\s+(?:from|of)\s+(?:the\s+)?(.+\.pdf)',
          caseSensitive: false),
    ],
    'chat': [
      RegExp(r"let's\s+chat(.*)", caseSensitive: false),
      RegExp(r"talk\s+to\s+me(.*)", caseSensitive: false),
      RegExp(r"have\s+a\s+conversation(.*)", caseSensitive: false),
      RegExp(r"chat\s+with\s+me(.*)", caseSensitive: false),
    ],
  };

  FileAssistant({required this.fileIndex}) {
    _initTts();
  }

  void _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  // Process user queries and perform actions
  Future<ChatMessage> processQuery(String query) async {
    // First check for specific intents based on pattern matching
    final intentInfo = _detectIntent(query);

    if (intentInfo != null) {
      final intent = intentInfo['intent'];
      final param = intentInfo['param'];

      if (intent == 'search' && param != null) {
        return _handleSearchQuery(param);
      } else if (intent == 'open' && param != null) {
        return _handleOpenFile(param);
      } else if (intent == 'convert_pdf_to_image' && param != null) {
        return _handleConversion(param, 'pdf', 'image');
      } else if (intent == 'chat' && param != null) {
        return _handleChat(param);
      }
    }

    // Conversation patterns
    if (query.toLowerCase().contains('hello') ||
        query.toLowerCase().contains('hi') ||
        query.toLowerCase().contains('hey')) {
      return ChatMessage(
        text:
            "Hello! I'm your file assistant. I can help you find files, convert PDFs to images, or tell you about your files. What would you like help with today?",
        isUser: false,
        files: [],
      );
    }

    if (query.toLowerCase().contains('what can you do') ||
        query.toLowerCase().contains('help me') ||
        query.toLowerCase() == 'help') {
      return ChatMessage(
        text: "I can help you with several file-related tasks:\n\n"
            "• Find files (e.g., 'Find my documents', 'Where are my photos?')\n"
            "• Open files (e.g., 'Open my resume.pdf')\n"
            "• Convert PDFs to images (e.g., 'Convert invoice.pdf to image')\n"
            "• Show information about files in your storage\n\n"
            "What would you like to do?",
        isUser: false,
        files: [],
      );
    }

    if (query.toLowerCase().contains('thank')) {
      return ChatMessage(
        text:
            "You're welcome! Let me know if you need anything else with your files.",
        isUser: false,
        files: [],
      );
    }

    // General intent detection as fallback
    if (query.toLowerCase().contains('find') ||
        query.toLowerCase().contains('search') ||
        query.toLowerCase().contains('look for') ||
        query.toLowerCase().contains('where')) {
      return _handleSearchQuery(query);
    }

    if (query.toLowerCase().contains('convert') &&
        (query.toLowerCase().contains('pdf') ||
            query.toLowerCase().contains('.pdf')) &&
        (query.toLowerCase().contains('image') ||
            query.toLowerCase().contains('jpg') ||
            query.toLowerCase().contains('png'))) {
      return _handleConversion(query, 'pdf', 'image');
    }

    if (query.toLowerCase().contains('open') ||
        query.toLowerCase().contains('show me') ||
        query.toLowerCase().contains('display')) {
      return _handleOpenFile(query);
    }

    // Try semantic search to find files related to the query
    final results = fileIndex.semanticSearch(query);
    if (results.isNotEmpty) {
      final limitedResults = results.take(3).toList();
      final fileList = limitedResults.map((path) {
        return FileInfo(
          path: path,
          name: path.split('/').last,
          type: _getFileTypeFromPath(path),
        );
      }).toList();

      return ChatMessage(
        text:
            "I found these files that might be related to your question. Would you like me to help you with any of them?",
        isUser: false,
        files: fileList,
      );
    }

    // Default response
    return ChatMessage(
      text:
          "I'm not sure how to help with that specific request. You can ask me to find files, open them, or convert PDFs to images. Would you like me to show you what files you have?",
      isUser: false,
      files: [],
    );
  }

  Map<String, String>? _detectIntent(String query) {
    // Normalize the query
    query = query.trim().toLowerCase();

    // Check each intent pattern
    for (var intent in _intentPatterns.keys) {
      for (var pattern in _intentPatterns[intent]!) {
        final match = pattern.firstMatch(query);
        if (match != null && match.groupCount >= 1) {
          final param = match.group(1)?.trim();
          return {
            'intent': intent,
            'param': param ?? '',
          };
        }
      }
    }

    return null;
  }

  Future<ChatMessage> _handleSearchQuery(String query) async {
    // Extract search terms - remove common words
    final searchTerms = query
        .replaceAll('find', '')
        .replaceAll('search', '')
        .replaceAll('look for', '')
        .replaceAll('files', '')
        .replaceAll('documents', '')
        .trim();

    if (searchTerms.isEmpty) {
      return ChatMessage(
        text: "What would you like me to search for?",
        isUser: false,
        files: [],
      );
    }

    // Perform search
    final results = fileIndex.semanticSearch(searchTerms);

    if (results.isEmpty) {
      return ChatMessage(
        text: "I couldn't find any files matching '$searchTerms'.",
        isUser: false,
        files: [],
      );
    }

    // Limit to top 5 results for display
    final limitedResults = results.take(5).toList();

    final fileList = limitedResults.map((path) {
      return FileInfo(
        path: path,
        name: path.split('/').last,
        type: _getFileTypeFromPath(path),
      );
    }).toList();

    return ChatMessage(
      text: "Here are some files I found for '$searchTerms':",
      isUser: false,
      files: fileList,
    );
  }

  Future<ChatMessage> _handleConversion(
      String query, String fromType, String toType) async {
    // Extract the file to convert from the query if possible
    final List<String> searchTerms = [];

    // Common patterns for conversion requests
    final extractPatterns = [
      // Pattern: "convert my file.pdf to image"
      RegExp(r'convert\s+(?:my|the)?\s*([a-zA-Z0-9_\-\.]+\.pdf)'),
      // Pattern: "change file.pdf into images"
      RegExp(r'change\s+(?:my|the)?\s*([a-zA-Z0-9_\-\.]+\.pdf)'),
      // Pattern: "transform file.pdf to jpg"
      RegExp(r'transform\s+(?:my|the)?\s*([a-zA-Z0-9_\-\.]+\.pdf)'),
    ];

    String? extractedFileName;
    for (final pattern in extractPatterns) {
      final match = pattern.firstMatch(query);
      if (match != null && match.groupCount >= 1) {
        extractedFileName = match.group(1);
        break;
      }
    }

    if (extractedFileName != null) {
      // Search for this specific file
      final results = fileIndex.search(extractedFileName);
      if (results.isNotEmpty) {
        return ChatMessage(
          text:
              "I'll convert '$extractedFileName' from $fromType to $toType for you.",
          isUser: false,
          files: [
            FileInfo(
              path: results[0],
              name: extractedFileName,
              type: fromType,
            )
          ],
          action: "convert_${fromType}_to_${toType}",
        );
      }
    }

    // If no specific file was mentioned or found, search for files of that type
    final results =
        fileIndex.searchByExtension(fromType.replaceFirst("pdf", "pdf"));

    if (results.isEmpty) {
      return ChatMessage(
        text:
            "I couldn't find any $fromType files to convert. Please upload a $fromType file first.",
        isUser: false,
        files: [],
      );
    }

    // Show a list of files that can be converted
    final limitedResults = results.take(5).toList();
    final fileList = limitedResults.map((path) {
      return FileInfo(
        path: path,
        name: path.split('/').last,
        type: fromType,
      );
    }).toList();

    return ChatMessage(
      text:
          "I can convert these $fromType files to $toType. Please select one:",
      isUser: false,
      files: fileList,
      action: "select_for_conversion_${fromType}_to_${toType}",
    );
  }

  Future<ChatMessage> _handleOpenFile(String query) async {
    final searchTerms = query
        .replaceAll('open', '')
        .replaceAll('show me', '')
        .replaceAll('file', '')
        .replaceAll('the', '')
        .trim();

    if (searchTerms.isEmpty) {
      return ChatMessage(
        text: "Which file would you like to open?",
        isUser: false,
        files: [],
      );
    }

    // Search for the file
    final results = fileIndex.semanticSearch(searchTerms);

    if (results.isEmpty) {
      return ChatMessage(
        text: "I couldn't find any files matching '$searchTerms' to open.",
        isUser: false,
        files: [],
      );
    }

    // Get the best match
    final filePath = results[0];

    return ChatMessage(
      text: "I found this file. Would you like me to open it?",
      isUser: false,
      files: [
        FileInfo(
          path: filePath,
          name: filePath.split('/').last,
          type: _getFileTypeFromPath(filePath),
        )
      ],
      action: "open_file",
    );
  }

  String _getFileTypeFromPath(String path) {
    final ext = path.contains('.')
        ? path.substring(path.lastIndexOf('.') + 1).toLowerCase()
        : '';

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return 'image';
    if (['mp4', 'avi', 'mov', 'mkv'].contains(ext)) return 'video';
    if (['mp3', 'wav', 'aac', 'ogg'].contains(ext)) return 'audio';
    if (['pdf'].contains(ext)) return 'pdf';
    if (['doc', 'docx', 'txt'].contains(ext)) return 'document';
    if (['xls', 'xlsx', 'csv'].contains(ext)) return 'spreadsheet';

    return 'file';
  }

  // Read text from file
  Future<String> readTextFromFile(String path) async {
    try {
      // Read the first few KB of the file for preview
      final file = File(path);
      final bytes = await file.readAsBytes();

      if (['txt', 'md', 'csv'].any((ext) => path.toLowerCase().endsWith(ext))) {
        // Simple text files
        final fileSize = bytes.length;
        final maxSize = 1024 * 2; // 2KB max

        if (fileSize > maxSize) {
          return String.fromCharCodes(bytes.sublist(0, maxSize)) + "...";
        } else {
          return String.fromCharCodes(bytes);
        }
      }

      // For other file types, just show metadata
      final stat = await file.stat();
      final modified = DateFormat('MMM dd, yyyy').format(stat.modified);
      final size = _formatFileSize(stat.size);

      return "File: ${path.split('/').last}\nSize: $size\nModified: $modified";
    } catch (e) {
      return "Could not read file: $e";
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // Speak the response
  Future<void> speak(String text) async {
    await flutterTts.speak(text);
  }

  // Stop speaking
  Future<void> stop() async {
    await flutterTts.stop();
  }

  // Handle chat intent - redirects to the OfflineChatAssistant
  Future<ChatMessage> _handleChat(String query) async {
    return ChatMessage(
      text:
          "Let's chat! I'm not just a file assistant - I'm happy to talk about other things too. How's your day going?",
      isUser: false,
      files: [],
      action: "start_chat",
    );
  }
}

// New class for more human-like conversation
class OfflineChatAssistant {
  // Personal details to create a more human-like persona
  final String name = "Alex";
  final List<String> hobbies = ["photography", "hiking", "reading", "coding"];
  final Map<String, List<String>> knowledgeBase = {
    "interests": ["mobile apps", "AI", "technology", "productivity"],
    "facts": [
      "I'm always learning new things about files and organization",
      "I enjoy helping people find what they're looking for",
      "I believe good file organization saves time",
      "I prefer simplicity over complexity"
    ],
    "quotes": [
      "The art of filing is knowing where to find things when you need them.",
      "Digital organization is the key to digital peace of mind.",
      "A well-named file is half found."
    ]
  };

  // Tracks conversation context
  List<String> recentTopics = [];
  int messageCount = 0;
  bool personalModeActive = false;

  // Map for small talk responses
  final Map<String, List<String>> smallTalkResponses = {
    "greeting": [
      "Hey there! How's your day going?",
      "Hi! Nice to chat with you today.",
      "Hello! What can I help you with today?",
      "Hey! I'm here to assist with your files and have a chat."
    ],
    "how_are_you": [
      "I'm doing great, thanks for asking! How about you?",
      "Pretty good! Always happy to help organize files and chat. How are you?",
      "I'm good! Ready to help with whatever you need today.",
      "Doing well! I've been helping organize lots of files lately."
    ],
    "goodbye": [
      "Talk to you later! Let me know if you need help with your files.",
      "Goodbye! Feel free to chat anytime you need assistance.",
      "See you soon! I'll be here when you need help with your files.",
      "Bye for now! Come back anytime for file help or just to chat."
    ],
    "thanks": [
      "You're welcome! I'm happy I could help.",
      "Anytime! That's what I'm here for.",
      "No problem at all! Let me know if you need anything else.",
      "Glad I could be of assistance!"
    ],
    "weather": [
      "I don't have real-time weather data, but I hope it's nice where you are!",
      "I can't check the weather, but I can help organize your weather photos!",
      "I wish I could tell you the forecast, but I'm better with files than weather.",
      "While I can't see outside, I can help you find weather-related documents."
    ],
    "joke": [
      "Why don't scientists trust atoms? Because they make up everything!",
      "What did the file say to the folder? You're always keeping my stuff!",
      "Why was the computer cold? It left its Windows open!",
      "What do you call a factory that makes good products? A satisfactory!"
    ],
    "who_are_you": [
      "I'm Alex, your personal file assistant. I help you manage files and we can chat about other things too!",
      "I'm a digital assistant named Alex that specializes in file management, but I enjoy good conversation too.",
      "Think of me as your file-organizing friend Alex who's always ready to chat!",
      "I'm Alex, designed to help with your files but also happy to have a friendly conversation."
    ]
  };

  // Regex patterns for common conversation topics
  final Map<String, RegExp> _conversationPatterns = {
    "greeting":
        RegExp(r"\b(hi|hello|hey|greetings|howdy)\b", caseSensitive: false),
    "how_are_you": RegExp(
        r"\b(how are you|how's it going|how are things|what's up|how do you feel)\b",
        caseSensitive: false),
    "goodbye": RegExp(
        r"\b(bye|goodbye|see you|talk later|farewell|have to go)\b",
        caseSensitive: false),
    "thanks": RegExp(r"\b(thanks|thank you|appreciate|grateful)\b",
        caseSensitive: false),
    "weather": RegExp(r"\b(weather|temperature|forecast|rain|sunny|cold|hot)\b",
        caseSensitive: false),
    "joke": RegExp(r"\b(joke|funny|make me laugh|tell me something funny)\b",
        caseSensitive: false),
    "who_are_you": RegExp(
        r"\b(who are you|what are you|tell me about yourself|your name|who is this)\b",
        caseSensitive: false),
  };

  // Generate a personal response based on the user's query
  Future<ChatMessage> processChat(String query) async {
    messageCount++;

    // Check if we're already in personal mode or if the user wants to chat
    if (!personalModeActive) {
      for (var pattern in _conversationPatterns.entries) {
        if (pattern.value.hasMatch(query.toLowerCase())) {
          personalModeActive = true;
          break;
        }
      }
    }

    // If in personal chat mode, respond conversationally
    if (personalModeActive) {
      // Store the topic if it seems important
      if (query.length > 15 && !query.toLowerCase().contains("how are you")) {
        recentTopics.add(query);
        if (recentTopics.length > 3) {
          recentTopics.removeAt(0);
        }
      }

      // Check for specific conversation patterns
      for (var entry in _conversationPatterns.entries) {
        if (entry.value.hasMatch(query.toLowerCase())) {
          final responses = smallTalkResponses[entry.key] ?? [];
          if (responses.isNotEmpty) {
            final response = responses[messageCount % responses.length];
            return ChatMessage(
              text: response,
              isUser: false,
              files: [],
            );
          }
        }
      }

      // Check for questions about me
      if (query.toLowerCase().contains("you like") ||
          query.toLowerCase().contains("your hobby") ||
          query.toLowerCase().contains("you enjoy")) {
        return ChatMessage(
          text:
              "I enjoy ${hobbies[messageCount % hobbies.length]} when I'm not helping with files. What about you?",
          isUser: false,
          files: [],
        );
      }

      // Simple question detection
      if (query.toLowerCase().contains("?")) {
        final facts = knowledgeBase["facts"] ?? [];
        if (facts.isNotEmpty) {
          return ChatMessage(
            text:
                "That's an interesting question! ${facts[messageCount % facts.length]}. What else would you like to know?",
            isUser: false,
            files: [],
          );
        }
      }

      // Generic conversation continuers
      final continuers = [
        "Tell me more about that.",
        "That's interesting! What else is on your mind?",
        "I'd love to hear more about that. Or we can get back to your files if you prefer?",
        "I enjoy our conversations. Is there anything specific you'd like to talk about or need help with?",
        "Thanks for sharing that with me. Speaking of which, I found a quote you might like: ${knowledgeBase["quotes"]![messageCount % knowledgeBase["quotes"]!.length]}"
      ];

      return ChatMessage(
        text: continuers[messageCount % continuers.length],
        isUser: false,
        files: [],
      );
    }

    // If not in personal mode, return a message suggesting we can chat
    return ChatMessage(
      text:
          "It seems like you want to chat! I'm not just a file assistant - I'm happy to talk about other things too. How's your day going?",
      isUser: false,
      files: [],
    );
  }

  // Reset conversation state
  void resetConversation() {
    recentTopics.clear();
    messageCount = 0;
    personalModeActive = false;
  }
}

// Utility class for file conversions
class ConversionUtils {
  // Convert PDF to images
  static Future<List<String>> pdfToImages(String pdfPath) async {
    try {
      // Create a directory to store the converted images
      final directory = await getTemporaryDirectory();
      final outputDir = Directory('${directory.path}/pdf_to_image');

      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final outputPaths = <String>[];

      // Open the PDF document
      final pdfDocument = await PdfDocument.openFile(pdfPath);
      print('PDF opened: ${pdfDocument.pageCount} pages');

      // Convert each page to an image
      for (int i = 0; i < pdfDocument.pageCount; i++) {
        // Get the page
        final page = await pdfDocument.getPage(i + 1);

        // Calculate a good resolution (300 DPI)
        final scale = 2.0; // 2x for better quality
        final width = (page.width * scale).toInt();
        final height = (page.height * scale).toInt();

        // Render the page to an image
        final pageImage = await page.render(
          width: width,
          height: height,
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
        );

        // Get the image data - use pixels property to get RGBA data
        final imgData = pageImage.pixels;

        // Save the image
        final imagePath = '${outputDir.path}/page_${i + 1}.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(imgData);

        outputPaths.add(imagePath);
      }

      // Clean up
      pdfDocument.dispose();

      return outputPaths;
    } catch (e) {
      print('Error converting PDF to images: $e');
      return [];
    }
  }

  // Get a temporary directory for file processing
  static Future<Directory> getTemporaryDirectory() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      return directory ?? Directory.systemTemp;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    }
  }
}

// Model for chat messages
class ChatMessage {
  final String text;
  final bool isUser;
  final List<FileInfo> files;
  final String? action;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.files,
    this.action,
  });
}

// Model for file information
class FileInfo {
  final String path;
  final String name;
  final String type;

  FileInfo({
    required this.path,
    required this.name,
    required this.type,
  });
}

// Chat interface
class ChatScreen extends StatefulWidget {
  final FileIndex fileIndex;

  const ChatScreen({
    required this.fileIndex,
    Key? key,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController =
      ScrollController(); // Add this line
  final List<ChatMessage> _messages = [];
  late FileAssistant _assistant;
  late OfflineChatAssistant _chatAssistant;
  bool _isProcessing = false;
  bool _inChatMode = false;
  bool _ttsEnabled = true; // Add this line to track TTS state

  @override
  void initState() {
    super.initState();
    _assistant = FileAssistant(fileIndex: widget.fileIndex);
    _chatAssistant = OfflineChatAssistant();

    // Add welcome message with example commands
    _messages.add(ChatMessage(
      text:
          "Hi! I'm your file assistant. Here are some things you can ask me to do:\n\n"
          "• \"Find my PDF files\"\n"
          "• \"Convert document.pdf to image\"\n"
          "• \"Show me my photos\"\n"
          "• \"What's in my Downloads folder?\"\n\n"
          "You can also tap on any file to interact with it, or simply chat with me about anything! How can I help you today?",
      isUser: false,
      files: [],
    ));

    // Load chat history
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('chat_history');

      if (history != null && history.isNotEmpty) {
        // Only show prompt to continue previous chat if history exists
        _messages.add(ChatMessage(
          text: "Would you like to continue our previous chat?",
          isUser: false,
          files: [],
          action: "load_history",
        ));
      }
    } catch (e) {
      print("Error loading chat history: $e");
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save last 20 messages, user messages only
      final userMessages = _messages
          .where((msg) => msg.isUser)
          .take(20)
          .map((msg) => msg.text)
          .toList();

      prefs.setStringList('chat_history', userMessages);
    } catch (e) {
      print("Error saving chat history: $e");
    }
  }

  void _handleSubmitted(String text) async {
    if (text.isEmpty) return;

    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        files: [],
      ));
      _isProcessing = true;
    });

    // Scroll to bottom after adding user message
    _scrollToBottom();

    ChatMessage response;

    // Check if this is a conversation message or a file command
    if (_inChatMode) {
      // First try to detect if the user is asking for file assistance
      final intentInfo = _assistant._detectIntent(text);
      if (intentInfo != null && intentInfo['intent'] != 'chat') {
        // If user asks about files while in chat mode, switch back
        _inChatMode = false;
        response = await _assistant.processQuery(text);
      } else {
        // Otherwise continue the conversation
        response = await _chatAssistant.processChat(text);
      }
    } else {
      // Check if this is a chat request
      final intentInfo = _assistant._detectIntent(text);
      if (intentInfo != null && intentInfo['intent'] == 'chat') {
        _inChatMode = true;
        response = await _chatAssistant.processChat(text);
      } else if (_isPotentialChatMessage(text)) {
        response = await _chatAssistant.processChat(text);
        if (_chatAssistant.personalModeActive) {
          _inChatMode = true;
        }
      } else {
        // Process as file query
        response = await _assistant.processQuery(text);
      }
    }

    setState(() {
      _messages.add(response);
      _isProcessing = false;
    });

    // Scroll to bottom after adding response
    _scrollToBottom();

    // Speak the response if TTS is enabled
    if (_ttsEnabled && !response.isUser) {
      _assistant.speak(response.text);
    }

    // Save chat history
    _saveChatHistory();
  }

  bool _isPotentialChatMessage(String text) {
    final chatIndicators = [
      'hi',
      'hello',
      'hey',
      'how are you',
      'what\'s up',
      'good morning',
      'good afternoon',
      'good evening',
      'tell me',
      'talk',
      'chat',
      '?',
      '!'
    ];

    final normalizedText = text.toLowerCase();

    // Short messages are more likely to be conversation starters
    if (text.length < 15) {
      for (final indicator in chatIndicators) {
        if (normalizedText.contains(indicator)) {
          return true;
        }
      }
    }

    // Catch questions not related to files
    if (normalizedText.contains('?') &&
        !normalizedText.contains('file') &&
        !normalizedText.contains('pdf') &&
        !normalizedText.contains('find') &&
        !normalizedText.contains('show') &&
        !normalizedText.contains('search')) {
      return true;
    }

    return false;
  }

  void _handleFileAction(String? action, FileInfo file) async {
    if (action == null) return;

    if (action == "start_chat") {
      _inChatMode = true;
      setState(() {
        _messages.add(ChatMessage(
          text:
              "I'd love to chat! I'm Alex, by the way. What would you like to talk about?",
          isUser: false,
          files: [],
        ));
      });
      return;
    }

    if (action == "open_file") {
      try {
        // For simulated converted files, show a helpful message
        if (file.path.contains('/pdf_to_image/converted_') &&
            file.name.startsWith('converted_')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'PDF to image conversion is simulated. To enable real conversion, add the pdf_render plugin.'),
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }

        await OpenFile.open(file.path);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    } else if (action.startsWith("convert_")) {
      // Show a loading indicator
      setState(() {
        _isProcessing = true;
        _messages.add(ChatMessage(
          text: "Starting conversion...",
          isUser: false,
          files: [],
        ));
      });

      // Parse conversion type
      final conversionParts = action.split('_');
      if (conversionParts.length >= 4 &&
          conversionParts[1] == "pdf" &&
          conversionParts[3] == "image") {
        // PDF to image conversion
        try {
          final results = await ConversionUtils.pdfToImages(file.path);

          if (results.isNotEmpty) {
            final convertedFiles = results.map((path) {
              return FileInfo(
                path: path,
                name: path.split('/').last,
                type: 'image',
              );
            }).toList();

            setState(() {
              _isProcessing = false;
              _messages.add(ChatMessage(
                text: "I've converted the PDF to images. Here are the results:",
                isUser: false,
                files: convertedFiles,
                action: "open_file",
              ));
            });
          } else {
            setState(() {
              _isProcessing = false;
              _messages.add(ChatMessage(
                text:
                    "Sorry, I couldn't convert the PDF. The conversion process failed.",
                isUser: false,
                files: [],
              ));
            });
          }
        } catch (e) {
          setState(() {
            _isProcessing = false;
            _messages.add(ChatMessage(
              text: "An error occurred during conversion: $e",
              isUser: false,
              files: [],
            ));
          });
        }
      } else {
        // Other conversions - placeholder for future types
        setState(() {
          _isProcessing = false;
          _messages.add(ChatMessage(
            text:
                "This type of conversion is not supported yet, but will be coming soon!",
            isUser: false,
            files: [],
          ));
        });
      }
    } else if (action.startsWith("select_for_conversion_")) {
      // User selected a file for conversion from a list
      final parts = action.split('_');
      if (parts.length >= 5) {
        final fromType = parts[3];
        final toType = parts[5];

        // Trigger the appropriate conversion
        _handleFileAction("convert_${fromType}_to_${toType}", file);
      }
    } else if (action == "load_history") {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('chat_history');

      if (history != null && history.isNotEmpty) {
        final oldestQuery = history.last;
        _handleSubmitted(oldestQuery);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_inChatMode ? 'Chat with Alex' : 'Chat with Files AI'),
        actions: [
          // Add a TTS toggle button
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.volume_up : Icons.volume_off),
            tooltip: _ttsEnabled ? 'Disable voice' : 'Enable voice',
            onPressed: () {
              setState(() {
                _ttsEnabled = !_ttsEnabled;
                if (!_ttsEnabled) {
                  _assistant.stop(); // Stop any ongoing speech
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text(_ttsEnabled ? 'Voice enabled' : 'Voice disabled'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          // Existing mode toggle button
          IconButton(
            icon: Icon(_inChatMode ? Icons.folder : Icons.chat),
            tooltip: _inChatMode
                ? 'Switch to File Assistant'
                : 'Switch to Chat Mode',
            onPressed: () {
              setState(() {
                _inChatMode = !_inChatMode;
                if (_inChatMode) {
                  _messages.add(ChatMessage(
                    text:
                        "I'm now in chat mode! Feel free to talk about anything. If you need file help, just ask about files and I'll switch back.",
                    isUser: false,
                    files: [],
                  ));
                } else {
                  _messages.add(ChatMessage(
                    text:
                        "Back to file assistant mode. How can I help with your files?",
                    isUser: false,
                    files: [],
                  ));
                }
              });
            },
          ),
          // Existing delete button
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              setState(() {
                _messages.clear();
                _inChatMode = false;
                _chatAssistant.resetConversation();
                _messages.add(ChatMessage(
                  text: "Chat cleared. How can I help you?",
                  isUser: false,
                  files: [],
                ));
              });
              _saveChatHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // Add this line
              padding: EdgeInsets.all(8.0),
              reverse: false,
              itemCount: _messages.length,
              itemBuilder: (_, int index) {
                final message = _messages[index];
                return _buildMessageWidget(message);
              },
            ),
          ),
          if (_isProcessing)
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Processing...'),
                ],
              ),
            ),
          Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
            ),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageWidget(ChatMessage message) {
    final textWidget = message.isUser
        ? BubbleSpecialThree(
            text: message.text,
            color: Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF4B4B4B)
                : Color(0xFF1B97F3),
            tail: true,
            isSender: true,
            textStyle: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          )
        : BubbleSpecialThree(
            text: message.text,
            color: Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF303030)
                : Color(0xFFE8E8EE),
            tail: true,
            isSender: false,
            textStyle: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontSize: 16,
            ),
          );

    // If there are files attached, show them
    if (message.files.isNotEmpty) {
      return Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          textWidget,
          SizedBox(height: 8),
          ...message.files.map((file) => _buildFileCard(file, message.action)),
          SizedBox(height: 16),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: textWidget,
    );
  }

  Widget _buildFileCard(FileInfo file, String? action) {
    IconData icon = Icons.insert_drive_file;
    Color iconColor = Colors.blue;

    switch (file.type) {
      case 'image':
        icon = Icons.image;
        iconColor = Colors.purple;
        break;
      case 'video':
        icon = Icons.video_library;
        iconColor = Colors.red;
        break;
      case 'audio':
        icon = Icons.music_note;
        iconColor = Colors.orange;
        break;
      case 'pdf':
        icon = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'document':
        icon = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'spreadsheet':
        icon = Icons.table_chart;
        iconColor = Colors.green;
        break;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _handleFileAction(action, file),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 40),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      file.path,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new, size: 18),
                        SizedBox(width: 8),
                        Text('Open file'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'use_in_chat',
                    child: Row(
                      children: [
                        Icon(Icons.chat, size: 18),
                        SizedBox(width: 8),
                        Text('Use in chat'),
                      ],
                    ),
                  ),
                  if (file.type == 'pdf')
                    PopupMenuItem(
                      value: 'convert',
                      child: Row(
                        children: [
                          Icon(Icons.transform, size: 18),
                          SizedBox(width: 8),
                          Text('Convert to image'),
                        ],
                      ),
                    ),
                ],
                onSelected: (value) {
                  if (value == 'open') {
                    _handleFileAction('open_file', file);
                  } else if (value == 'use_in_chat') {
                    _controller.text = _suggestCommandForFile(file);
                  } else if (value == 'convert') {
                    _handleFileAction("convert_pdf_to_image", file);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _suggestCommandForFile(FileInfo file) {
    switch (file.type) {
      case 'pdf':
        return "Can you convert ${file.name} to an image?";
      case 'image':
        return "Tell me about this image ${file.name}";
      case 'document':
        return "What's in the document ${file.name}?";
      case 'video':
        return "Can you extract audio from ${file.name}?";
      case 'audio':
        return "Can you transcribe ${file.name}?";
      default:
        return "Tell me more about ${file.name}";
    }
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.primary),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(_inChatMode ? Icons.chat : Icons.mic),
              color: _inChatMode ? Colors.green : null,
              onPressed: () {
                if (_inChatMode) {
                  // Show a hint for chat mode
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Chat mode active! Try asking me about my hobbies or tell me about your day.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                } else {
                  // Voice input placeholder
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Voice input coming soon!')),
                  );
                }
              },
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: _inChatMode
                      ? "Chat with Alex..."
                      : "Ask me about your files...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: _inChatMode
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.green.withOpacity(0.2)
                          : Colors.green.withOpacity(0.1))
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200]),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onSubmitted: _handleSubmitted,
              ),
            ),
            IconButton(
              icon: Icon(Icons.send),
              color: _inChatMode ? Colors.green : null,
              onPressed: () => _handleSubmitted(_controller.text),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to scroll to the bottom of chat
  void _scrollToBottom() {
    // Use a small delay to ensure the UI has updated
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose(); // Add this line
    _assistant.stop();
    super.dispose();
  }
}
