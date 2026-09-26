import 'package:flutter/material.dart';

/// Spacing, radii, motion, and layout breakpoints for Verifi.
///
/// Prefer these tokens over hard-coded numbers so screens stay consistent
/// and text-scaling-friendly.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  /// Standard horizontal page inset on phones.
  static const double pageX = 20;

  /// Standard vertical padding under status/app bars.
  static const double pageTop = 16;

  /// Comfortable bottom inset above the nav bar content.
  static const double pageBottom = 24;

  /// Minimum interactive target (Material / WCAG).
  static const double touchTarget = 48;

  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(
    pageX,
    pageTop,
    pageX,
    pageBottom,
  );

  static const EdgeInsets pagePaddingTight = EdgeInsets.fromLTRB(
    pageX,
    12,
    pageX,
    pageBottom,
  );
}

class AppRadii {
  AppRadii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
}

class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
}

class AppBreakpoints {
  AppBreakpoints._();

  /// Compact phones.
  static const double compact = 400;

  /// Switch to navigation rail / split-friendly layout.
  static const double medium = 600;

  /// Prefer dual-pane / wider content.
  static const double expanded = 840;

  /// Max readable content width on large screens.
  static const double contentMax = 720;
}

/// Centers [child] and caps its width on large screens.
class AdaptiveContent extends StatelessWidget {
  const AdaptiveContent({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.contentMax,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, maxWidth)
            : maxWidth;

        Widget content = SizedBox(
          width: width,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          child: child,
        );

        if (padding != null) {
          content = Padding(padding: padding!, child: content);
        }

        return Align(alignment: Alignment.topCenter, child: content);
      },
    );
  }
}
