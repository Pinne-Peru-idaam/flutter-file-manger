import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
// import '../widgets/cleanup_card.dart';
import '../widgets/category_section.dart';
import '../widgets/category_item.dart';
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
          padding: const EdgeInsets.all(16),
          children: [
            // const CleanupCard(),
            const SizedBox(height: 16),
            CategorySection(
              title: 'Categories',
              items: [
                CategoryItem(
                  title: 'Downloads',
                  icon: SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.asset(
                      'assets/icons/download-01.png',
                      color: Colors.blue,
                    ),
                  ),
                  backgroundColor:
                      Theme.of(context).colorScheme.onPrimaryFixedVariant,
                  color: Colors.blue,
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
                CategoryItem(
                  title: 'Images',
                  icon: SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.asset(
                      'assets/icons/image-05.png',
                      color: Colors.blue,
                    ),
                  ),
                  backgroundColor:
                      Theme.of(context).colorScheme.onPrimaryFixedVariant,
                  color: Colors.purple,
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
                CategoryItem(
                  title: 'Videos',
                  icon: SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.asset(
                      'assets/icons/video-recorder.png',
                      color: Colors.blue,
                    ),
                  ),
                  backgroundColor:
                      Theme.of(context).colorScheme.onPrimaryFixedVariant,
                  color: Colors.red,
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
                CategoryItem(
                  title: 'Audio',
                  icon: SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.asset(
                      'assets/icons/recording-01.png',
                      color: Colors.blue,
                    ),
                  ),
                  backgroundColor:
                      Theme.of(context).colorScheme.onPrimaryFixedVariant,
                  color: Colors.orange,
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
                CategoryItem(
                  title: 'Documents',
                  icon: SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.asset(
                      'assets/icons/file-attachment-02.png',
                      color: Colors.blue,
                    ),
                  ),
                  backgroundColor:
                      Theme.of(context).colorScheme.onPrimaryFixedVariant,
                  color: Colors.teal,
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
                CategoryItem(
                  title: 'Archives',
                  icon: SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.asset(
                      'assets/icons/archive.png',
                      color: Colors.blue,
                    ),
                  ),
                  backgroundColor:
                      Theme.of(context).colorScheme.onPrimaryFixedVariant,
                  color: Colors.brown,
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
