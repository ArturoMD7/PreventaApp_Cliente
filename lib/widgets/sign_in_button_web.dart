import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart';

/// Botón nativo de Google Sign-In para web (GIS).
/// onPressed se ignora porque el botón de Google maneja el clic internamente.
Widget buildGoogleSignInButton({required VoidCallback onPressed}) {
  return renderButton(
    configuration: GSIButtonConfiguration(
      type: GSIButtonType.standard,
      theme: GSIButtonTheme.filledBlue,
      size: GSIButtonSize.large,
      text: GSIButtonText.continueWith,
      shape: GSIButtonShape.pill,
    ),
  );
}
