import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTheme {
  // Premium Emerald Green seed color
  static const _seedColor = Color(0xFF059669);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
      // Customizing some scheme colors for a more premium look
      primary: _seedColor,
      surface: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
      surfaceContainerLowest: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF020617),
      surfaceContainerLow: isLight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
    );

    final base = isLight ? ThemeData.light(useMaterial3: true) : ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: scheme,
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme),
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 28),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
        selectedLabelTextStyle: GoogleFonts.outfit(
          color: scheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: GoogleFonts.outfit(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: scheme.primaryContainer.withOpacity(0.5),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      cardTheme: CardTheme(
        elevation: isLight ? 2 : 0,
        shadowColor: scheme.shadow.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isLight 
              ? BorderSide.none 
              : BorderSide(color: scheme.outlineVariant.withOpacity(0.3)),
        ),
        color: scheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isLight ? Colors.transparent : scheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: GoogleFonts.outfit(
          color: scheme.onSurfaceVariant, 
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.outfit(
          color: scheme.onSurfaceVariant.withOpacity(0.7),
          fontSize: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
          elevation: isLight ? 2 : 0,
          shadowColor: scheme.primary.withOpacity(0.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          elevation: isLight ? 2 : 0,
          backgroundColor: scheme.surfaceContainerLowest,
          foregroundColor: scheme.primary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(isLight ? 0.3 : 0.1),
        thickness: 1,
        space: 24,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.transparent),
        ),
        labelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(
          isLight ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withOpacity(0.04);
          }
          return scheme.surfaceContainerLowest;
        }),
        dividerThickness: 0.5,
        headingTextStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
        dataTextStyle: GoogleFonts.outfit(
          color: scheme.onSurface,
          fontSize: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }
}
