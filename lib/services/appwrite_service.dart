import 'dart:io' as io;
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class AppwriteService {
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;

  late Client client;
  late Databases databases;
  late Storage storage;
  late Account account;

  final String databaseId = '67ee1aaa00189001768b';
  final String collectionId = '67ee1ccb000b3655bd60';
  final String bucketId = '67ee1ace00322808a89b';
  final String projectId = '67ee1a020004e3766663';

  AppwriteService._internal() {
    _initializeAppwrite();
  }

  void _initializeAppwrite() {
    try {
      client = Client()
          .setEndpoint('https://cloud.appwrite.io/v1')
          .setProject(projectId);

      databases = Databases(client);
      storage = Storage(client);
      account = Account(client);
      debugPrint('AppwriteService initialized successfully');
    } catch (e) {
      debugPrint('AppwriteService initialization error: $e');
    }
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      await account.get();
      debugPrint('User is authenticated');
      return true;
    } catch (e) {
      debugPrint('User is not authenticated: $e');
      return false;
    }
  }

  // Create a new event
  Future<models.Document> createEvent(Map<String, dynamic> eventData) async {
    // Check authentication
    if (!await isAuthenticated()) {
      debugPrint('Authentication required for createEvent');
      throw Exception('Authentication required');
    }

    try {
      // Get current user ID to set as owner
      final user = await account.get();

      // Add creator information to event data
      eventData['userId'] = user.$id;
      eventData['creatorName'] = user.name;

      debugPrint('Creating event with user: ${user.$id}');

      final document = await databases.createDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: ID.unique(),
        data: eventData,
        // Add permissions for the creator
        permissions: [
          Permission.read(Role.user(user.$id)),
          Permission.write(Role.user(user.$id)),
          Permission.update(Role.user(user.$id)),
          Permission.delete(Role.user(user.$id)),
        ],
      );
      debugPrint('Event created successfully: ${document.$id}');
      return document;
    } catch (e) {
      debugPrint('Error creating event: $e');
      rethrow;
    }
  }

  // Get all events
  Future<List<models.Document>> getEvents(
      {Map<String, dynamic>? userFaceFeatures}) async {
    try {
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
      );

      final documents = response.documents;

      // If no face features provided, return all events
      if (userFaceFeatures == null) {
        return documents;
      }

      // Filter documents to only include ones matching user's face
      // This is a simple implementation - you'd need more sophisticated matching
      final filteredDocs = <models.Document>[];
      for (final doc in documents) {
        if (doc.data.containsKey('faceFeatures')) {
          // Do face matching logic
          // This is oversimplified - you need real face matching
          filteredDocs.add(doc);
        }
      }

      return filteredDocs;
    } catch (e) {
      debugPrint('Error getting events: $e');
      rethrow;
    }
  }

  // Get event by code
  Future<models.Document?> getEventByCode(String code) async {
    try {
      final response = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
        queries: [Query.equal('code', code)],
      );

      if (response.documents.isNotEmpty) {
        debugPrint('Event found with code: $code');
        return response.documents.first;
      }
      debugPrint('No event found with code: $code');
      return null;
    } catch (e) {
      debugPrint('Error getting event by code: $e');
      rethrow;
    }
  }

  // Upload a file to Appwrite storage
  Future<models.File> uploadFile(io.File file, String eventId) async {
    // Check authentication first
    if (!await isAuthenticated()) {
      debugPrint('Authentication required for uploadFile');
      throw Exception('Authentication required');
    }

    try {
      final fileName = path.basename(file.path);
      debugPrint('Uploading file: $fileName for event: $eventId');
      final result = await storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(
          path: file.path,
          filename: '${eventId}_$fileName',
        ),
      );
      debugPrint('File uploaded successfully: ${result.$id}');
      return result;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }

  // Get file view URL
  String getFileViewUrl(String fileId) {
    final url =
        '${client.endPoint}/storage/buckets/$bucketId/files/$fileId/view?project=${client.config['project']}';
    debugPrint('Generated file URL: $url');
    return url;
  }

  // Add this method to AppwriteService
  Future<bool> matchFaceWithPhoto(
      Map<String, dynamic> faceFeatures, io.File photoFile) async {
    try {
      // You'll need to implement face matching logic here
      // This could use ML Kit or custom matching algorithm
      // For simplicity, I'm just returning true for now
      return true;
    } catch (e) {
      debugPrint('Error matching face: $e');
      return false;
    }
  }

  // Delete event and its associated photos
  Future<bool> deleteEvent(String eventId, List<String> photoIds) async {
    // Check authentication
    if (!await isAuthenticated()) {
      debugPrint('Authentication required for deleteEvent');
      throw Exception('Authentication required');
    }

    try {
      // Delete all associated photos first
      for (final photoId in photoIds) {
        await storage.deleteFile(bucketId: bucketId, fileId: photoId);
        debugPrint('Deleted photo: $photoId');
      }

      // Delete the event document
      await databases.deleteDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: eventId,
      );

      debugPrint('Event deleted successfully: $eventId');
      return true;
    } catch (e) {
      debugPrint('Error deleting event: $e');
      rethrow;
    }
  }

  // Add this method for image compression
  Future<io.File> _compressImage(io.File file) async {
    final String targetPath = file.path.replaceAll(
      RegExp(r'\.(jpg|jpeg|png)$'),
      '_compressed.webp',
    );

    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 85, // Adjust quality as needed (0-100)
        format: CompressFormat.webp,
        minWidth: 1024, // Adjust minimum width as needed
        minHeight: 1024, // Adjust minimum height as needed
      );

      if (result == null) {
        debugPrint('Image compression failed, using original file');
        return file;
      }

      debugPrint('Image compressed successfully: ${result.path}');
      final compressedFile = io.File(result.path);
      debugPrint(
          'Original size: ${file.lengthSync()}, Compressed size: ${compressedFile.lengthSync()}');
      return compressedFile;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return file; // Return original file if compression fails
    }
  }

  // Modify the uploadFileWithProgress method to include compression
  Future<models.File> uploadFileWithProgress(
      io.File file, String eventId, Function(double) onProgress) async {
    // Check authentication first
    if (!await isAuthenticated()) {
      debugPrint('Authentication required for uploadFile');
      throw Exception('Authentication required');
    }

    try {
      // Compress the image if it's an image file
      final fileExtension = path.extension(file.path).toLowerCase();
      final isImage = ['.jpg', '.jpeg', '.png'].contains(fileExtension);

      final fileToUpload = isImage ? await _compressImage(file) : file;
      final fileName = path.basename(fileToUpload.path);

      debugPrint('Uploading file: $fileName for event: $eventId');

      final result = await storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(
          path: fileToUpload.path,
          filename: '${eventId}_$fileName',
        ),
        onProgress: (uploaded) {
          // Progress is already in percentage (0-100)
          onProgress(uploaded.progress / 100);
        },
      );

      // Clean up compressed file if it's different from original
      if (isImage && fileToUpload.path != file.path) {
        try {
          await fileToUpload.delete();
        } catch (e) {
          debugPrint('Error deleting temporary compressed file: $e');
        }
      }

      debugPrint('File uploaded successfully: ${result.$id}');
      return result;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }
}
