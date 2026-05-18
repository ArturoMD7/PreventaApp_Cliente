import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../widgets/sign_in_button.dart';
import 'vinculacion_screen.dart';
import 'completar_perfil_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  StreamSubscription<AuthResponse>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      await _authService.init();
      if (kIsWeb) {
        _authSubscription = _authService.authResponseStream.listen(
          _onAuthSuccess,
          onError: _onAuthError,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al inicializar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authService.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (kIsWeb) {
      setState(() => _isLoading = true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      await _navigateAfterSignIn();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateAfterSignIn() async {
    final tienePerfil = await _dataService.tienePerfil();
    final tienePerfilLocal = await _dataService.getPerfilLocal() != null;
    if (!mounted) return;

    final nav = Navigator.of(context);
    if (!tienePerfil && !tienePerfilLocal) {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const CompletarPerfilScreen()),
      );
    } else {
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => const VinculacionScreen()),
      );
    }
  }

  void _onAuthSuccess(AuthResponse response) {
    if (!mounted) return;
    _navigateAfterSignIn();
  }

  void _onAuthError(Object error) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showError(error);
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error al iniciar sesión: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2540), Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // Subtle, transparent pattern of floating arrows
          Positioned(
            top: 250, right: -40,
            child: Icon(Icons.arrow_upward_rounded, size: 160, color: Colors.white.withValues(alpha: 0.04)),
          ),
          Positioned(
            bottom: -30, right: 30,
            child: Icon(Icons.arrow_circle_up, size: 140, color: Colors.white.withValues(alpha: 0.04)),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo and App Name
                      Column(
                        children: [
                          Image.asset(
                            'assets/logo.png',
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'PreventaApp Cliente',
                            style: TextStyle(
                              fontFamily: 'Roboto', // Modern sans-serif
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Gestión inteligente para tu fuerza de venta, con o sin conexión',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // Tarjeta de Login (Clean white card with soft shadows)
                      Card(
                        elevation: 12,
                        shadowColor: Colors.black.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(
                                child: Text(
                                  'Iniciar sesión o registrarse',
                                  style: TextStyle(
                                    fontSize: 20, 
                                    fontWeight: FontWeight.w800, 
                                    color: Color(0xFF1E3A8A)
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // Iniciar Sesión Button (Google)
                              _isLoading
                                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                                  : buildGoogleSignInButton(
                                      onPressed: _signInWithGoogle,
                                    ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // DEBUG and system status bars (Subtle text at the bottom)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DEBUG',
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: 10, 
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'v1.0.0 (Build 42) - Conectado',
                            style: TextStyle(
                              color: Colors.white70, 
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
