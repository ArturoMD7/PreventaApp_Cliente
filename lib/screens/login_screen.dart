import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../widgets/sign_in_button.dart';
import '../widgets/particle_background.dart';
import 'vinculacion_screen.dart';
import 'completar_perfil_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DataService _dataService = DataService();
  bool _isLoading = false;
  StreamSubscription<AuthResponse>? _authSubscription;

  late AnimationController _animController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _titleOpacity;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _buttonOpacity;
  late Animation<Offset> _buttonSlide;
  late Animation<double> _footerOpacity;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );

    _buttonOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
      ),
    );
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOut),
      ),
    );

    _animController.forward();

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
    _animController.dispose();
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
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0A2540),
                  Color(0xFF1E3A8A),
                  Color(0xFF3B82F6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          const Positioned.fill(child: ParticleBackground()),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    FadeTransition(
                      opacity: _titleOpacity,
                      child: const Text(
                        'PreventaApp Cliente',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    FadeTransition(
                      opacity: _subtitleOpacity,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Tu portal de pedidos y seguimiento de ruta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white60,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 56),

                    SlideTransition(
                      position: _buttonSlide,
                      child: FadeTransition(
                        opacity: _buttonOpacity,
                        child: _isLoading
                            ? const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : kIsWeb
                                ? buildGoogleSignInButton(
                                    onPressed: _signInWithGoogle,
                                  )
                                : GestureDetector(
                                    onTap: _signInWithGoogle,
                                    child: _buildSignInButton(),
                                  ),
                      ),
                    ),

                    const SizedBox(height: 52),

                    FadeTransition(
                      opacity: _footerOpacity,
                      child: Text(
                        'v1.0.0 · Build 42',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton() {
    return Container(
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
    );
  }
}
