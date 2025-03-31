import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FileIndex {
  // Map to store file paths indexed by filename
  final Map<String, List<String>> _fileNameIndex = {};
  // Map to store file paths indexed by file extension
  final Map<String, List<String>> _fileExtensionIndex = {};
  // Set to track indexed directories to avoid duplicates
  final Set<String> _indexedDirectories = {};

  // Path to the model files
  static const String VOCAB_PATH = 'assets/vocab.txt';
  static const String MODEL_PATH = 'assets/mobilebert_model.tflite';

  // Singleton instance
  static FileIndex? _instance;

  // Private constructor
  FileIndex._();

  // Factory constructor
  factory FileIndex() {
    _instance ??= FileIndex._();
    return _instance!;
  }

  // Initialize model files
  Future<void> initializeModel() async {
    try {
      // Get application documents directory
      final appDir = await getApplicationDocumentsDirectory();

      // Create models directory if it doesn't exist
      final modelsDir = Directory(path.join(appDir.path, 'models'));
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      // Copy vocab.txt from assets if needed
      final vocabFile = File(path.join(modelsDir.path, 'vocab.txt'));
      if (!await vocabFile.exists()) {
        final vocabData = await rootBundle.load(VOCAB_PATH);
        await vocabFile.writeAsBytes(vocabData.buffer.asUint8List());
      }

      // Copy tflite model from assets if needed
      final modelFile =
          File(path.join(modelsDir.path, 'mobilebert_model.tflite'));
      if (!await modelFile.exists()) {
        final modelData = await rootBundle.load(MODEL_PATH);
        await modelFile.writeAsBytes(modelData.buffer.asUint8List());
      }
    } catch (e) {
      print('Error initializing model files: $e');
      rethrow;
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

  // Semantic search using the model
  List<String> semanticSearch(String query) {
    // For now, return basic search results
    // TODO: Implement actual model-based semantic search
    return searchByName(query);
  }

  // Clear the index
  void clear() {
    _fileNameIndex.clear();
    _fileExtensionIndex.clear();
    _indexedDirectories.clear();
  }
}
