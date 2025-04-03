import 'package:flutter/material.dart';

class CategoryItem extends StatelessWidget {
  final String title;
  final dynamic icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const CategoryItem({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 0, top: 0, bottom: 0),
          child: Row(
            children: [
              icon is IconData
                  ? Icon(
                      icon as IconData,
                      color: color,
                      size: 20,
                    )
                  : icon,
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
