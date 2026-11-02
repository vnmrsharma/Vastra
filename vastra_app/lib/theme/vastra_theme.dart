import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'vastra_colors.dart';

class VastraTheme {
  static ThemeData get light {
    final display = GoogleFonts.cormorantGaramond(color: VastraColors.charcoal, fontWeight: FontWeight.w600);
    final body = GoogleFonts.outfit(color: VastraColors.charcoal);

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: VastraColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: VastraColors.ivory,
      canvasColor: VastraColors.softWhite,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.light(
        primary: VastraColors.burgundy,
        onPrimary: VastraColors.softWhite,
        primaryContainer: VastraColors.blush,
        onPrimaryContainer: VastraColors.burgundy,
        secondary: VastraColors.chocolate,
        onSecondary: VastraColors.softWhite,
        surface: VastraColors.softWhite,
        onSurface: VastraColors.charcoal,
        onSurfaceVariant: VastraColors.muted,
        surfaceTint: Colors.transparent,
        outline: VastraColors.border,
        error: VastraColors.danger,
      ),
      textTheme: TextTheme(
        displayLarge: display.copyWith(fontSize: 57),
        displayMedium: display.copyWith(fontSize: 45),
        displaySmall: display.copyWith(fontSize: 36),
        headlineLarge: display.copyWith(fontSize: 32),
        headlineMedium: display.copyWith(fontSize: 28),
        headlineSmall: display.copyWith(fontSize: 24),
        titleLarge: body.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
        titleSmall: body.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge: body.copyWith(fontSize: 16),
        bodyMedium: body.copyWith(fontSize: 14, color: VastraColors.chocolate),
        bodySmall: body.copyWith(fontSize: 12, color: VastraColors.muted),
        labelLarge: body.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        labelMedium: body.copyWith(fontSize: 13),
        labelSmall: body.copyWith(fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: VastraColors.charcoal,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.cormorantGaramond(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          color: VastraColors.charcoal,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VastraColors.softWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: GoogleFonts.outfit(color: VastraColors.muted),
        floatingLabelStyle: GoogleFonts.outfit(color: VastraColors.chocolate),
        hintStyle: GoogleFonts.outfit(color: VastraColors.muted.withValues(alpha: 0.7)),
        prefixIconColor: VastraColors.muted,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: VastraColors.burgundySoft, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VastraColors.burgundy,
          foregroundColor: VastraColors.softWhite,
          disabledBackgroundColor: VastraColors.burgundy.withValues(alpha: 0.35),
          disabledForegroundColor: VastraColors.softWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VastraColors.charcoal,
          backgroundColor: VastraColors.softWhite.withValues(alpha: 0.7),
          side: const BorderSide(color: VastraColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VastraColors.burgundy,
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: VastraColors.softWhite,
        selectedColor: VastraColors.blush,
        side: const BorderSide(color: VastraColors.border),
        showCheckmark: false,
        labelStyle: GoogleFonts.outfit(color: VastraColors.chocolate, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const StadiumBorder(),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? VastraColors.burgundy : Colors.transparent,
        ),
        side: const BorderSide(color: VastraColors.muted, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: VastraColors.softWhite,
        surfaceTintColor: Colors.transparent,
        indicatorColor: VastraColors.blush,
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? VastraColors.burgundy : VastraColors.muted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: s.contains(WidgetState.selected) ? VastraColors.burgundy : VastraColors.muted,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: VastraColors.softWhite,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: VastraColors.border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: VastraColors.softWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.cormorantGaramond(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: VastraColors.charcoal,
        ),
        contentTextStyle: GoogleFonts.outfit(color: VastraColors.chocolate),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: VastraColors.charcoal,
        contentTextStyle: GoogleFonts.outfit(color: VastraColors.softWhite),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: const PopupMenuThemeData(color: VastraColors.softWhite, surfaceTintColor: Colors.transparent),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: VastraColors.burgundy,
        linearTrackColor: VastraColors.blush,
      ),
      dividerColor: VastraColors.border,
    );
  }
}
