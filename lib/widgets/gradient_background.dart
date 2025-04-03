import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(1.2, -0.6),
          radius: 1.6,
          colors: isDark ? [
            const Color(0xFF1A3048), // Dark blue
            const Color(0xFF0D1B29), // Darker blue
            const Color(0xFF060D14), // Very dark blue
            const Color(0xFF020408), // Almost black with slight blue
            const Color(0xFF010204), // Almost black with green tint at bottom
          ] : [
            const Color(0xFFE6F0FF), // Light blue
            const Color(0xFFD1E5FF), // Lighter blue
            const Color(0xFFB8D9FF), // Very light blue
            const Color(0xFFA0CDFF), // Lightest blue
            const Color(0xFF8AC2FF), // Light blue with slight tint
          ],
          stops: const [0.2, 0.4, 0.6, 0.8, 1.0],
          focal: const Alignment(1, -0.6),
          focalRadius: 0.2,
        ),
      ),
      child: child,
    );
  }
} 