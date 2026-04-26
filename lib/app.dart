import 'package:flutter/material.dart';

import 'presentation/app_root.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final baseColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1F6F5B),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: baseColorScheme,
    useMaterial3: true,
  );
}

ThemeData buildTerminalTheme() {
  const background = Color(0xFF07130A);
  const panel = Color(0xFF0D1D11);
  const primary = Color(0xFF6BFF8F);
  const secondary = Color(0xFF2ACF6E);
  const text = Color(0xFFB8FFC8);
  const muted = Color(0xFF7ABA88);
  const outline = Color(0xFF245C34);

  final scheme = const ColorScheme.dark(
    primary: primary,
    secondary: secondary,
    surface: panel,
    onSurface: text,
    onPrimary: background,
    onSecondary: background,
    outline: outline,
  ).copyWith(
    surfaceContainerHighest: const Color(0xFF14311C),
    surfaceContainerLow: const Color(0xFF102716),
  );

  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    useMaterial3: true,
    fontFamily: 'Courier',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: outline),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: outline,
      thickness: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: primary,
      textColor: text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panel,
      labelStyle: const TextStyle(color: muted),
      hintStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: primary,
      collapsedIconColor: primary,
      textColor: text,
      collapsedTextColor: text,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: outline),
      ),
      textStyle: const TextStyle(color: text),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: outline),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: panel,
      contentTextStyle: TextStyle(color: text),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: text,
      displayColor: text,
    ),
  );
}

class SharedListsApp extends StatelessWidget {
  const SharedListsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppRoot();
  }
}
