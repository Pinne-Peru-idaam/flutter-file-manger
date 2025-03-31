import 'package:flutter/material.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imagePath;

  const ImageViewerScreen({required this.imagePath, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(imagePath.split('/').last),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Implement sharing
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Open in external editor
              OpenFile.open(imagePath);
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Unable to load image'),
                  TextButton(
                    onPressed: () {
                      OpenFile.open(imagePath);
                    },
                    child: const Text('Open with external app'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
