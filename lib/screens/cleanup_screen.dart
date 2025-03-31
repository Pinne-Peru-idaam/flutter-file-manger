import 'package:flutter/material.dart';

class CleanupScreen extends StatefulWidget {
  const CleanupScreen({super.key});

  @override
  State<CleanupScreen> createState() => _CleanupScreenState();
}

class _CleanupScreenState extends State<CleanupScreen> {
  bool isAnalyzing = false;
  final List<Map<String, dynamic>> cleanupItems = [
    {
      'title': 'Large Files',
      'description': 'Files larger than 100MB',
      'icon': Icons.file_present,
    },
    {
      'title': 'Duplicate Files',
      'description': 'Find and remove duplicate files',
      'icon': Icons.file_copy,
    },
    {
      'title': 'Empty Folders',
      'description': 'Locate and remove empty folders',
      'icon': Icons.folder_off,
    },
    {
      'title': 'Temporary Files',
      'description': 'Clean temporary and cache files',
      'icon': Icons.delete_sweep,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Storage Cleanup',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: cleanupItems.length,
              itemBuilder: (context, index) {
                final item = cleanupItems[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: Icon(item['icon'] as IconData),
                    title: Text(item['title'] as String),
                    subtitle: Text(item['description'] as String),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Implement cleanup functionality
                    },
                  ),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: isAnalyzing
                ? null
                : () {
                    setState(() {
                      isAnalyzing = true;
                    });
                    // TODO: Implement analysis functionality
                  },
            child: Text(isAnalyzing ? 'Analyzing...' : 'Analyze Storage'),
          ),
        ],
      ),
    );
  }
}
