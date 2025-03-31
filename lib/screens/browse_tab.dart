import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import '../screens/image_viewer_screen.dart';

class BrowseTab extends StatefulWidget {
  const BrowseTab({super.key});

  @override
  State<BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<BrowseTab> {
  String currentPath = '/storage/emulated/0';
  List<FileSystemEntity> files = [];
  bool _showHiddenFiles = false;
  bool _isLoading = true;
  List<String> _navigationHistory = [];

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  bool handleBackPress() {
    if (_navigationHistory.isNotEmpty) {
      setState(() {
        currentPath = _navigationHistory.removeLast();
        _loadFiles();
      });
      return true;
    }
    return false;
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dir = Directory(currentPath);
      final entities = await dir.list().toList();

      final filteredEntities = _showHiddenFiles
          ? entities
          : entities
              .where((e) => !path.basename(e.path).startsWith('.'))
              .toList();

      // Sort files (directories first, then alphabetically)
      filteredEntities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return path
            .basename(a.path)
            .toLowerCase()
            .compareTo(path.basename(b.path).toLowerCase());
      });

      setState(() {
        files = filteredEntities;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading files: $e');
      setState(() {
        files = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading files: $e')),
      );
    }
  }

  void _navigateToDirectory(String newPath) {
    if (currentPath != newPath) {
      _navigationHistory.add(currentPath);
      setState(() {
        currentPath = newPath;
        _loadFiles();
      });
    }
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
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showDeleteDialog(FileSystemEntity item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${path.basename(item.path)}?'),
        content: const Text('This item will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await item.delete(recursive: true);
                _loadFiles();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting item: $e')),
                );
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _showFileInfo(FileSystemEntity item) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<FileStat>(
        future: item.stat(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(
              title: Text('Loading...'),
              content: Center(child: CircularProgressIndicator()),
            );
          }

          final stat = snapshot.data!;
          final fileName = path.basename(item.path);
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
                  title: const Text('Path'),
                  subtitle: Text(item.path),
                ),
                ListTile(
                  title: const Text('Size'),
                  subtitle: Text(size),
                ),
                ListTile(
                  title: const Text('Modified'),
                  subtitle: Text(modified),
                ),
                ListTile(
                  title: const Text('Type'),
                  subtitle: Text(item is Directory ? 'Directory' : 'File'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
              ),
            ],
          );
        },
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[900]
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: currentPath == '/storage/emulated/0'
                      ? null
                      : () {
                          final parentDir = Directory(currentPath).parent;
                          _navigateToDirectory(parentDir.path);
                        },
                ),
                Expanded(
                  child: Text(
                    currentPath,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showHiddenFiles ? Icons.visibility : Icons.visibility_off,
                  ),
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
                ? const Center(child: CircularProgressIndicator())
                : files.isEmpty
                    ? _buildEmptyState()
                    : _buildFileList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
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

  Widget _buildFileList() {
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final fileName = path.basename(file.path);
        final isDirectory = file is Directory;
        final isImage = !isDirectory &&
            ['.jpg', '.jpeg', '.png', '.gif', '.webp']
                .any((ext) => fileName.toLowerCase().endsWith(ext));

        return ListTile(
          leading: isDirectory
              ? const Icon(Icons.folder, color: Colors.amber, size: 40)
              : isImage
                  ? SizedBox(
                      width: 40,
                      height: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(
                          File(file.path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(_getFileIcon(fileName),
                                color: Colors.blue);
                          },
                        ),
                      ),
                    )
                  : Icon(_getFileIcon(fileName), color: Colors.blue, size: 40),
          title: Text(fileName),
          subtitle: FutureBuilder<FileStat>(
            future: file.stat(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Text('Loading...');
              }

              final stat = snapshot.data!;
              final modified = DateFormat('MMM dd, yyyy').format(stat.modified);
              final size = isDirectory ? '' : _formatSize(stat.size);

              return Text('$modified${size.isNotEmpty ? ' • $size' : ''}');
            },
          ),
          onTap: () {
            if (isDirectory) {
              _navigateToDirectory(file.path);
            } else if (isImage) {
              _openImage(file.path);
            } else {
              _openFile(file.path);
            }
          },
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Text('Share'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
              const PopupMenuItem(
                value: 'info',
                child: Text('Info'),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteDialog(file);
              } else if (value == 'info') {
                _showFileInfo(file);
              }
            },
          ),
        );
      },
    );
  }
}
