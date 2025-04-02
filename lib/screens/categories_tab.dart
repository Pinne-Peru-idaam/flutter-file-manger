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
              title: 'Storage',
              items: [
                CategoryItem(
                  title: 'Downloads',
                  icon: Icons.download,
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
                  icon: Icons.image,
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
                  icon: Icons.video_library,
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
                  icon: Icons.music_note,
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
              ],
            ),
            const SizedBox(height: 16),
            CategorySection(
              title: 'Categories',
              items: [
                CategoryItem(
                  title: 'Documents',
                  icon: Icons.description,
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
                  icon: Icons.archive,
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
