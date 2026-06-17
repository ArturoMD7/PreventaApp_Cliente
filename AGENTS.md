# PreventaApp Cliente

## Overview
Flutter mobile/web app for clients/customers of the Preventa platform. Allows customers to browse stores, place orders, track order history, manage their profile, and link to a service provider via QR.

## Tech Stack
- **Flutter** (Dart SDK `^3.7.2`) — cross-platform (Android, iOS, Linux, macOS, Windows, Web)
- **Supabase** (`supabase_flutter: ^2.12.4`) — backend, auth, and real-time data
- **Google OAuth with Web** (`google_sign_in: ^7.2.0`, `google_sign_in_web: ^1.1.0`) — auth with full web platform support (nonce-based)
- **Crypto** (`crypto: ^3.0.3`) — used for PKCE nonce generation in web Google Sign-In
- **Shared Preferences** (`shared_preferences: ^2.5.5`) — local key-value storage for profile data
- **Google Maps / OpenStreetMap** (`flutter_map`, `latlong2`, `geolocator`) — store locator with map
- **PDF + Printing** — order receipt generation
- **Local Notifications** — order status alerts

## Architecture
- **Entry point:** `lib/main.dart` — initializes Supabase, env vars; `_AppEntryPoint` resolves initial route
- **Auth:** `lib/services/auth_service.dart` — Google OAuth with web/native dual path and auth stream
- **Screens:** `lib/screens/` — login, home, stores, order history, profile, completar perfil, vinculacion, map location selector
- **Models:** `lib/models/` — data classes matching Supabase tables (shared schema with PreventaApp)
- **Services:** `lib/services/` — auth, data CRUD, PDF generation (IO/web stubs), notifications
- **Widgets:** `lib/widgets/` — sign-in button with conditional export (native stub vs web GIS button)

## Key Features
- Browse and discover nearby stores on a map
- Place orders with selected stores
- View order history and status
- Profile management and completion
- QR-based provider vinculacion (link to a vendor)
- Cross-platform: works natively on mobile and on the web

## Auth Flow
1. `LoginScreen` → Google Sign-In → checks if user has a profile
2. If no profile → `CompletarPerfilScreen` → then `VinculacionScreen`
3. If profile exists → `VinculacionScreen` (QR link to provider)
4. `_AppEntryPoint` in `main.dart` checks session on app start and routes accordingly
5. Web: uses auth stream listener (`authResponseStream`) for GIS button flow
6. Native: uses direct `signInWithGoogle()` + navigation

## Theme/Colors
- Primary: `#1E3A8A` (deep blue)
- Secondary: `#3B82F6` (bright blue)
- Gradient: `#0A2540` → `#1E3A8A` → `#3B82F6`
- Font: Inter (via Google Fonts)
- Material 3 enabled

## Environment
- Requires `.env` file with `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- Web requires Google Cloud OAuth client ID for redirect

## Commands
```bash
flutter pub get          # Install dependencies
flutter run              # Run on connected device/emulator
flutter run -d chrome    # Run on web
flutter build apk        # Build Android APK
flutter build web        # Build for web deployment
flutter analyze          # Lint/static analysis
```
