import 'package:flutter/material.dart';

abstract final class KimjodLayout {
  static const double compactBreakpoint = 380;

  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width <= compactBreakpoint;
  }

  static double gutter(
    BuildContext context, {
    double regular = 24,
    double compact = 16,
  }) {
    return isCompact(context) ? compact : regular;
  }

  static EdgeInsets horizontal(
    BuildContext context, {
    double regular = 24,
    double compact = 16,
    double top = 0,
    double bottom = 0,
  }) {
    final horizontal = gutter(context, regular: regular, compact: compact);
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }
}
