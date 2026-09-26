import 'package:flutter/material.dart';

/// Shows a floating snackbar for features that are not built yet.
void showComingSoon(BuildContext context, [String message = 'Coming soon']) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
}
