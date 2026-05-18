import 'package:flutter/material.dart';

/// Stub para mobile/desktop — botón personalizado que requiere onPressed.
Widget buildGoogleSignInButton({required VoidCallback onPressed}) {
  return SizedBox(
    height: 56,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: Image.asset(
        'assets/google.png',
        height: 24,
      ),
      label: const Text(
        'Continuar con Google',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.grey, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: Colors.white,
      ),
    ),
  );
}
