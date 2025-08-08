import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  green,
  red,
  orange,
  blue,
  purple,
  lightPurple,
  pink,
  light,
  dark,
}

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.green;
  static const String fontFamily = 'DMSans';
  
  // Sage green color for replacing orange UI elements
  static const Color sageGreen = Color(0xFF87A96B);
  
  AppThemeMode get themeMode => _themeMode;
  
  bool get isDarkMode => _themeMode == AppThemeMode.dark;
  
  ThemeProvider() {
    _loadTheme();
  }
  
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('theme_mode') ?? 'green';
    _themeMode = AppThemeMode.values.firstWhere(
      (mode) => mode.toString().split('.').last == themeName,
      orElse: () => AppThemeMode.green,
    );
    notifyListeners();
  }
  
  Future<void> setTheme(AppThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString().split('.').last);
    notifyListeners();
  }
  
  ThemeData getTheme() {
    switch (_themeMode) {
      case AppThemeMode.red:
        return _buildTheme(
          primaryColor: const Color(0xFF690808),
          secondaryColor: const Color(0xFF690808),
          backgroundColor: const Color(0xFFD68D8D),
        );
      case AppThemeMode.orange:
        return _buildTheme(
          primaryColor: const Color(0xFFAD570C),
          secondaryColor: const Color(0xFFAD570C),
          backgroundColor: const Color(0xFFEDB585),
        );
      case AppThemeMode.green:
        return _buildTheme(
          primaryColor: const Color(0xFFAECFB6), // Original light green
          secondaryColor: const Color(0xFF547A5F), // Original darker green
          backgroundColor: const Color(0xFFF5F5F5), // Light background
        );
      case AppThemeMode.blue:
        return _buildTheme(
          primaryColor: const Color(0xFF4569A3),
          secondaryColor: const Color(0xFF4569A3),
          backgroundColor: const Color(0xFFB8CFF5),
        );
      case AppThemeMode.purple:
        return _buildTheme(
          primaryColor: const Color(0xFF460E5C),
          secondaryColor: const Color(0xFF460E5C),
          backgroundColor: const Color(0xFFE4BAF5),
        );
      case AppThemeMode.lightPurple:
        return _buildTheme(
          primaryColor: const Color(0xFF9e8df1), // Light purple primary
          secondaryColor: const Color(0xFF7b68ee), // Medium slate blue secondary
          backgroundColor: const Color(0xFFe6e6fa), // Lavender background
        );
      case AppThemeMode.pink:
        return _buildTheme(
          primaryColor: const Color(0xFFf78fc5), // Pink primary
          secondaryColor: const Color(0xFFa62367), // Pink secondary
          backgroundColor: const Color(0xFFfce4ec), // Light pink background
        );
      case AppThemeMode.light:
        return _buildTheme(
          primaryColor: Colors.black,
          secondaryColor: Colors.grey[700]!,
          backgroundColor: Colors.white,
          isLight: true,
        );
      case AppThemeMode.dark:
        return _buildTheme(
          primaryColor: const Color(0xFF76B887), // Green accents
          secondaryColor: const Color(0xFF76B887), // Green accents
          backgroundColor: const Color(0xFF000000), // Black background
          isDark: true,
        );
    }
  }
  
  ThemeData _buildTheme({
    required Color primaryColor,
    required Color secondaryColor,
    required Color backgroundColor,
    bool isLight = false,
    bool isDark = false,
  }) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    
    return ThemeData(
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0A0A0A) : (isLight ? Colors.grey[50] : const Color(0xFFF5F5F5)),
      fontFamily: fontFamily,
      textTheme: TextTheme(
        // Display (largest headers) - SemiBold for big titles
        displayLarge: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        displayMedium: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        displaySmall: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        // Headlines (big headers) - SemiBold
        headlineLarge: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        headlineMedium: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        headlineSmall: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        // Titles (medium headers) - SemiBold
        titleLarge: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        titleMedium: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        titleSmall: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        // Body text (smaller text like chats) - Regular
        bodyLarge: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
        bodyMedium: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
        bodySmall: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
        // Labels (smaller text) - Regular
        labelLarge: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
        labelMedium: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
        labelSmall: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w400),
      ).apply(
        bodyColor: isDark ? Colors.white : Colors.black,
        displayColor: isDark ? Colors.white : Colors.black,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
      ).copyWith(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: isDark ? Colors.grey[900] : (isLight ? Colors.white : backgroundColor.withValues(alpha: 0.5)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? Colors.grey[850] : Colors.white,
        elevation: isDark ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? primaryColor.withValues(alpha: 0.3) : (isLight ? Colors.grey[300]! : primaryColor.withValues(alpha: 0.2)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.grey[700] : Colors.grey[300],
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: isDark ? Colors.white : Colors.black,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }
}