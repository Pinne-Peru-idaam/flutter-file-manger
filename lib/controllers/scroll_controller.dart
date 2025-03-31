import 'package:flutter/material.dart';

class CustomScrollController {
  final ScrollController controller = ScrollController();

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void dispose() {
    controller.dispose();
  }
}
