import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const Color ink = Color(0xFF0A0C0E);
const Color panel = Color(0xFF15191E);
const Color panelRaised = Color(0xFF1E242C);
const Color line = Color(0xFF2C343E);
const Color paper = Color(0xFFF4F6F8);
const Color dim = Color(0xFF9AA3AD);
const Color goYellow = Color(0xFFF5C400);
const Color goInk = Color(0xFF1A1400);
const Color panicRed = Color(0xFFC41818);
const Color liveGreen = Color(0xFF3DDC97);

ThemeData buildUnmuteTheme() {
  final scheme = ColorScheme.dark(
    surface: ink,
    primary: goYellow,
    onPrimary: goInk,
    secondary: const Color(0xFF9EBBFF),
    onSecondary: ink,
    error: const Color(0xFFFF6B6B),
    onError: ink,
    onSurface: paper,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ink,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: ink,
      foregroundColor: paper,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF101418),
      indicatorColor: goYellow.withValues(alpha: 0.22),
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? goYellow : dim,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? goYellow : dim, size: 26);
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      labelStyle: const TextStyle(color: dim, fontSize: 16),
      hintStyle: const TextStyle(color: dim),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: goYellow, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    chipTheme: const ChipThemeData(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      side: BorderSide(color: line),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: panelRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

ButtonStyle bigFill({required Color background, required Color foreground}) {
  return FilledButton.styleFrom(
    backgroundColor: background,
    foregroundColor: foreground,
    disabledBackgroundColor: panelRaised,
    disabledForegroundColor: dim,
    minimumSize: const Size.fromHeight(64),
    textStyle: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}
