import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class OfflineAIService {
  static const String VOCAB_PATH = 'assets/vocab.txt';
  static const String MODEL_PATH = 'assets/mobilebert_model.tflite';

  bool _modelInitialized = false;
  late List<String> _vocabList;

  // Singleton instance
  static OfflineAIService? _instance;

  // Factory constructor
  factory OfflineAIService() {
    _instance ??= OfflineAIService._();
    return _instance!;
  }

  // Private constructor
  OfflineAIService._();

  // Check if internet connection is available
  Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // Initialize the model
  Future<bool> initModel() async {
    if (_modelInitialized) return true;

    try {
      // Load vocabulary
      final String vocabData = await rootBundle.loadString(VOCAB_PATH);
      _vocabList = vocabData.split('\n');

      // Check if model exists
      final modelBytes = await rootBundle.load(MODEL_PATH);
      debugPrint(
          'MobileBERT model loaded, size: ${modelBytes.lengthInBytes} bytes');

      _modelInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing MobileBERT: $e');
      return false;
    }
  }

  // Process text using MobileBERT (uses method channel to communicate with native code)
  Future<String> _processText(String text, String task) async {
    if (!_modelInitialized) {
      final initialized = await initModel();
      if (!initialized) {
        return "Offline AI processing failed: Model not initialized";
      }
    }

    try {
      // This would be a method channel call to native code that runs the model
      // For now, we'll simulate basic functionality based on task

      if (task == "summarize") {
        return _generateOfflineSummary(text);
      } else if (task == "generate") {
        return _generateOfflineResponse(text);
      } else {
        return "Unsupported task: $task";
      }
    } catch (e) {
      debugPrint('Error processing text with MobileBERT: $e');
      return "An error occurred during offline processing";
    }
  }

  // Simulate document summarization offline
  String _generateOfflineSummary(String text) {
    // Simple extractive summarization approach
    // In reality, MobileBERT would do this via native code

    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.length <= 3) return text; // If text is already short

    // Extract first sentence as title
    final title = sentences[0].trim();

    // Create section heading
    final summary = StringBuffer("# Summary of Document\n\n");

    // Add introduction (first sentence)
    summary.write("## Introduction\n\n");
    summary.write("${sentences[0]}\n\n");

    // Add main points (sample sentences from the text)
    summary.write("## Main Points\n\n");

    // Select key sentences (1/4 of the text, at most 5 sentences)
    final sentenceCount = sentences.length;
    final keySentenceCount = (sentenceCount / 4).ceil().clamp(1, 5);
    final step = sentenceCount / keySentenceCount;

    for (int i = 0; i < keySentenceCount; i++) {
      final idx = (i * step).round();
      if (idx < sentenceCount && sentences[idx].length > 20) {
        // Only meaningful sentences
        summary.write("- ${sentences[idx]}\n");
      }
    }

    // Add conclusion (last sentence if it's not a question)
    if (!sentences.last.contains('?') && sentences.last.length > 15) {
      summary.write("\n## Conclusion\n\n");
      summary.write("${sentences.last}");
    }

    return summary.toString();
  }

  // Generate responses offline
  String _generateOfflineResponse(String query) {
    // In reality, MobileBERT would process this via native code
    // For now, we'll provide basic responses based on keywords

    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('hello') ||
        lowerQuery.contains('hi') ||
        lowerQuery.contains('hey')) {
      return "Hello! I'm currently operating in offline mode, but I'll do my best to help you.";
    }

    if (lowerQuery.contains('help')) {
      return "# How I Can Help You Offline\n\n"
          "I can assist with these tasks while offline:\n\n"
          "- Summarize documents\n"
          "- Answer basic questions\n"
          "- Provide file management tips\n"
          "- Search for files by name\n\n"
          "For more advanced tasks, please connect to the internet.";
    }

    if (lowerQuery.contains('create') && lowerQuery.contains('pdf')) {
      return "# Offline PDF Creation\n\n"
          "I can help you create a simple PDF with basic content while offline. However, for more advanced PDF creation with detailed formatting and content generation, an internet connection is required.\n\n"
          "## What I can do offline:\n"
          "- Create a basic document structure\n"
          "- Include text you provide\n"
          "- Add simple formatting\n\n"
          "Would you like to proceed with creating a basic PDF?";
    }

    // Default response
    return "I'm currently operating in offline mode with limited capabilities. I can help with basic file management, document summarization, and simple questions. For more advanced assistance, please connect to the internet.";
  }

  // Public methods

  // Summarize a document offline
  Future<String> summarizeOffline(String text) async {
    return _processText(text, "summarize");
  }

  // Generate chat response offline
  Future<String> generateResponse(String query) async {
    return _processText(query, "generate");
  }
}
