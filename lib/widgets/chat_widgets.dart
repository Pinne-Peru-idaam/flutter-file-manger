import 'package:flutter/material.dart';
import 'package:chat_bubbles/chat_bubbles.dart';

class ChatMessageWidget extends StatelessWidget {
  final String message;
  final bool isUser;
  final VoidCallback? onTap;

  const ChatMessageWidget({
    Key? key,
    required this.message,
    required this.isUser,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BubbleSpecialThree(
      text: message,
      color: isUser
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).brightness == Brightness.dark
              ? Color(0xFF303030)
              : Color(0xFFE8E8EE),
      tail: true,
      isSender: isUser,
      textStyle: TextStyle(
        color: isUser
            ? Colors.white
            : Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
        fontSize: 16,
      ),
    );
  }
}

class FilePreviewCard extends StatelessWidget {
  final String fileName;
  final String filePath;
  final String fileType;
  final VoidCallback onTap;

  const FilePreviewCard({
    Key? key,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(_getFileIcon(fileType)),
        title: Text(fileName),
        subtitle: Text(filePath),
        onTap: onTap,
      ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_library;
      case 'pdf':
        return Icons.picture_as_pdf;
      default:
        return Icons.insert_drive_file;
    }
  }
}
