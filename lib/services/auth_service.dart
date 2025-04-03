import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  late Client client;
  late Account account;
  bool _initialized = false;

  // Project ID from Appwrite console
  final String projectId = '67ee1a020004e3766663';

  AuthService._internal() {
    _initializeAppwrite();
  }

  void _initializeAppwrite() {
    if (_initialized) return;

    try {
      client = Client()
          .setEndpoint('https://cloud.appwrite.io/v1')
          .setProject(projectId);

      account = Account(client);
      _initialized = true;
      debugPrint('Appwrite initialized successfully');
    } catch (e) {
      debugPrint('Appwrite initialization error: $e');
      _initialized = false;
    }
  }

  // Sign up a new user
  Future<User> createAccount(String email, String password, String name) async {
    if (!_initialized) _initializeAppwrite();

    try {
      debugPrint('Creating account for: $email');
      final user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
      debugPrint('Account created successfully');
      return user;
    } catch (e) {
      debugPrint('Account creation error: $e');
      rethrow;
    }
  }

  // Sign in existing user
  Future<Session> createSession(String email, String password) async {
    if (!_initialized) _initializeAppwrite();

    try {
      debugPrint('Creating session for: $email');
      final session = await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      debugPrint('Session created successfully');
      return session;
    } catch (e) {
      debugPrint('Session creation error: $e');
      rethrow;
    }
  }

  // Get current user
  Future<User> getCurrentUser() async {
    if (!_initialized) _initializeAppwrite();

    try {
      final user = await account.get();
      debugPrint('Current user: ${user.name}');
      return user;
    } catch (e) {
      debugPrint('Get current user error: $e');
      rethrow;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    if (!_initialized) _initializeAppwrite();

    try {
      await getCurrentUser();
      return true;
    } catch (e) {
      debugPrint('User not logged in: $e');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (!_initialized) _initializeAppwrite();

    try {
      await account.deleteSession(sessionId: 'current');
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  // Add this method to AuthService
  Future<void> saveFaceFeatures(
      String userId, Map<String, dynamic> faceFeatures) async {
    if (!_initialized) _initializeAppwrite();

    try {
      debugPrint('Saving face features for user: $userId');
      await account.updatePrefs(prefs: {
        'faceFeatures': faceFeatures,
      });
      debugPrint('Face features saved successfully');
    } catch (e) {
      debugPrint('Error saving face features: $e');
      rethrow;
    }
  }

  // Add method to get face features
  Future<Map<String, dynamic>?> getFaceFeatures() async {
    if (!_initialized) _initializeAppwrite();

    try {
      final prefs = await account.getPrefs();
      return prefs.data['faceFeatures'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting face features: $e');
      return null;
    }
  }
}
