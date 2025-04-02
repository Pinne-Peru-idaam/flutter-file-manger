import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:pdf_render/pdf_render.dart' as pdf_render;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_pdf;
import 'dart:math' as math;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FileIndex {
  // Map to store file paths indexed by filename
  final Map<String, List<String>> _fileNameIndex = {};
  // Map to store file paths indexed by file extension
  final Map<String, List<String>> _fileExtensionIndex = {};
  // Set to track indexed directories to avoid duplicates
  final Set<String> _indexedDirectories = {};
  // Map to store file content and terms for semantic search
  final Map<String, String> _fileContentCache = {};
  final Map<String, List<String>> _fileTermsCache = {};

  // Progress tracking
  int _totalFilesToIndex = 0;
  int _filesIndexed = 0;
  String _currentFileBeingIndexed = "";
  bool _isIndexing = false;

  // Progress callback
  Function(double progress, String currentFile)? onIndexingProgress;

  // Path to the model files
  static const String VOCAB_PATH = 'assets/vocab.txt';
  static const String MODEL_PATH = 'assets/mobilebert_model.tflite';

  // Model initialization flag
  bool _modelInitialized = false;

  // Singleton instance
  static FileIndex? _instance;

  // Private constructor
  FileIndex._();

  // Factory constructor
  factory FileIndex() {
    _instance ??= FileIndex._();
    return _instance!;
  }

  // Getters for progress tracking
  bool get isIndexing => _isIndexing;
  int get totalFilesToIndex => _totalFilesToIndex;
  int get filesIndexed => _filesIndexed;
  String get currentFileBeingIndexed => _currentFileBeingIndexed;
  double get indexingProgress =>
      _totalFilesToIndex > 0 ? _filesIndexed / _totalFilesToIndex : 0.0;

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

      _modelInitialized = true;
      print("Model files initialized successfully");
    } catch (e) {
      print('Error initializing model files: $e');
      _modelInitialized = false;
      rethrow;
    }
  }

  // Extract text from PDF file using Syncfusion
  Future<String> extractPdfText(String pdfPath) async {
    try {
      // Check if we already have the content cached
      if (_fileContentCache.containsKey(pdfPath)) {
        return _fileContentCache[pdfPath]!;
      }

      // Load the PDF document
      final File file = File(pdfPath);
      final bytes = await file.readAsBytes();
      final syncfusion_pdf.PdfDocument document =
          syncfusion_pdf.PdfDocument(inputBytes: bytes);

      final buffer = StringBuffer();

      // Extract text from all pages
      for (int i = 0; i < document.pages.count; i++) {
        // Extract text from the current page
        final syncfusion_pdf.PdfTextExtractor extractor =
            syncfusion_pdf.PdfTextExtractor(document);
        final String pageText =
            extractor.extractText(startPageIndex: i, endPageIndex: i);
        buffer.write(pageText);
        buffer.write(' ');
      }

      // Dispose the document
      document.dispose();

      final extractedText = buffer.toString();

      // Cache the content
      _fileContentCache[pdfPath] = extractedText;

      // Process and cache terms
      _fileTermsCache[pdfPath] = _processTextToTerms(extractedText);

      print(
          "Extracted ${_fileTermsCache[pdfPath]!.length} terms from PDF: ${pdfPath.split('/').last}");

      return extractedText;
    } catch (e) {
      print('Error extracting text from PDF: $e');
      // Fallback to metadata extraction if text extraction fails
      await extractPdfMetadata(pdfPath);
      return '';
    }
  }

  // Extract PDF metadata as a fallback
  Future<Map<String, dynamic>> extractPdfMetadata(String pdfPath) async {
    try {
      final pdfDocument = await pdf_render.PdfDocument.openFile(pdfPath);

      // Extract basic metadata
      final metadata = {
        'pageCount': pdfDocument.pageCount,
        'fileName': pdfPath.split('/').last,
        'filePath': pdfPath,
        'fileSize': await File(pdfPath).length(),
      };

      // Generate keywords from filename
      final fileName = pdfPath.split('/').last;
      final fileNameWithoutExt = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;

      // Convert filename to searchable terms
      final fileNameTerms = _processTextToTerms(fileNameWithoutExt);

      // If we don't have content cache for this file, use filename terms
      if (!_fileTermsCache.containsKey(pdfPath)) {
        _fileTermsCache[pdfPath] = fileNameTerms;
      }

      // Clean up
      pdfDocument.dispose();

      return metadata;
    } catch (e) {
      print('Error extracting PDF metadata: $e');
      return {
        'pageCount': 0,
        'fileName': pdfPath.split('/').last,
        'filePath': pdfPath,
        'fileSize': 0,
      };
    }
  }

  // Process text into searchable terms
  List<String> _processTextToTerms(String text) {
    // Convert to lowercase
    final lowerText = text.toLowerCase();

    // Remove special characters and replace with spaces
    final cleanText = lowerText.replaceAll(RegExp(r'[^\w\s]'), ' ');

    // Split by whitespace
    final words = cleanText.split(RegExp(r'\s+'));

    // Filter out very short words and common stop words
    final stopWords = {
      'the',
      'a',
      'an',
      'in',
      'on',
      'at',
      'to',
      'for',
      'with',
      'by',
      'of',
      'and',
      'or',
      'is',
      'are',
      'was',
      'were',
      'be',
      'been',
      'being',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'but',
      'if',
      'then',
      'else',
      'when',
      'where',
      'why',
      'how',
      'all',
      'any',
      'both',
      'each',
      'few',
      'more',
      'most',
      'some',
      'such',
      'no',
      'nor',
      'not',
      'only',
      'own',
      'same',
      'so',
      'than',
      'too',
      'very'
    };

    final filteredWords = words
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .toList();

    return filteredWords;
  }

  // Check if a directory has been indexed
  bool isDirectoryIndexed(String path) {
    return _indexedDirectories.contains(path);
  }

  // Add a file to the index
  Future<void> addFile(FileSystemEntity entity) async {
    if (entity is! File) return;

    final String path = entity.path;
    final String fileName = path.split('/').last.toLowerCase();
    final String fileNameWithoutExt = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final String extension = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.') + 1)
        : '';

    // Set current file being indexed for progress reporting
    _currentFileBeingIndexed = fileName;
    _filesIndexed++;

    // Report progress
    if (onIndexingProgress != null) {
      onIndexingProgress!(indexingProgress, fileName);
    }

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

    // Extract and cache content for PDF files for semantic search
    if (extension.toLowerCase() == 'pdf') {
      final text = await extractPdfText(path);
      if (text.isEmpty) {
        // If text extraction failed, fallback to filename-based terms
        _fileTermsCache[path] = _processTextToTerms(fileNameWithoutExt);
      }
    } else {
      // For non-PDF files, just index their filename terms
      _fileTermsCache[path] = _processTextToTerms(fileNameWithoutExt);
    }
  }

  // Add a file to the index by path
  Future<void> addFilePath(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await addFile(file);
    }
  }

  // Count files in a directory recursively
  Future<int> _countFilesInDirectory(String dirPath,
      {bool recursive = true}) async {
    int count = 0;
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return 0;

      final List<FileSystemEntity> entities = await dir.list().toList();

      for (var entity in entities) {
        if (entity is File) {
          count++;
        } else if (recursive && entity is Directory) {
          count += await _countFilesInDirectory(entity.path);
        }
      }
    } catch (e) {
      print('Error counting files in directory: $e');
    }
    return count;
  }

  // Index all files in a directory recursively
  Future<void> indexDirectory(String dirPath, {bool recursive = true}) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return;

      // If already indexed and not forcing re-index, skip
      if (_indexedDirectories.contains(dirPath)) {
        return;
      }

      // Start indexing - update status
      _isIndexing = true;

      // First count total files (for progress tracking)
      if (_totalFilesToIndex == 0) {
        _totalFilesToIndex =
            await _countFilesInDirectory(dirPath, recursive: recursive);
      }

      _indexedDirectories.add(dirPath);

      final List<FileSystemEntity> entities = await dir.list().toList();

      for (var entity in entities) {
        if (entity is File) {
          await addFile(entity);
        } else if (recursive && entity is Directory) {
          await indexDirectory(entity.path);
        }
      }

      // Finished indexing this directory
      if (_filesIndexed >= _totalFilesToIndex) {
        _isIndexing = false;
        // Save indexed data
        await saveIndexedData();
      }
    } catch (e) {
      print('Error indexing directory: $e');
      _isIndexing = false;
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

  // Calculate TF-IDF score for term frequency
  double _calculateTfIdfScore(
      List<String> queryTerms, List<String> docTerms, int totalDocs) {
    if (queryTerms.isEmpty || docTerms.isEmpty) return 0.0;

    double score = 0.0;

    // Count term frequency in document
    final docTermCounts = <String, int>{};
    for (final term in docTerms) {
      docTermCounts[term] = (docTermCounts[term] ?? 0) + 1;
    }

    // For each query term
    for (final queryTerm in queryTerms) {
      // Term frequency in document
      final tf = docTermCounts[queryTerm] ?? 0;
      if (tf == 0) continue;

      // Normalized term frequency
      final normalizedTf = tf / docTerms.length;

      // Count documents containing term
      int docsWithTerm = 0;
      _fileTermsCache.forEach((filePath, terms) {
        if (terms.contains(queryTerm)) docsWithTerm++;
      });

      // IDF calculation
      final idf = math.log(totalDocs / (docsWithTerm + 1));

      // Add to score
      score += normalizedTf * idf;
    }

    return score;
  }

  // Search for text within PDF files
  Future<List<String>> searchTextInPdf(
      String filePath, String searchText) async {
    try {
      final results = <String>[];

      // Load the PDF document
      final File file = File(filePath);
      final bytes = await file.readAsBytes();
      final syncfusion_pdf.PdfDocument document =
          syncfusion_pdf.PdfDocument(inputBytes: bytes);

      // Search for the text
      final syncfusion_pdf.PdfTextExtractor extractor =
          syncfusion_pdf.PdfTextExtractor(document);

      for (int i = 0; i < document.pages.count; i++) {
        final matches = extractor
            .findText([searchText], startPageIndex: i, endPageIndex: i);

        if (matches.isNotEmpty) {
          results.add(
              'Found "$searchText" in ${filePath.split('/').last} on page ${i + 1}');
        }
      }

      // Clean up
      document.dispose();

      return results;
    } catch (e) {
      print('Error searching text in PDF: $e');
      return [];
    }
  }

  // Semantic search using term frequency-inverse document frequency
  List<String> semanticSearch(String query) {
    // Process the query
    final queryTerms = _processTextToTerms(query);

    // If no meaningful terms, fall back to basic search
    if (queryTerms.isEmpty) {
      print('No meaningful search terms, falling back to name-based search');
      return searchByName(query);
    }

    // Calculate scores for each PDF in the cache
    final scores = <String, double>{};
    final totalDocuments = _fileTermsCache.length;

    _fileTermsCache.forEach((filePath, terms) {
      scores[filePath] =
          _calculateTfIdfScore(queryTerms, terms, totalDocuments);
    });

    // Sort by score (descending)
    final sortedPaths = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));

    // Filter by minimum threshold score
    final threshold = 0.01;
    sortedPaths.removeWhere((path) => scores[path]! < threshold);

    print('Semantic search found ${sortedPaths.length} results for "$query"');

    // If no semantic results or very few, supplement with name-based search
    if (sortedPaths.length < 3) {
      final nameResults = searchByName(query);
      // Add name results that aren't already in semantic results
      for (final path in nameResults) {
        if (!sortedPaths.contains(path)) {
          sortedPaths.add(path);
        }
      }
    }

    return sortedPaths;
  }

  // Get text content of a PDF file
  Future<String> getPdfContent(String pdfPath) async {
    if (_fileContentCache.containsKey(pdfPath)) {
      return _fileContentCache[pdfPath]!;
    }

    return await extractPdfText(pdfPath);
  }

  // Summarize PDF content
  Future<String> summarizePdfContent(String pdfPath) async {
    try {
      final content = await getPdfContent(pdfPath);
      if (content.isEmpty) {
        return "Could not extract text from this PDF.";
      }

      // Get significant terms by frequency
      final terms = _processTextToTerms(content);
      final termCounts = <String, int>{};

      for (final term in terms) {
        termCounts[term] = (termCounts[term] ?? 0) + 1;
      }

      // Sort terms by frequency
      final sortedTerms = termCounts.keys.toList()
        ..sort((a, b) => termCounts[b]!.compareTo(termCounts[a]!));

      // Take top 10 most frequent terms
      final topTerms = sortedTerms.take(10).toList();

      // Extract sentences containing top terms (simple summary)
      final sentences = content.split(RegExp(r'[.!?]+\s'));
      final relevantSentences = <String>[];

      for (final sentence in sentences) {
        for (final term in topTerms) {
          if (sentence.toLowerCase().contains(term) &&
              sentence.length > 20 &&
              sentence.length < 200 &&
              !relevantSentences.contains(sentence)) {
            relevantSentences.add(sentence);
            break;
          }
        }

        if (relevantSentences.length >= 3) break;
      }

      // Format summary
      final summary = StringBuffer();
      summary.writeln("📄 PDF Summary: ${pdfPath.split('/').last}");
      summary.writeln();
      summary.writeln("Key topics: ${topTerms.take(5).join(', ')}");
      summary.writeln();

      if (relevantSentences.isNotEmpty) {
        summary.writeln("Key points:");
        for (final sentence in relevantSentences) {
          summary.writeln("• ${sentence.trim()}.");
        }
      } else {
        summary.writeln("Could not generate summary points.");
      }

      return summary.toString();
    } catch (e) {
      print('Error summarizing PDF: $e');
      return "Error generating summary for this PDF.";
    }
  }

  // Save indexed data to local storage
  Future<void> saveIndexedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create a serializable version of file terms cache (most important data)
      final Map<String, dynamic> serializedCache = {};
      _fileTermsCache.forEach((path, terms) {
        serializedCache[path] = terms;
      });

      // Store indexed directories
      await prefs.setStringList(
          'indexed_directories', _indexedDirectories.toList());

      // Store file terms cache in chunks (could be large)
      final String serialized = jsonEncode(serializedCache);

      // If data is too large, split into chunks (SharedPreferences has size limits)
      const int maxChunkSize = 500000; // ~500KB per chunk
      if (serialized.length > maxChunkSize) {
        // Clear any existing chunks
        final keys = prefs.getKeys();
        for (final key in keys) {
          if (key.startsWith('file_terms_chunk_')) {
            await prefs.remove(key);
          }
        }

        // Save number of chunks
        final int numChunks = (serialized.length / maxChunkSize).ceil();
        await prefs.setInt('file_terms_chunks_count', numChunks);

        // Save each chunk
        for (int i = 0; i < numChunks; i++) {
          final int start = i * maxChunkSize;
          final int end = math.min((i + 1) * maxChunkSize, serialized.length);
          final String chunk = serialized.substring(start, end);
          await prefs.setString('file_terms_chunk_$i', chunk);
        }
      } else {
        // Small enough to save as a single chunk
        await prefs.setInt('file_terms_chunks_count', 1);
        await prefs.setString('file_terms_chunk_0', serialized);
      }

      // Save timestamp of last indexing
      await prefs.setInt(
          'last_indexing_timestamp', DateTime.now().millisecondsSinceEpoch);

      print('Indexed data saved to local storage');
    } catch (e) {
      print('Error saving indexed data: $e');
    }
  }

  // Load indexed data from local storage
  Future<bool> loadIndexedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we have saved data
      if (!prefs.containsKey('indexed_directories') ||
          !prefs.containsKey('file_terms_chunks_count')) {
        return false;
      }

      // Load indexed directories
      final List<String>? dirs = prefs.getStringList('indexed_directories');
      if (dirs != null) {
        _indexedDirectories.addAll(dirs);
      }

      // Load file terms cache from chunks
      final int numChunks = prefs.getInt('file_terms_chunks_count') ?? 0;
      if (numChunks > 0) {
        final StringBuffer serialized = StringBuffer();
        for (int i = 0; i < numChunks; i++) {
          final String? chunk = prefs.getString('file_terms_chunk_$i');
          if (chunk != null) {
            serialized.write(chunk);
          }
        }

        final Map<String, dynamic> serializedCache =
            jsonDecode(serialized.toString()) as Map<String, dynamic>;

        // Restore file terms cache
        serializedCache.forEach((key, value) {
          _fileTermsCache[key] = List<String>.from(value as List);
        });

        // Reconstruct filename and extension indexes
        for (final filePath in _fileTermsCache.keys) {
          final fileName = filePath.split('/').last.toLowerCase();
          final fileNameWithoutExt = fileName.contains('.')
              ? fileName.substring(0, fileName.lastIndexOf('.'))
              : fileName;
          final extension = fileName.contains('.')
              ? fileName.substring(fileName.lastIndexOf('.') + 1)
              : '';

          // Add to filename index
          if (!_fileNameIndex.containsKey(fileNameWithoutExt)) {
            _fileNameIndex[fileNameWithoutExt] = [];
          }
          _fileNameIndex[fileNameWithoutExt]!.add(filePath);

          // Add to extension index
          if (extension.isNotEmpty) {
            if (!_fileExtensionIndex.containsKey(extension)) {
              _fileExtensionIndex[extension] = [];
            }
            _fileExtensionIndex[extension]!.add(filePath);
          }
        }

        print('Loaded indexed data: ${_fileTermsCache.length} files');
        return true;
      }

      return false;
    } catch (e) {
      print('Error loading indexed data: $e');
      return false;
    }
  }

  // Check if index is still valid (files exist)
  Future<bool> validateIndex() async {
    int invalidFiles = 0;
    final List<String> toRemove = [];

    for (final filePath in _fileTermsCache.keys) {
      if (!await File(filePath).exists()) {
        toRemove.add(filePath);
        invalidFiles++;
      }
    }

    // Remove invalid files from cache
    for (final path in toRemove) {
      _fileTermsCache.remove(path);

      // Also remove from other indexes
      _fileNameIndex.forEach((key, value) {
        value.remove(path);
      });

      _fileExtensionIndex.forEach((key, value) {
        value.remove(path);
      });
    }

    // If more than 30% of files are invalid, consider cache invalid
    return invalidFiles < _fileTermsCache.length * 0.3;
  }

  // Reset indexing progress
  void resetIndexingProgress() {
    _totalFilesToIndex = 0;
    _filesIndexed = 0;
    _isIndexing = false;
    _currentFileBeingIndexed = "";
  }

  // Clear the index
  void clear() {
    _fileNameIndex.clear();
    _fileExtensionIndex.clear();
    _indexedDirectories.clear();
    _fileContentCache.clear();
    _fileTermsCache.clear();
    resetIndexingProgress();
  }
}
