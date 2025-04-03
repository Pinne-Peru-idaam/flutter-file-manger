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
                  'photos': doc.data['photos'] ?? [],
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
        'photos': [],
      };

      final document = await _appwriteService.createEvent(eventData);

      setState(() {
        _events.add({
          'id': document.$id,
          'name': _eventNameController.text,
          'code': eventCode,
          'password': _eventPasswordController.text,
          'created_at': DateTime.now().toIso8601String(),
          'photos': [],
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
        'photos': eventDoc.data['photos'] ?? [],
      };

      if (event['password'] != _eventPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect password')),
        );
        return;
      }

      // Fetch user's saved face features to filter photos
      final authService = AuthService();
      final userFaceFeatures = await authService.getFaceFeatures();

      // Filter photos to only show matching ones
      if (userFaceFeatures != null && event['photos'].isNotEmpty) {
        // This would need actual face matching implementation
        // For now, we'll just display all photos
        debugPrint('Filtering photos based on face recognition');
      }

      // Show event photos
      _showEventPhotos(event);

      _eventCodeController.clear();
      _eventPasswordController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining event: $e')),
      );
    }
  }

  void _showEventPhotos(Map<String, dynamic> event) {
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
              const SizedBox(height: 16),
              if ((event['photos'] as List).isEmpty)
                const Center(
                  child: Text('No photos uploaded for this event yet'),
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
                    itemCount: (event['photos'] as List).length,
                    itemBuilder: (context, index) {
                      final fileId = event['photos'][index];
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
                                    _appwriteService.getFileViewUrl(fileId),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _appwriteService.getFileViewUrl(fileId),
                            fit: BoxFit.cover,
                          ),
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
      final uploadedFileIds = <String>[];

      for (final image in result) {
        final file = io.File(image.path);
        final uploadedFile =
            await _appwriteService.uploadFile(file, event['id']);
        uploadedFileIds.add(uploadedFile.$id);
      }

      // Update event document with new file IDs
      final eventDoc = await _appwriteService.getEventByCode(event['code']);
      if (eventDoc != null) {
        final existingPhotos = eventDoc.data['photos'] ?? [];
        final updatedPhotos = [...existingPhotos, ...uploadedFileIds];

        await _appwriteService.databases.updateDocument(
          databaseId: _appwriteService.databaseId,
          collectionId: _appwriteService.collectionId,
          documentId: eventDoc.$id,
          data: {'photos': updatedPhotos},
        );

        // Update local state
        final eventIndex = _events.indexWhere((e) => e['id'] == event['id']);
        setState(() {
          _events[eventIndex]['photos'] = updatedPhotos;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${uploadedFileIds.length} photos uploaded')),
      );
    } catch (e) {
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
        ],
      ),
    );
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
