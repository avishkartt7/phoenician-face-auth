// lib/constants/theme.dart - ENHANCED VERSION WITH LIGHT/DARK MODE SUPPORT

import 'package:flutter/material.dart';




const Color primaryWhite = Color(0xFFFFFFFF);
const Color primaryBlack = Color(0xFF000000);
const Color appBarColor = Color(0xFF6A5ACD); // Same as scaffoldTopGradientClr
const Color buttonColor = Color(0xFF4CAF50); // Same as accentColor
const Color overlayContainerClr = Color(0xFF000000);



// ✅ ENHANCED: Original colors maintained for backward compatibility
const Color scaffoldTopGradientClr = Color(0xFF6A5ACD); // SlateBlue
const Color scaffoldBottomGradientClr = Color(0xFF483D8B); // DarkSlateBlue
const Color accentColor = Color(0xFF4CAF50); // Green

// ✅ NEW: Enhanced color palette for light/dark mode
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF6A5ACD);
  static const Color primaryDark = Color(0xFF483D8B);
  static const Color accent = Color(0xFF4CAF50);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Neutral colors for light mode
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightBorder = Color(0xFFE0E0E0);

  // Neutral colors for dark mode
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2D2D2D);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB3B3B3);
  static const Color darkDivider = Color(0xFF404040);
  static const Color darkBorder = Color(0xFF404040);

  // Gradient colors
  static const List<Color> lightGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFF5F5F5),
  ];

  static const List<Color> darkGradient = [
    Color(0xFF1E1E1E),
    Color(0xFF121212),
  ];

  // Status-specific gradients
  static const List<Color> successGradient = [
    Color(0xFF66BB6A),
    Color(0xFF4CAF50),
  ];

  static const List<Color> warningGradient = [
    Color(0xFFFFB74D),
    Color(0xFFFF9800),
  ];

  static const List<Color> errorGradient = [
    Color(0xFFEF5350),
    Color(0xFFF44336),
  ];

  static const List<Color> infoGradient = [
    Color(0xFF42A5F5),
    Color(0xFF2196F3),
  ];
}

// ✅ NEW: Enhanced theme data
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: createMaterialColor(AppColors.primary),
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.lightBackground,

    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.lightSurface,
      background: AppColors.lightBackground,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.lightText,
      onBackground: AppColors.lightText,
      onError: Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    cardTheme: CardTheme(
      color: AppColors.lightCard,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.black.withOpacity(0.1),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
      hintStyle: const TextStyle(color: AppColors.lightTextSecondary),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return AppColors.accent;
        }
        return AppColors.lightBorder;
      }),
      checkColor: MaterialStateProperty.all(Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    tabBarTheme: const TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primarySwatch: createMaterialColor(AppColors.primary),
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.darkBackground,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
      background: AppColors.darkBackground,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.darkText,
      onBackground: AppColors.darkText,
      onError: Colors.white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),

    cardTheme: CardTheme(
      color: AppColors.darkCard,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      shadowColor: Colors.black.withOpacity(0.3),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
      hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return AppColors.accent;
        }
        return AppColors.darkBorder;
      }),
      checkColor: MaterialStateProperty.all(Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    tabBarTheme: const TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
  );

  // ✅ Helper method to create MaterialColor from Color
  static MaterialColor createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    strengths.forEach((strength) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    });
    return MaterialColor(color.value, swatch);
  }
}

// ✅ NEW: Theme-aware helper widgets
class ThemeAwareContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;
  final bool hasShadow;
  final Color? customColor;

  const ThemeAwareContainer({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.hasShadow = true,
    this.customColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      decoration: BoxDecoration(
        color: customColor ?? (isDarkMode ? AppColors.darkCard : AppColors.lightCard),
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: hasShadow ? [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: child,
    );
  }
}

class ThemeAwareGradientContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;
  final List<Color>? customGradient;

  const ThemeAwareGradientContainer({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.customGradient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: customGradient ?? (isDarkMode ? AppColors.darkGradient : AppColors.lightGradient),
        ),
        borderRadius: borderRadius ?? BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

// ✅ NEW: Status color helpers
class StatusColors {
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'pending':
        return AppColors.warning;
      case 'cancelled':
        return Colors.grey;
      default:
        return AppColors.info;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.pending;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info;
    }
  }

  static String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending Approval';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }
}

// ✅ NEW: Designation icon helpers
class DesignationIcons {
  static IconData getDesignationIcon(String designation) {
    String lower = designation.toLowerCase();
    if (lower.contains('foreman') || lower.contains('supervisor')) {
      return Icons.engineering;
    } else if (lower.contains('gardner') || lower.contains('garden')) {
      return Icons.grass;
    } else if (lower.contains('driver')) {
      return Icons.local_shipping;
    } else if (lower.contains('security') || lower.contains('guard')) {
      return Icons.security;
    } else if (lower.contains('cleaner') || lower.contains('cleaning')) {
      return Icons.cleaning_services;
    } else if (lower.contains('maintenance')) {
      return Icons.build;
    } else if (lower.contains('electrician')) {
      return Icons.electrical_services;
    } else if (lower.contains('plumber')) {
      return Icons.plumbing;
    } else if (lower.contains('carpenter')) {
      return Icons.carpenter;
    } else if (lower.contains('painter')) {
      return Icons.format_paint;
    } else if (lower.contains('welder')) {
      return Icons.settings_input_component;
    } else {
      return Icons.person;
    }
  }

  static Color getDesignationColor(String designation) {
    String lower = designation.toLowerCase();
    if (lower.contains('foreman') || lower.contains('supervisor')) {
      return Colors.orange;
    } else if (lower.contains('gardner') || lower.contains('garden')) {
      return Colors.green;
    } else if (lower.contains('driver')) {
      return Colors.blue;
    } else if (lower.contains('security') || lower.contains('guard')) {
      return Colors.red;
    } else if (lower.contains('cleaner') || lower.contains('cleaning')) {
      return Colors.purple;
    } else if (lower.contains('maintenance')) {
      return Colors.brown;
    } else if (lower.contains('electrician')) {
      return Colors.yellow[700]!;
    } else if (lower.contains('plumber')) {
      return Colors.cyan;
    } else {
      return Colors.grey;
    }
  }
}