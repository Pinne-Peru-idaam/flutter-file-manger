import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:intl/intl.dart';
import '../models/file_index.dart';
import '../utils/conversion_utils.dart';
import '../controllers/speech_controller.dart';
import '../controllers/scroll_controller.dart';
import '../services/file_service.dart';
import '../services/groq_service.dart';
import '../services/offline_ai_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_pdf;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

// File info class
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

// Chat message class
class ChatMessage {
  final String text;
  final bool isUser;
  final List<FileInfo> files;
  final String?
      action; // Can be: "open_file", "convert_pdf_to_image", "create_pdf"
  final Map<String, dynamic>? pdfData; // For storing PDF creation details

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.files,
    this.action,
    this.pdfData,
  });
}

// File Assistant class
class FileAssistant {
  final FileIndex fileIndex;
  final FlutterTts flutterTts = FlutterTts();
  final GroqChatService _groqChatService;

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

  FileAssistant(
      {required this.fileIndex, required GroqChatService groqChatService})
      : _groqChatService = groqChatService {
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
      final results = fileIndex.semanticSearch(extractedFileName);
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
          return "${String.fromCharCodes(bytes.sublist(0, maxSize))}...";
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
    try {
      String response = await _groqChatService.sendMessage(query);
      return ChatMessage(
        text: response,
        isUser: false,
        files: [],
      );
    } catch (e) {
      return ChatMessage(
        text:
            "I apologize, but I encountered an error processing your request. Please try again.",
        isUser: false,
        files: [],
      );
    }
  }

  // Inside FileAssistant class
  Future<void> checkPythonDependencies() async {
    try {
      // Check if Python is installed
      final pythonVersion = await Process.run('python3', ['--version']);
      if (pythonVersion.exitCode != 0) {
        throw Exception('Python 3 is not installed');
      }

      // Check if pip is installed
      final pipVersion = await Process.run('pip3', ['--version']);
      if (pipVersion.exitCode != 0) {
        throw Exception('pip is not installed');
      }

      // Install required Python packages
      final directory = await getApplicationDocumentsDirectory();
      final requirementsPath = path.join(directory.path, 'requirements.txt');

      // Create requirements.txt
      final requirementsFile = File(requirementsPath);
      await requirementsFile.writeAsString('''
tensorflow
Pillow
numpy
transformers
''');

      // Install requirements
      final installResult = await Process.run(
        'pip3',
        ['install', '-r', requirementsPath],
      );

      if (installResult.exitCode != 0) {
        throw Exception(
            'Failed to install Python dependencies: ${installResult.stderr}');
      }
    } catch (e) {
      throw Exception('Failed to check/install Python dependencies: $e');
    }
  }

  // Summarize document content
  Future<ChatMessage> summarizeDocument(FileInfo file) async {
    try {
      String content = "";
      bool isPdf = file.path.toLowerCase().endsWith('.pdf');
      bool isText = [
        'txt',
        'md',
        'csv',
        'json',
        'html',
        'xml',
        'js',
        'css',
        'dart'
      ].any((ext) => file.path.toLowerCase().endsWith('.$ext'));

      // Extract content based on file type
      if (isPdf) {
        // Use the FileIndex's PDF extractor for PDFs
        content = await _extractPdfContent(file.path);
      } else if (isText) {
        // Read text content for text files
        final fileContent = await File(file.path).readAsString();
        content = fileContent.length > 3000
            ? fileContent.substring(0, 3000) + "..."
            : fileContent;
      } else {
        // For non-summarizable files, just return file info
        return ChatMessage(
          text:
              "This file type cannot be summarized. Would you like me to open it instead?",
          isUser: false,
          files: [file],
          action: "open_file",
        );
      }

      // If no content could be extracted, return a default message
      if (content.isEmpty) {
        return ChatMessage(
          text:
              "I couldn't extract any text from this file. Would you like me to open it for you?",
          isUser: false,
          files: [file],
          action: "open_file",
        );
      }

      String summary;
      bool isOfflineMode = false;

      try {
        // First try using Groq for online summary
        isOfflineMode = !(await _groqChatService.isOnline());

        if (isOfflineMode) {
          // Import OfflineAIService directly for offline summarization
          final offlineAIService = OfflineAIService();
          debugPrint('Using offline summarization for ${file.name}');
          summary = await offlineAIService.summarizeOffline(content);
        } else {
          // Use online summarization with markdown formatting
          String prompt = """
Summarize the following document content in markdown format using:
1. A top-level heading for the document title
2. Second-level headings for main sections
3. Bullet points for key points
4. Code blocks for any code or technical content
5. Bold or italic for emphasis

Make the summary clear, concise, and well-structured. Focus on the main ideas and key information.

Content to summarize: $content
""";
          summary = await _groqChatService.sendMessage(prompt);
        }
      } catch (e) {
        debugPrint(
            'Error in online summarization, falling back to offline: $e');
        // Fallback to offline summarization on any error
        try {
          final offlineAIService = OfflineAIService();
          summary = await offlineAIService.summarizeOffline(content);
          isOfflineMode = true;
        } catch (offlineError) {
          // If even offline summarization fails, return error
          return ChatMessage(
            text:
                "I encountered an error trying to summarize this document: $offlineError",
            isUser: false,
            files: [file],
            action: "open_file",
          );
        }
      }

      // Ensure summary starts with a heading if it doesn't already
      if (!summary.trimLeft().startsWith('#')) {
        summary = "# Summary of ${file.name}\n\n$summary";
      }

      return ChatMessage(
        text: "$summary\n\n*Would you like to open the full document?*",
        isUser: false,
        files: [file],
        action: "open_file",
      );
    } catch (e) {
      return ChatMessage(
        text: "I encountered an error trying to summarize this document: $e",
        isUser: false,
        files: [file],
        action: "open_file",
      );
    }
  }

