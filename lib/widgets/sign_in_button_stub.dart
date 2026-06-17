import 'package:flutter/material.dart';

Widget buildGoogleSignInButton({required VoidCallback onPressed}) {
  return GestureDetector(
    onTap: onPressed,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.25),
            blurRadius: 32,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/google.png', height: 26),
          const SizedBox(width: 14),
          const Text(
            'Continuar con Google',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    ),
  );
}
