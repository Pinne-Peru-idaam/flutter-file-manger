import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

class AppTheme {
  static ThemeData themeData(ColorScheme colorScheme) {
    // Harmonize the color scheme
    final harmonizedScheme = colorScheme.harmonized();

    // Custom colors to harmonize with the dynamic scheme
    final customAccent = Colors.orange.harmonizeWith(harmonizedScheme.primary);

    return ThemeData(
      useMaterial3: true,
      colorScheme: harmonizedScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: harmonizedScheme.surface,
        foregroundColor: harmonizedScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: harmonizedScheme.surface,
      ),
      bottomAppBarTheme: BottomAppBarTheme(
        color: harmonizedScheme.surface,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: harmonizedScheme.primary,
        foregroundColor: harmonizedScheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      iconTheme: IconThemeData(
        color: harmonizedScheme.onSurface,
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      // Additional theme customizations using harmonized colors
      chipTheme: ChipThemeData(
        backgroundColor: harmonizedScheme.surfaceContainerHighest,
        selectedColor: customAccent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: harmonizedScheme.inverseSurface,
        contentTextStyle: TextStyle(color: harmonizedScheme.onInverseSurface),
      ),
    );
  }
}
