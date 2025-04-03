import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import '../services/appwrite_service.dart';
import '../services/auth_service.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  final ImagePicker _picker = ImagePicker();
  io.File? _selectedImage;
  List<Face>? _detectedFaces;
  Map<String, dynamic>? _faceFeatures;
  bool _processingImage = false;
  List<Map<String, dynamic>> _savedFaces = [];
  List<Map<String, dynamic>> _events = [];

  TextEditingController _nameController = TextEditingController();
  TextEditingController _eventNameController = TextEditingController();
  TextEditingController _eventCodeController = TextEditingController();
  TextEditingController _eventPasswordController = TextEditingController();

  final AppwriteService _appwriteService = AppwriteService();

  @override
  void initState() {
    super.initState();
    _loadSavedFaces();
    _loadEvents();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _nameController.dispose();
    _eventNameController.dispose();
    _eventCodeController.dispose();
    _eventPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedFaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final facesJson = prefs.getString('saved_faces');
      if (facesJson != null) {
        final List<dynamic> decodedFaces = jsonDecode(facesJson);
        setState(() {
          _savedFaces = decodedFaces.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Error loading saved faces: $e');
    }
  }

  Future<void> _loadEvents() async {
    try {
      final documents = await _appwriteService.getEvents();
      setState(() {
        _events = documents
            .map((doc) => {
                  'id': doc.$id,
                  'name': doc.data['name'],
                  'code': doc.data['code'],
                  'password': doc.data['password'],
                  'created_at': doc.data['created_at'],
                  'photos': doc.data['photos'] != null
                      ? jsonDecode(doc.data['photos'])
                      : [],
                })
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
    }
  }

  Future<void> _saveFace() async {
    if (_faceFeatures == null) return;

    try {
      if (_nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a name')),
        );
        return;
      }

      // Save the reference face
      final String faceId = DateTime.now().millisecondsSinceEpoch.toString();
      final faceData = {
        'id': faceId,
        'name': _nameController.text,
        'features': _faceFeatures,
        'created_at': DateTime.now().toIso8601String(),
      };

      setState(() {
        _savedFaces.add(faceData);
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_faces', jsonEncode(_savedFaces));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face saved for ${_nameController.text}')),
      );

      _nameController.clear();
      setState(() {
        _selectedImage = null;
        _detectedFaces = null;
        _faceFeatures = null;
      });
    } catch (e) {
      debugPrint('Error saving face: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving face: $e')),
      );
    }
  }

  Future<void> _createEvent() async {
    if (_eventNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event name')),
      );
      return;
    }

    try {
      // Check authentication
      if (!await _appwriteService.isAuthenticated()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to create events')),
        );
        Navigator.pushNamed(context, '/signin');
        return;
      }

      // Generate random event code
      final random = Random();
      final eventCode = List.generate(6, (_) => random.nextInt(10)).join();

      final eventData = {
        'name': _eventNameController.text,
        'code': eventCode,
        'password': _eventPasswordController.text,
        'created_at': DateTime.now().toIso8601String(),
        'photos': jsonEncode([]),
      };

      final document = await _appwriteService.createEvent(eventData);

      setState(() {
        _events.add({
          'id': document.$id,
          'name': _eventNameController.text,
          'code': eventCode,
          'password': _eventPasswordController.text,
          'created_at': DateTime.now().toIso8601String(),
          'photos': jsonEncode([]),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event created! Event code: $eventCode')),
      );

      _eventNameController.clear();
      _eventPasswordController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating event: $e')),
      );
    }
  }

  Future<void> _joinEvent() async {
    if (_eventCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event code')),
      );
      return;
    }

    try {
      final eventDoc =
          await _appwriteService.getEventByCode(_eventCodeController.text);

      if (eventDoc == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event not found')),
        );
        return;
      }

      final event = {
        'id': eventDoc.$id,
        'name': eventDoc.data['name'],
        'code': eventDoc.data['code'],
        'password': eventDoc.data['password'],
        'created_at': eventDoc.data['created_at'],
        'photoData': []
      };

      // Decode the photoData JSON string
      if (eventDoc.data['photoData'] != null) {
        try {
          debugPrint('Decoding photoData: ${eventDoc.data['photoData']}');
          final photoDataJson = eventDoc.data['photoData'];
          final List<dynamic> decodedPhotoData = jsonDecode(photoDataJson);
          event['photoData'] = decodedPhotoData;
          debugPrint(
              'Successfully decoded photoData: ${decodedPhotoData.length} photos');
        } catch (e) {
          debugPrint('Error decoding photoData: $e');
          // Keep empty array as fallback
        }
      }

      if (event['password'] != _eventPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect password')),
        );
        return;
      }

      // Save joined event to local storage
      final prefs = await SharedPreferences.getInstance();
      final joinedEvents = prefs.getStringList('joined_events') ?? [];
      final eventDetails = {
        'id': event['id'],
        'name': event['name'],
        'code': event['code'],
        'password': event['password'],
      };
      joinedEvents.add(jsonEncode(eventDetails));
      await prefs.setStringList('joined_events', joinedEvents);

      // Load user's face features
      final authService = AuthService();
      final userFaceData = await authService.getFaceFeatures();

      debugPrint(
          'User face features loaded: ${userFaceData != null ? 'Yes' : 'No'}');

      // Filter photos based on face matching
      final matchingPhotos = <Map<String, dynamic>>[];
      int totalPhotos = 0;
      int matchedPhotos = 0;

      if (userFaceData != null && (event['photoData'] as List).isNotEmpty) {
        totalPhotos = event['photoData'].length;
        debugPrint('Total photos in event: $totalPhotos');

        for (final photoData in event['photoData']) {
          bool hasMatch = false;

          // Skip if no faces in this photo
          if (photoData is! Map || photoData['faces'] == null) {
            debugPrint('Skipping photo - no face data');
            continue;
          }

          // For each photo, check if any face matches the user's face
          for (var i = 0; i < photoData['faces'].length; i++) {
            try {
              // Get face feature and safely convert to Map<String, dynamic>
              final dynamic rawFeature = photoData['faces'][i];
              if (rawFeature is! Map) {
                debugPrint('Face feature is not a map, skipping');
                continue;
              }

              // Create a properly typed map
              final Map<String, dynamic> faceFeature = {};
              rawFeature.forEach((key, value) {
                if (key is String) {
                  faceFeature[key] = value;
                }
              });

              // Calculate match score
              final matchScore =
                  _calculateFaceMatchScore(userFaceData, faceFeature);
              debugPrint('Face match score: $matchScore');

              if (matchScore > 0.7) {
                // Arbitrary threshold for matching
                hasMatch = true;
                matchedPhotos++;
                debugPrint('Match found! Score: $matchScore');
                break;
              }
            } catch (e) {
              debugPrint('Error processing face: $e');
            }
          }

          if (hasMatch) {
            // Convert to Map<String, dynamic> before adding
            final Map<String, dynamic> typedPhotoData = {};
            photoData.forEach((key, value) {
              if (key is String) {
                typedPhotoData[key] = value;
              }
            });
            matchingPhotos.add(typedPhotoData);
          }
        }

        // Update the event to only include matching photos
        event['filteredPhotoData'] = matchingPhotos;
        debugPrint(
            'Filtered photos: ${matchingPhotos.length} out of $totalPhotos');
      } else {
        debugPrint('No user face features or no photos in event');
      }

      // Show event photos (filtered if face recognition is enabled)
      _showEventPhotos(event);

      _eventCodeController.clear();
      _eventPasswordController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining event: $e')),
      );
    }
  }

  // Helper method to calculate match score between two face features
  double _calculateFaceMatchScore(
      Map<String, dynamic> face1, Map<String, dynamic> face2) {
    try {
      // Access with null safety
      double angleXDiff = ((face1['headEulerAngleX'] ?? 0.0) -
              (face2['headEulerAngleX'] ?? 0.0))
          .abs();
      double angleYDiff = ((face1['headEulerAngleY'] ?? 0.0) -
              (face2['headEulerAngleY'] ?? 0.0))
          .abs();
      double angleZDiff = ((face1['headEulerAngleZ'] ?? 0.0) -
              (face2['headEulerAngleZ'] ?? 0.0))
          .abs();

      // Normalize differences
      double totalDiff = (angleXDiff + angleYDiff + angleZDiff) / 180.0;

      // Convert to a similarity score
      return 1.0 - totalDiff;
    } catch (e) {
      debugPrint('Error calculating face match: $e');
      return 0.0; // No match on error
    }
  }

  void _showEventPhotos(Map<String, dynamic> event) {
    // Determine which photos to display - filtered or all
    final List<dynamic> photosList = event.containsKey('filteredPhotoData')
        ? event['filteredPhotoData']
        : event['photoData'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Event: ${event['name']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (event.containsKey('filteredPhotoData'))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Showing ${photosList.length} photos matching your face',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.blue,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (photosList.isEmpty)
                const Center(
                  child: Text('No photos available for this event'),
                )
              else
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: photosList.length,
                    itemBuilder: (context, index) {
                      final photoData = photosList[index];
                      String imageUrl;

                      // Handle different formats
                      if (photoData is String) {
                        // Direct fileId as string (old format)
                        imageUrl = _appwriteService.getFileViewUrl(photoData);
                      } else if (photoData is Map) {
                        // New format with url field
                        imageUrl = photoData['url'] ??
                            _appwriteService
                                .getFileViewUrl(photoData['fileId']);
                      } else {
                        // Fallback
                        imageUrl =
                            'https://via.placeholder.com/150?text=Invalid+Image';
                      }

                      return GestureDetector(
                        onTap: () {
                          // Show full-screen image
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                appBar: AppBar(
                                  title: Text('Photo ${index + 1}'),
                                ),
                                body: Center(
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint('Image error: $error');
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image,
                                            color: Colors.white),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('Image error: $error');
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image,
                                        color: Colors.white),
                                  );
                                },
                              ),
                            ),
                            // Show face count - make sure we handle different formats
                            if (photoData is Map && photoData['faces'] != null)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.face,
                                          color: Colors.white, size: 14),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${photoData['faces'].length}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadPhotosToEvent(Map<String, dynamic> event) async {
    final result = await _picker.pickMultiImage();
    if (result.isEmpty) return;

    try {
      final uploadedPhotoData = <String>[];
      int processedImages = 0;
      int totalImages = result.length;

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Processing Images'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                        value: processedImages / totalImages),
                    const SizedBox(height: 16),
                    Text('$processedImages of $totalImages processed'),
                  ],
                ),
              );
            },
          );
        },
      );

      for (final image in result) {
        final file = io.File(image.path);

        // 1. Upload file to Appwrite
        final uploadedFile =
            await _appwriteService.uploadFile(file, event['id']);

        // 2. Analyze image for faces
        final inputImage = InputImage.fromFilePath(file.path);
        final faces = await _faceDetector.processImage(inputImage);

        // 3. Extract face features for each detected face
        final faceFeatures = <Map<String, dynamic>>[];

        for (final face in faces) {
          final features = {
            'boundingBox': {
              'left': face.boundingBox.left,
              'top': face.boundingBox.top,
              'right': face.boundingBox.right,
              'bottom': face.boundingBox.bottom,
            },
            'headEulerAngleX': face.headEulerAngleX,
            'headEulerAngleY': face.headEulerAngleY,
            'headEulerAngleZ': face.headEulerAngleZ,
          };
          faceFeatures.add(features);
        }

        // 4. Create photo data object
        final photoData = {
          'fileId': uploadedFile.$id,
          'url': _appwriteService.getFileViewUrl(uploadedFile.$id),
          'uploadedAt': DateTime.now().toIso8601String(),
          'faces': faceFeatures,
        };

        final photoDataString = jsonEncode(photoData);

        // Debug info about the size of the data
        debugPrint('Photo data JSON length: ${photoDataString.length} chars');
        if (photoDataString.length > 1000) {
          debugPrint(
              'WARNING: Photo data exceeds 1000 char limit: ${photoDataString.length}');
          // Trim face features if needed
          if (faceFeatures.length > 3) {
            final trimmedFeatures = faceFeatures.sublist(0, 3);
            final trimmedData = {
              'fileId': uploadedFile.$id,
              'url': _appwriteService.getFileViewUrl(uploadedFile.$id),
              'uploadedAt': DateTime.now().toIso8601String(),
              'faces': trimmedFeatures,
              'note': 'Face data trimmed due to size limitations',
            };
            final trimmedString = jsonEncode(trimmedData);
            debugPrint('Trimmed data length: ${trimmedString.length} chars');
            uploadedPhotoData.add(trimmedString);
          } else {
            // Try without detailed face contours
            final simplifiedFeatures = faceFeatures.map((face) {
              return {
                'boundingBox': face['boundingBox'],
                'headEulerAngleX': face['headEulerAngleX'],
                'headEulerAngleY': face['headEulerAngleY'],
                'headEulerAngleZ': face['headEulerAngleZ'],
              };
            }).toList();

            final simplifiedData = {
              'fileId': uploadedFile.$id,
              'url': _appwriteService.getFileViewUrl(uploadedFile.$id),
              'uploadedAt': DateTime.now().toIso8601String(),
              'faces': simplifiedFeatures,
            };

            final simplifiedString = jsonEncode(simplifiedData);
            debugPrint(
                'Simplified data length: ${simplifiedString.length} chars');
            uploadedPhotoData.add(simplifiedString);
          }
        } else {
          uploadedPhotoData.add(photoDataString);
        }

        // Update progress
        processedImages++;
        // We can't update the dialog state directly, so we'll just close and reopen it
      }

      Navigator.pop(context); // Close progress dialog

      // Update event document with new photo data
      final eventDoc = await _appwriteService.getEventByCode(event['code']);
      if (eventDoc != null) {
        List<dynamic> existingPhotos = [];

        // Decode existing photos if present
        if (eventDoc.data['photoData'] != null) {
          try {
            existingPhotos = jsonDecode(eventDoc.data['photoData']);
            debugPrint(
                'Successfully decoded existing photos: ${existingPhotos.length}');
          } catch (e) {
            debugPrint('Error decoding existing photos: $e');
            // Assume it's not JSON encoded yet
            existingPhotos = [];
          }
        }

        // Parse uploadedPhotoData from strings to actual objects
        final List<dynamic> parsedUploadedData = uploadedPhotoData
            .map((jsonStr) {
              try {
                return jsonDecode(jsonStr);
              } catch (e) {
                debugPrint('Error parsing photo data: $e');
                return null;
              }
            })
            .where((item) => item != null)
            .toList();

        // Combine both lists
        final List<dynamic> allPhotos = [
          ...existingPhotos,
          ...parsedUploadedData
        ];

        // Convert the entire array to a single JSON string
        final allPhotosJson = jsonEncode(allPhotos);
        debugPrint('Combined photos JSON length: ${allPhotosJson.length}');

        if (allPhotosJson.length > 1000) {
          debugPrint('WARNING: Combined photos exceed 1000 char limit');

          // Try just the new photos
          final newPhotosJson = jsonEncode(parsedUploadedData);
          if (newPhotosJson.length <= 1000) {
            debugPrint(
                'New photos only JSON length: ${newPhotosJson.length} - within limit');

            try {
              await _appwriteService.databases.updateDocument(
                databaseId: _appwriteService.databaseId,
                collectionId: _appwriteService.collectionId,
                documentId: eventDoc.$id,
                data: {'photoData': newPhotosJson},
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Added ${parsedUploadedData.length} new photos (replaced existing)')),
              );
              return;
            } catch (e) {
              debugPrint('Error updating with just new photos: $e');
            }
          } else {
            debugPrint(
                'Even new photos exceed limit (${newPhotosJson.length} chars)');

            // Try adding just one photo (the first one)
            if (parsedUploadedData.isNotEmpty) {
              final singlePhotoJson = jsonEncode([parsedUploadedData.first]);
              debugPrint('Single photo JSON length: ${singlePhotoJson.length}');

              if (singlePhotoJson.length <= 1000) {
                try {
                  await _appwriteService.databases.updateDocument(
                    databaseId: _appwriteService.databaseId,
                    collectionId: _appwriteService.collectionId,
                    documentId: eventDoc.$id,
                    data: {'photoData': singlePhotoJson},
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Added only the first photo (size limitations)')),
                  );
                  return;
                } catch (e) {
                  debugPrint('Error adding single photo: $e');
                }
              }
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Cannot add photos: Exceeds Appwrite 1000 char limit')),
            );
            return;
          }
        } else {
          try {
            // All photos combined are within limits
            await _appwriteService.databases.updateDocument(
              databaseId: _appwriteService.databaseId,
              collectionId: _appwriteService.collectionId,
              documentId: eventDoc.$id,
              data: {'photoData': allPhotosJson},
            );

            // Update local state
            final eventIndex =
                _events.indexWhere((e) => e['id'] == event['id']);
            if (eventIndex >= 0) {
              setState(() {
                _events[eventIndex]['photoData'] = allPhotos;
              });
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      '${parsedUploadedData.length} photos uploaded successfully')),
            );
          } catch (e) {
            debugPrint('Error updating document: $e');
            throw e;
          }
        }
      }
    } catch (e) {
      debugPrint('Error uploading photos: $e');
      // Additional error detail
      if (e.toString().contains('invalid_structure') ||
          e.toString().contains('1000 chars')) {
        debugPrint(
            'Database field size exceeded - Appwrite has a 1000 character limit for string fields');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading photos: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _selectedImage = io.File(image.path);
        _detectedFaces = null;
        _faceFeatures = null;
        _processingImage = true;
      });

      final inputImage = InputImage.fromFilePath(image.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No faces detected in the image')),
        );
        setState(() {
          _processingImage = false;
        });
        return;
      }

      // Use the first detected face
      final face = faces.first;

      // Extract facial features (landmarks, contours, etc.)
      final features = {
        'boundingBox': {
          'left': face.boundingBox.left,
          'top': face.boundingBox.top,
          'right': face.boundingBox.right,
          'bottom': face.boundingBox.bottom,
        },
        'headEulerAngleX': face.headEulerAngleX,
        'headEulerAngleY': face.headEulerAngleY,
        'headEulerAngleZ': face.headEulerAngleZ,
        'leftEyeOpenProbability': face.leftEyeOpenProbability,
        'rightEyeOpenProbability': face.rightEyeOpenProbability,
        'smilingProbability': face.smilingProbability,
        'trackingId': face.trackingId,
      };

      if (face.landmarks.isNotEmpty) {
        final landmarks = {};
        for (final landmark in face.landmarks.entries) {
          landmarks[landmark.key.toString()] = {
            'x': landmark.value?.position.x,
            'y': landmark.value?.position.y,
          };
        }
        features['landmarks'] = landmarks;
      }

      if (face.contours.isNotEmpty) {
        final contours = {};
        for (final contour in face.contours.entries) {
          // Create an empty list as the default value
          List<Map<String, dynamic>> points = [];

          // Only process contour points if contour.value is not null
          if (contour.value != null) {
            // Access the points property of FaceContour
            for (final point in contour.value!.points) {
              points.add({
                'x': point.x,
                'y': point.y,
              });
            }
          }

          // Store the points list (empty or with data)
          contours[contour.key.toString()] = points;
        }
        features['contours'] = contours;
      }

      setState(() {
        _detectedFaces = faces;
        _faceFeatures = features;
        _processingImage = false;
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
      setState(() {
        _processingImage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'ADD EVENT'),
              Tab(text: 'JOIN EVENT'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Add Event Tab
            _buildAddEventTab(),

            // Join Event Tab
            _buildJoinEventTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddEventTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Face Recognition Setup',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'First, save your face to use as reference for event access:',
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _selectedImage != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                        if (_detectedFaces != null)
                          CustomPaint(
                            painter: FacePainter(
                              image: _selectedImage!,
                              faces: _detectedFaces!,
                              imageSize: Size(
                                _selectedImage!
                                    .readAsBytesSync()
                                    .length
                                    .toDouble(),
                                _selectedImage!
                                    .readAsBytesSync()
                                    .length
                                    .toDouble(),
                              ),
                            ),
                          ),
                        if (_processingImage)
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    )
                  : const Icon(
                      Icons.add_a_photo,
                      size: 50,
                      color: Colors.grey,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Select Face Photo'),
              ),
            ],
          ),
          if (_detectedFaces != null && _detectedFaces!.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saveFace,
                  child: const Text('Save Face Reference'),
                ),
              ],
            ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Create New Event',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _eventNameController,
            decoration: const InputDecoration(
              labelText: 'Event Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _eventPasswordController,
            decoration: const InputDecoration(
              labelText: 'Event Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _createEvent,
            child: const Text('Create Event'),
          ),
          const SizedBox(height: 16),

          // Created Events List
          if (_events.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Your Created Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return Card(
                      child: ListTile(
                        title: Text(event['name']),
                        subtitle: Text('Code: ${event['code']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.photo_library),
                              onPressed: () => _uploadPhotosToEvent(event),
                              tooltip: 'Upload Photos',
                            ),
                            IconButton(
                              icon: const Icon(Icons.info),
                              onPressed: () => _showEventPhotos(event),
                              tooltip: 'View Photos',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildJoinEventTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Join an Existing Event',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _eventCodeController,
            decoration: const InputDecoration(
              labelText: 'Event Code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _eventPasswordController,
            decoration: const InputDecoration(
              labelText: 'Event Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _joinEvent,
            child: const Text('Join Event'),
          ),
          const SizedBox(height: 32),
          const Text(
            'Saved Face References',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_savedFaces.isEmpty)
            const Text(
                'No saved faces yet. Please add your face from the ADD EVENT tab.')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _savedFaces.length,
              itemBuilder: (context, index) {
                final face = _savedFaces[index];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.face),
                  ),
                  title: Text(face['name']),
                  subtitle: Text(
                      'Created: ${DateTime.parse(face['created_at']).toLocal().toString().split('.')[0]}'),
                );
              },
            ),
          _buildSavedEventsSection(),
        ],
      ),
    );
  }

  Widget _buildSavedEventsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadJoinedEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final savedEvents = snapshot.data ?? [];

        if (savedEvents.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Saved Events',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: savedEvents.length,
              itemBuilder: (context, index) {
                final event = savedEvents[index];
                return Card(
                  child: ListTile(
                    title: Text(event['name']),
                    subtitle: Text('Code: ${event['code']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.login),
                      onPressed: () {
                        _eventCodeController.text = event['code'];
                        _eventPasswordController.text = event['password'];
                        _joinEvent();
                      },
                      tooltip: 'Quick Join',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadJoinedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final joinedEvents = prefs.getStringList('joined_events') ?? [];

      return joinedEvents
          .map((eventJson) => jsonDecode(eventJson) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      debugPrint('Error loading joined events: $e');
      return [];
    }
  }
}

class FacePainter extends CustomPainter {
  final io.File image;
  final List<Face> faces;
  final Size imageSize;

  FacePainter({
    required this.image,
    required this.faces,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    for (final face in faces) {
      // Scale face position to the canvas size
      final rect = Rect.fromLTRB(
        face.boundingBox.left * size.width / imageSize.width,
        face.boundingBox.top * size.height / imageSize.height,
        face.boundingBox.right * size.width / imageSize.width,
        face.boundingBox.bottom * size.height / imageSize.height,
      );

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return image != oldDelegate.image || faces != oldDelegate.faces;
  }
}