  // Extract content from PDF
  Future<String> _extractPdfContent(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final document = syncfusion_pdf.PdfDocument(inputBytes: bytes);
      final extractor = syncfusion_pdf.PdfTextExtractor(document);

      // Extract text from first few pages (limit to prevent oversized requests)
      StringBuffer content = StringBuffer();
      int pagesToExtract = document.pages.count > 5 ? 5 : document.pages.count;

      for (int i = 0; i < pagesToExtract; i++) {
        content
            .write(extractor.extractText(startPageIndex: i, endPageIndex: i));
        content.write("\n\n");

        // Limit content size to 3000 characters
        if (content.length > 3000) {
          content.write("...(content truncated)");
          break;
        }
      }

      document.dispose();
      return content.toString();
    } catch (e) {
      return "";
    }
  }
}

// Offline Chat Assistant class
class OfflineChatAssistant {
  final GroqChatService _groqChatService;
  final String name = "FileNexus";
  final List<String> hobbies = ["photography", "hiking", "reading", "coding"];
  final Map<String, List<String>> knowledgeBase = {
    "interests": [
      "file management",
      "organization",
      "technology",
      "productivity"
    ],
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
      "I'm UCSS, your personal file assistant. I help you manage files and we can chat about other things too!",
      "I'm a digital assistant named UCSS that specializes in file management, but I enjoy good conversation too.",
      "Think of me as your file-organizing friend UCSS who's always ready to chat!",
      "I'm UCSS, designed to help with your files but also happy to have a friendly conversation."
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

  OfflineChatAssistant({required GroqChatService groqChatService})
      : _groqChatService = groqChatService;

  // Track PDF creation state
  bool _isCreatingPdf = false;
  Map<String, dynamic> _pdfCreationState = {
    'subject': '',
    'pages': 0,
    'sections': <String>[],
    'audience': '',
  };

  Future<ChatMessage> processChat(String query) async {
    messageCount++;

    // Continue PDF creation if in progress
    if (_isCreatingPdf) {
      if (_pdfCreationState['subject'].isEmpty) {
        _pdfCreationState['subject'] = query;
        return ChatMessage(
          text:
              "How many pages would you like the PDF to be? This will help me structure the content appropriately.",
          isUser: false,
          files: [],
        );
      }

      if (_pdfCreationState['pages'] == 0) {
        // Extract number from query (e.g., "make it 5 pages" -> 5)
        RegExp regExp = RegExp(r'\d+');
        Match? match = regExp.firstMatch(query);
        if (match != null) {
          _pdfCreationState['pages'] = int.parse(match.group(0)!);
          return ChatMessage(
            text: "What sections would you like to include? For example:\n"
                "• Introduction\n"
                "• Main concepts\n"
                "• Examples\n"
                "• Practice exercises\n"
                "• References",
            isUser: false,
            files: [],
          );
        } else {
          return ChatMessage(
            text:
                "Please specify the number of pages you'd like (e.g., '5 pages').",
            isUser: false,
            files: [],
          );
        }
      }

      if (_pdfCreationState['sections'].isEmpty) {
        _pdfCreationState['sections'] =
            query.split(',').map((s) => s.trim()).toList();
        return ChatMessage(
          text:
              "Who is the target audience for this PDF? This will help me adjust the content's complexity and tone.",
          isUser: false,
          files: [],
        );
      }

      if (_pdfCreationState['audience'].isEmpty) {
        _pdfCreationState['audience'] = query;

        // Generate content with all collected information
        try {
          String response = await _groqChatService.sendMessage(
              "Create a ${_pdfCreationState['pages']}-page PDF about ${_pdfCreationState['subject']} "
              "for ${_pdfCreationState['audience']}. Include these sections: ${_pdfCreationState['sections'].join(', ')}.\n"
              "Please generate a detailed content outline following this structure:\n"
              "1. Title\n"
              "2. Introduction\n"
              "3. Main sections (with subsections)\n"
              "4. Examples and illustrations\n"
              "5. Summary or conclusion");

          // Reset PDF creation state
          _isCreatingPdf = false;
          _pdfCreationState = {
            'subject': '',
            'pages': 0,
            'sections': <String>[],
            'audience': '',
          };

          return ChatMessage(
            text:
                "I've prepared the content for your PDF. Here's what I've created:\n\n$response\n\n"
                "Would you like me to create the PDF with this content? You can also request changes if needed.",
            isUser: false,
            files: [],
            action: "create_pdf",
          );
        } catch (e) {
          _isCreatingPdf = false;
          return ChatMessage(
            text:
                "I apologize, but I encountered an error while generating the PDF content. Please try again.",
            isUser: false,
            files: [],
          );
        }
      }
    }

    // Check for new PDF creation request
    if (query.toLowerCase().contains('create a pdf') ||
        query.toLowerCase().contains('make a pdf') ||
        query.toLowerCase().contains('generate a pdf')) {
      _isCreatingPdf = true;
      return ChatMessage(
        text:
            "I'll help you create a PDF! What subject or topic would you like it to be about?",
        isUser: false,
        files: [],
      );
    }

    // Continue with regular chat processing...
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
          String response = await _groqChatService.sendMessage(query);
          return ChatMessage(
            text: response,
            isUser: false,
            files: [],
          );
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
    _isCreatingPdf = false;
    _pdfCreationState = {
      'subject': '',
      'pages': 0,
      'sections': <String>[],
      'audience': '',
    };
  }
}

class ChatScreen extends StatefulWidget {
  final FileIndex fileIndex;
  final String apiKey;
  final bool initialChatMode;

