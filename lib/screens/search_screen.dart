import 'package:flutter/material.dart';
import 'dart:io';
import '../models/file_index.dart';
import 'package:open_file/open_file.dart';

class SearchScreen extends StatefulWidget {
  final FileIndex fileIndex;

  const SearchScreen({
    required this.fileIndex,
    super.key,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Use semantic search from FileIndex
    final results = widget.fileIndex.semanticSearch(query);

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  String _getFileIcon(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return '🖼️';
    if (['mp4', 'avi', 'mov', 'mkv'].contains(ext)) return '🎥';
    if (['mp3', 'wav', 'aac', 'ogg'].contains(ext)) return '🎵';
    if (['pdf'].contains(ext)) return '📄';
    if (['doc', 'docx', 'txt'].contains(ext)) return '📝';
    if (['xls', 'xlsx', 'csv'].contains(ext)) return '📊';
    if (['zip', 'rar', '7z'].contains(ext)) return '🗜️';
    
    return '📄';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search files...',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            border: InputBorder.none,
          ),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchController.text.isEmpty ? Icons.search : Icons.search_off,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Start typing to search files'
                            : 'No files found',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final filePath = _searchResults[index];
                    final fileName = filePath.split('/').last;
                    
                    return ListTile(
                      leading: Text(
                        _getFileIcon(fileName),
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(fileName),
                      subtitle: FutureBuilder<FileStat>(
                        future: FileStat.stat(filePath),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Text('Loading...');
                          final stat = snapshot.data!;
                          return Text(
                            '${_formatFileSize(stat.size)} • ${stat.modified.toString().split('.')[0]}',
                          );
                        },
                      ),
                      onTap: () => OpenFile.open(filePath),
                    );
                  },
                ),
    );
  }
}