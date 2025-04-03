import 'package:flutter/material.dart';

class CategoryCard extends StatelessWidget {
  final String title;
  final String size;
  final String imagePath;
  final VoidCallback onTap;

  const CategoryCard({
    super.key, 
    required this.title,
    required this.size,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1418),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Image.asset(
              imagePath,
              width: 20,
              height: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  size,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 