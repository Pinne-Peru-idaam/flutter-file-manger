import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_face_api/flutter_face_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
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
  // Face API instance
  var faceSdk = FaceSDK.instance;
  bool _faceApiInitialized = false;

  final ImagePicker _picker = ImagePicker();
  io.File? _selectedImage;
  Map<String, dynamic>? _faceFeatures;
  bool _processingImage = false;
  List<Map<String, dynamic>> _savedFaces = [];
  List<Map<String, dynamic>> _events = [];
  Map<String, List<String>> _matchedPhotos = {};

  MatchFacesImage? _referenceImage;

  TextEditingController _nameController = TextEditingController();
  TextEditingController _eventNameController = TextEditingController();
  TextEditingController _eventCodeController = TextEditingController();
  TextEditingController _eventPasswordController = TextEditingController();

  final AppwriteService _appwriteService = AppwriteService();

  @override
  void initState() {
    super.initState();
    _initializeFaceApi();
    _loadSavedFaces();
    _loadEvents();
  }

  Future<void> _initializeFaceApi() async {
    try {
      setState(() {
        _processingImage = true;
      });

      final result = await faceSdk.initialize();
      if (result.$1) {
        setState(() {
          _faceApiInitialized = true;
        });
        debugPrint("FaceAPI initialized successfully");
      } else {
        debugPrint("FaceAPI initialization failed: ${result.$2?.message}");
      }
    } catch (e) {
      debugPrint("Error initializing FaceAPI: $e");
    } finally {
      setState(() {
        _processingImage = false;
      });
    }
  }

  @override
  void dispose() {
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
    if (_selectedImage == null || _referenceImage == null) return;

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
        'imagePath': _selectedImage!.path,
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
        _referenceImage = null;
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

      // Check if we have a face reference
      if (_savedFaces.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please add your face from the ADD EVENT tab first')),
        );
        return;
      }

      // Use the most recent saved face for matching
      final latestFace = _savedFaces.last;
      final facePath = latestFace['imagePath'];

      if (facePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Invalid face reference, please add your face again')),
        );
        return;
      }

      // Show loading indicator
      setState(() {
        _processingImage = true;
      });

      try {
        // Create reference face image for matching
        final faceBytes = await io.File(facePath).readAsBytes();
        final referenceImage = MatchFacesImage(faceBytes, ImageType.PRINTED);

        // Match face with event photos
        final matchedPhotoIds = await _matchFaceWithEventPhotos(
            referenceImage, event['photos'] as List);

        // Store matched photos for this event
        setState(() {
          _matchedPhotos[event['id']] = matchedPhotoIds;
        });

        // Show event photos that match the user's face
        _showEventPhotos(event, matchedPhotoIds);
      } finally {
        setState(() {
          _processingImage = false;
        });
      }

      _eventCodeController.clear();
      _eventPasswordController.clear();
    } catch (e) {
      setState(() {
        _processingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining event: $e')),
      );
    }
  }

  Future<List<String>> _matchFaceWithEventPhotos(
      MatchFacesImage referenceImage, List eventPhotos) async {
    final matchedPhotoIds = <String>[];

    for (final fileId in eventPhotos) {
      try {
        final url = _appwriteService.getFileViewUrl(fileId);

        // Download the event photo
        final response = await io.HttpClient().getUrl(Uri.parse(url));
        final httpResponse = await response.close();
        final bytes = await httpResponse.toList();
        final imageBytes = bytes.expand((element) => element).toList();

        // Create comparison image
        final photoImage =
            MatchFacesImage(Uint8List.fromList(imageBytes), ImageType.PRINTED);

        // Match faces
        final request = MatchFacesRequest([referenceImage, photoImage]);
        final matchResponse = await faceSdk.matchFaces(request);

        // Check if matched
        final splitResponse =
            await faceSdk.splitComparedFaces(matchResponse.results, 0.75);

        if (splitResponse.matchedFaces.isNotEmpty) {
          // There is a match - add the photo ID to matched list
          matchedPhotoIds.add(fileId);
        }
      } catch (e) {
        debugPrint('Error matching photo $fileId: $e');
      }
    }

    return matchedPhotoIds;
  }

  void _showEventPhotos(Map<String, dynamic> event,
      [List<String>? filteredPhotoIds]) {
    final photoIds =
        filteredPhotoIds ?? (event['photos'] as List).cast<String>();

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
              if (photoIds.isEmpty)
                const Center(
                  child: Text('No matching photos found for you in this event'),
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
                    itemCount: photoIds.length,
                    itemBuilder: (context, index) {
                      final fileId = photoIds[index];
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
    if (!_faceApiInitialized) {
      await _initializeFaceApi();
      if (!_faceApiInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face API not initialized')),
        );
        return;
      }
    }

    try {
      setState(() {
        _processingImage = true;
      });

      // Start face capture using FaceCaptureUI
      final result = await faceSdk.startFaceCapture();
      if (result.image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No face captured')),
        );
        setState(() {
          _processingImage = false;
        });
        return;
      }

      // Save captured image to file
      final tempDir = await io.Directory.systemTemp.createTemp();
      final tempFile = io.File('${tempDir.path}/face.jpg');
      await tempFile.writeAsBytes(result.image!.image);

      // Create a MatchFacesImage from the captured image
      final capturedImage =
          MatchFacesImage(result.image!.image, ImageType.PRINTED);

      setState(() {
        _selectedImage = tempFile;
        _referenceImage = capturedImage;
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
        body: Stack(
          children: [
            TabBarView(
              children: [
                // Add Event Tab
                _buildAddEventTab(),

                // Join Event Tab
                _buildJoinEventTab(),
              ],
            ),
            if (_processingImage)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
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
                  ? Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
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
                label: const Text('Capture Face'),
              ),
            ],
          ),
          if (_selectedImage != null)
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
                              tooltip: 'View All Photos',
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
                  leading: CircleAvatar(
                    backgroundImage: face['imagePath'] != null
                        ? FileImage(io.File(face['imagePath']))
                        : null,
                    child: face['imagePath'] == null ? Icon(Icons.face) : null,
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
