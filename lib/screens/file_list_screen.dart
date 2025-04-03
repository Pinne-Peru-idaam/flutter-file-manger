import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

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

        if (mounted) {
          setState(() {
            _files = entities;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _files = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _files = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $e')),
        );
      }
    }
  }

  void _navigateToDirectory(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FileListScreen(
          title: path.split('/').last,
          directoryPath: path,
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    String lowercaseName = fileName.toLowerCase();
    if (lowercaseName.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    } else if (['.jpg', '.jpeg', '.png', '.gif', '.webp']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.image;
    } else if (['.mp3', '.wav', '.aac', '.ogg']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.music_note;
    } else if (['.mp4', '.avi', '.mov', '.mkv']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.video_library;
    } else if (['.doc', '.docx', '.txt', '.pdf']
        .any((ext) => lowercaseName.endsWith(ext))) {
      return Icons.description;
    }
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              // Implement sorting functionality
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? const Center(child: Text('No files found'))
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
                            return const Text('Loading...');
                          }

                          final stat = snapshot.data!;
                          final modified = DateFormat('MMM dd, yyyy')
                              .format(stat.modified);
                          final size =
                              isDirectory ? '' : _formatFileSize(stat.size);

                          return Text(
                              '$modified${size.isNotEmpty ? ' • $size' : ''}');
                        },
                      ),
                      onTap: () {
                        if (isDirectory) {
                          _navigateToDirectory(file.path);
                        } else {
                          OpenFile.open(file.path);
                        }
                      },
                    );
                  },
                ),
    );
  }
}
