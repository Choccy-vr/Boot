import 'package:flutter/material.dart';

/// Helper for responsive layout breakpoints and sizing.
class Responsive {
  static const double small = 640;
  static const double medium = 1024;
  static const double large = 1440;

  static bool isSmall(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width < small;
  }

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= small && width < medium;
  }

  static bool isLarge(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= medium && width < large;
  }

  static bool isExtraLarge(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= large;
  }

  static double horizontalPadding(BuildContext context) {
    if (isSmall(context)) return 16;
    if (isMedium(context)) return 24;
    if (isLarge(context)) return 32;
    return 48;
  }

  static double verticalPadding(BuildContext context) {
    if (isSmall(context)) return 16;
    if (isMedium(context)) return 24;
    if (isLarge(context)) return 32;
    return 40;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: horizontalPadding(context),
      vertical: verticalPadding(context),
    );
  }

  static double spacing(BuildContext context) {
    if (isSmall(context)) return 12;
    if (isMedium(context)) return 16;
    return 20;
  }

  static int columnsForWidth({
    required double maxWidth,
    int maxColumns = 3,
    double minTileWidth = 280,
  }) {
    final possible = (maxWidth / minTileWidth).floor();
    if (possible <= 1) return 1;
    return possible.clamp(1, maxColumns);
  }

  static T value<T>({
    required BuildContext context,
    required T smallValue,
    T? mediumValue,
    T? largeValue,
    T? extraLargeValue,
  }) {
    if (isSmall(context)) return smallValue;
    if (isMedium(context)) return mediumValue ?? smallValue;
    if (isLarge(context)) return largeValue ?? mediumValue ?? smallValue;
    return extraLargeValue ?? largeValue ?? mediumValue ?? smallValue;
  }
}
