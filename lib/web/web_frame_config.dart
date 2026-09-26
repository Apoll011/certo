import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Whether to show the desktop Chrome iPhone mockup + side guide.
///
/// True for Flutter web on a wide viewport (typical `flutter run -d chrome`).
/// Narrow / mobile browsers get the normal full-bleed app.
bool get shouldUseWebPhoneFrame {
  if (!kIsWeb) return false;
  return true; // final gate is viewport width inside [WebDemoShell]
}

/// Physical-ish iPhone logical size used inside the bezel.
const Size kDemoPhoneSize = Size(390, 844);
