import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// import '../widgets/cleanup_card.dart';
// import '../widgets/category_section.dart';
import '../widgets/category_card.dart';
import '../screens/file_list_screen.dart';

class CategoriesTab extends StatelessWidget {
  const CategoriesTab({super.key});

  Future<String> _getBasePath() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0';
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getBasePath(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final basePath = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // const CleanupCard(),
            const SizedBox(height: 12),
            Text(
              'Categories',
              style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                CategoryCard(
                  title: 'Downloads',
                  size: '456 MB',
                  imagePath: 'assets/icons/download-01.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FileListScreen(
                          title: 'Downloads',
                          directoryPath: '$basePath/Download',
                        ),
                      ),
                    );
                  },
                ),
                CategoryCard(
                  title: 'Images',
                  size: '1.2 GB',
                  imagePath: 'assets/icons/image-05.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FileListScreen(
                          title: 'Images',
                          directoryPath: '$basePath/Pictures',
                        ),
                      ),
                    );
                  },
                ),
                CategoryCard(
                  title: 'Videos',
                  size: '2.8 GB',
                  imagePath: 'assets/icons/video-recorder.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FileListScreen(
                          title: 'Videos',
                          directoryPath: '$basePath/DCIM',
                        ),
                      ),
                    );
                  },
                ),
                CategoryCard(
                  title: 'Audio',
                  size: '228 MB',
                  imagePath: 'assets/icons/recording-01.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FileListScreen(
                          title: 'Audio',
                          directoryPath: '$basePath/Music',
                        ),
                      ),
                    );
                  },
                ),
                CategoryCard(
                  title: 'Documents',
                  size: '128 MB',
                  imagePath: 'assets/icons/file-attachment-02.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FileListScreen(
                          title: 'Documents',
                          directoryPath: '$basePath/Documents',
                        ),
                      ),
                    );
                  },
                ),
                CategoryCard(
                  title: 'Archives',
                  size: '64 MB',
                  imagePath: 'assets/icons/archive.png',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FileListScreen(
                          title: 'Archives',
                          directoryPath: '$basePath/Download',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
