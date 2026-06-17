import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart';

Widget buildGoogleSignInButton({required VoidCallback onPressed}) {
  return renderButton(
    configuration: GSIButtonConfiguration(
      type: GSIButtonType.standard,
      theme: GSIButtonTheme.outline,
      size: GSIButtonSize.large,
      text: GSIButtonText.continueWith,
      shape: GSIButtonShape.pill,
    ),
  );
}