  const ChatScreen({
    required this.fileIndex,
    required this.apiKey,
    this.initialChatMode = false,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final CustomScrollController _scrollController = CustomScrollController();
  final SpeechController _speechController = SpeechController();
  final List<ChatMessage> _messages = [];
  late final FileAssistant _assistant;
  late final OfflineChatAssistant _chatAssistant;
  late final GroqChatService _groqChatService;
  bool _isProcessing = false;
  bool _inChatMode = false;
  bool _ttsEnabled = true;
  String _recognizedText = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _groqChatService = GroqChatService(widget.apiKey);
    _groqChatService.startChat();
    _assistant = FileAssistant(
      fileIndex: widget.fileIndex,
      groqChatService: _groqChatService,
    );
    _chatAssistant = OfflineChatAssistant(groqChatService: _groqChatService);
    _initializeControllers();
    _inChatMode = widget.initialChatMode;
    _addWelcomeMessage();
    _loadChatHistory();
    _initializeFileIndex();
  }

  void _initializeControllers() async {
    await _speechController.initializeTts();
    await _speechController.initializeStt();
  }

  void _addWelcomeMessage() {
    _messages.add(ChatMessage(
      text: _inChatMode
          ? "👋 Welcome to Chat Mode!\n\n"
            "I'm your AI assistant ready to help create custom content and PDFs. Here are some examples:\n\n"
            "📚 What I can do:\n"
            "• Create detailed PDF guides and documentation\n"
            "• Generate study materials and tutorials\n"
            "• Help with technical writing and content creation\n"
            "• Answer questions and have engaging discussions\n\n"
            "💡 Try asking:\n"
            "\"Create a PDF about modern web development best practices\"\n"
            "\"Generate a comprehensive study guide for machine learning\"\n"
            "\"Help me write technical documentation for my API\"\n\n"
            "What would you like to create today?"
          : "👋 Welcome to File Assistant Mode!\n\n"
            "I'm here to help you manage and work with your files. Here's what I can do:\n\n"
            "📁 File Management:\n"
            "• Find files by name, type, or content\n"
            "• Convert PDFs to images\n"
            "• Open and preview files\n"
            "• Organize your documents\n\n"
            "💡 Try asking:\n"
            "\"Find my recent PDF files\"\n"
            "\"Convert presentation.pdf to images\"\n"
            "\"Show me photos from last week\"\n"
            "\"What's in my Downloads folder?\"\n\n"
            "How can I help with your files today?",
      isUser: false,
      files: [],
    ));
  }

  void _handleSubmitted(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        files: [],
      ));
      _isProcessing = true;
    });

    try {
      final response = _inChatMode
          ? await _chatAssistant.processChat(text)
          : await _assistant.processQuery(text);

      setState(() {
        _messages.add(response);

        // If the response contains a PDF creation request
        if (response.action == "create_pdf") {
          _showPdfConfirmationDialog(response.text);
        }

        if (_ttsEnabled && !response.isUser) {
          _speechController.speak(response.text);
        }
      });
    } catch (e, stackTrace) {
      debugPrint('Error processing chat: $e\n$stackTrace');
      setState(() {
        _messages.add(ChatMessage(
          text:
              "I apologize, but I encountered an error. Please check your internet connection and try again.",
          isUser: false,
          files: [],
        ));
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }

    _controller.clear();
    _scrollController.scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar with gradient border
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: _toggleMode,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Listening...' : 'Ask anything...',
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                    color: _isListening 
                        ? Colors.red 
                        : Theme.of(context).colorScheme.onSurface,
                    onPressed: _toggleListening,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () => _handleSubmitted(_controller.text),
                  ),
                ],
              ),
            ),

            // Messages list with modern styling
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController.controller,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageWidget(message);
                      },
                    ),
            ),

            // Loading indicator
            if (_isProcessing)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Thinking...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Ask anything about your files',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search, convert, or chat about your documents',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageWidget(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // User/Assistant label
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.isUser ? Icons.person : Icons.assistant,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  message.isUser ? 'You' : 'Assistant',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          
          // Message content
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: message.isUser
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  message.text,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // Sources section for assistant messages
          if (!message.isUser && message.files.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sources',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: message.files.map((file) => _buildSourceChip(file)).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceChip(FileInfo file) {
    IconData icon;
    switch (file.type) {
      case 'image':
        icon = Icons.image;
        break;
      case 'pdf':
        icon = Icons.picture_as_pdf;
        break;
      case 'document':
        icon = Icons.description;
        break;
      default:
        icon = Icons.insert_drive_file;
    }

    return InkWell(
      onTap: () => _openFile(file.path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              file.name,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileAction(String? action, FileInfo file) async {
    if (action == null) return;

    if (action == "open_file") {
      await _openFile(file.path);
    } else if (action.startsWith("convert_")) {
      await _handleConversion(file);
    }
  }

  Future<void> _openFile(String path) async {
    try {
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  Future<void> _handleConversion(FileInfo file) async {
    try {
      setState(() {
        _isProcessing = true;
      });

      final results = await ConversionUtils.pdfToImages(file.path);

      if (results.isNotEmpty) {
        setState(() {
          _messages.add(ChatMessage(
            text: "I've converted the PDF to images. Here are the results:",
            isUser: false,
            files: results
                .map((path) => FileInfo(
                      path: path,
                      name: path.split('/').last,
                      type: 'image',
                    ))
                .toList(),
          ));
        });
      } else {
        setState(() {
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
        _messages.add(ChatMessage(
          text: "An error occurred during conversion: $e",
          isUser: false,
          files: [],
        ));
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
      _scrollController.scrollToBottom();
    }
  }

  void _toggleTts() {
    setState(() {
      _ttsEnabled = !_ttsEnabled;
      if (!_ttsEnabled) {
        _speechController.stop();
      }
    });
  }

  void _toggleMode() {
    setState(() {
      _inChatMode = !_inChatMode;
      _messages.add(ChatMessage(
        text: _inChatMode
            ? "🤖 Switched to Chat Mode\n\n"
              "Now you can:\n"
              "• Create professional PDFs with custom content\n"
              "• Generate comprehensive study materials\n"
              "• Get help with technical writing\n"
              "• Have in-depth discussions on any topic\n\n"
              "What would you like to create or discuss?"
            : "📁 Switched to File Assistant Mode\n\n"
              "Now you can:\n"
              "• Search through your files and documents\n"
              "• Convert and transform file formats\n"
              "• Get quick access to your files\n"
              "• Organize your digital workspace\n\n"
              "What files can I help you with?",
        isUser: false,
        files: [],
      ));
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _addWelcomeMessage();
      _inChatMode = false;
      _chatAssistant.resetConversation();
    });
  }

  void _toggleListening() async {
    if (_speechController.speech.isNotListening) {
      final available = await _speechController.initializeStt();
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
        return;
      }

      setState(() {
        _isListening = true;
        _recognizedText = '';
      });

      _speechController.speech.listen(
        onResult: (result) {
          setState(() {
            _recognizedText = result.recognizedWords;
            _controller.text = _recognizedText;
            if (result.finalResult) {
              _isListening = false;
              _handleSubmitted(_recognizedText);
            }
          });
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
        localeId: 'en_US',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listening...')),
      );
    } else {
      _speechController.speech.stop();
      setState(() {
        _isListening = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _speechController.cancel();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('chat_history');

      if (history != null && history.isNotEmpty) {
        setState(() {
          _messages.add(ChatMessage(
            text: "Would you like to continue our previous chat?",
            isUser: false,
            files: [],
            action: "load_history",
          ));
        });
      }
    } catch (e) {
      debugPrint("Error loading chat history: $e");
    }
  }

  Future<void> _initializeFileIndex() async {
    try {
      final basePath = await FileService.getBasePath();
      final hasPermission = await FileService.requestPermissions();

      if (hasPermission) {
        // Index common directories
        await widget.fileIndex.indexDirectory('$basePath/Download');
        await widget.fileIndex.indexDirectory('$basePath/Documents');
        await widget.fileIndex.indexDirectory('$basePath/Pictures');
        await widget.fileIndex.indexDirectory('$basePath/DCIM');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Storage permission is required to access files')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error initializing file index: $e');
    }
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

  void _showPdfConfirmationDialog(String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create PDF'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Generated Content Preview:'),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(content),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _messages.add(ChatMessage(
                  text: "What changes would you like to make to the content?",
                  isUser: false,
                  files: [],
                ));
              },
              child: Text('Request Changes'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _createPdf(content);
              },
              child: Text('Create PDF'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createPdf(String content) async {
    try {
      setState(() {
        _isProcessing = true;
      });

      // Generate a title based on the content's first line or use a default
      String title = 'Generated_Document';
      if (content.contains('\n')) {
        String firstLine = content.split('\n').first.trim();
        if (firstLine.isNotEmpty) {
          // Clean up the title and limit its length
          title = firstLine
              .replaceAll(RegExp(r'[^\w\s-]'), '') // Remove special characters
              .trim()
              .replaceAll(
                  RegExp(r'\s+'), '_'); // Replace spaces with underscore

          if (title.length > 50) {
            title = title.substring(0, 50); // Limit title length
          }
        }
      }

      final filePath = await _groqChatService.createPdf(
        content,
        title,
      );

      // Index the new file if it was saved in an indexed location
      await widget.fileIndex.addFilePath(filePath);

      setState(() {
        _messages.add(ChatMessage(
          text:
              "PDF created successfully and saved to Downloads! You can find it at: $filePath",
          isUser: false,
          files: [
            FileInfo(
              path: filePath,
              name: filePath.split('/').last,
              type: 'pdf',
            )
          ],
          action: "open_file", // Allow direct opening
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Failed to create PDF: $e",
          isUser: false,
          files: [],
        ));
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
      _scrollController.scrollToBottom();
    }
  }
}
