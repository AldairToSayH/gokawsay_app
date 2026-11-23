import 'package:material_ui/material_ui.dart';

const roomEditorialPhoto = 'assets/room-san-blas.png';
const designRadius = 24.0;

TextStyle editorialHeading(BuildContext context) =>
    Theme.of(context).textTheme.displaySmall!;

ThemeData goKawsayTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFAA4C38),
        brightness: brightness,
      ).copyWith(
        primary: light ? const Color(0xFF973D2E) : const Color(0xFFFFB5A2),
        onPrimary: light ? Colors.white : const Color(0xFF521C12),
        primaryContainer: light
            ? const Color(0xFFF8E4DA)
            : const Color(0xFF572D24),
        onPrimaryContainer: light
            ? const Color(0xFF692A1E)
            : const Color(0xFFFFD9CD),
        secondaryContainer: light
            ? const Color(0xFFEDE5D9)
            : const Color(0xFF43372E),
        onSecondaryContainer: light
            ? const Color(0xFF49392F)
            : const Color(0xFFF1E0D3),
        surface: light ? const Color(0xFFFFFCF8) : const Color(0xFF201B19),
        surfaceContainer: light
            ? const Color(0xFFF8F1E9)
            : const Color(0xFF2A2421),
        surfaceContainerHigh: light
            ? const Color(0xFFF1E8DF)
            : const Color(0xFF362C27),
        onSurface: light ? const Color(0xFF271F1C) : const Color(0xFFF6E8DF),
        onSurfaceVariant: light
            ? const Color(0xFF675752)
            : const Color(0xFFD6C2B9),
        outline: light ? const Color(0xFF8D776C) : const Color(0xFF9F8C83),
        outlineVariant: light
            ? const Color(0xFFE7D9CE)
            : const Color(0xFF56463F),
      );
  final theme = ThemeData(colorScheme: scheme, fontFamily: 'DM Sans');
  final text = theme.textTheme;
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(17),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return theme.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontFamily: 'Instrument Serif',
        fontSize: 47,
        height: 1.01,
      ),
      headlineLarge: text.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.15,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.65,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -.45,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(designRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainer,
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 49),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
    ),
  );
}
