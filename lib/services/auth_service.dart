import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StreamController<AuthResponse> _authController =
      StreamController<AuthResponse>.broadcast();

  Stream<AuthResponse> get authResponseStream => _authController.stream;

  String? _rawNonce;
  String? _hashedNonce;

  String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> init() async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    if (webClientId == null || webClientId.isEmpty) {
      throw AuthException('GOOGLE_WEB_CLIENT_ID no está configurado en .env');
    }

    _rawNonce = _generateNonce();
    _hashedNonce = _sha256ofString(_rawNonce!);

    if (kIsWeb) {
      await GoogleSignIn.instance.initialize(
        clientId: webClientId,
        nonce: _hashedNonce,
      );
      _setupWebAuthListener();
    } else {
      await GoogleSignIn.instance.initialize(
        serverClientId: webClientId,
        nonce: _hashedNonce,
      );
    }
  }

  void _setupWebAuthListener() {
    GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _handleWebSignIn(event.user);
      }
    });
  }

  Future<void> _handleWebSignIn(GoogleSignInAccount user) async {
    try {
      final googleAuth = user.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw AuthException('No se pudo obtener el ID Token de Google');
      }

      final authz = await user.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authz.accessToken,
        nonce: _rawNonce,
      );

      _authController.add(response);
    } catch (e) {
      _authController.addError(e);
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw AuthException('No se pudo obtener el ID Token de Google');
    }

    final authz = await googleUser.authorizationClient.authorizeScopes([
      'email',
      'profile',
    ]);

    return _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authz.accessToken,
      nonce: _rawNonce,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    await GoogleSignIn.instance.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;

  void dispose() {
    _authController.close();
  }
}
