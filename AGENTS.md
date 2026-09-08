# AGENTS.md

Flutter mobile app (Android-only) for "Forest — Microfinanzas", a microfinance/banking UI for a student project (SI2). Talks to a FastAPI backend for auth.

## Commands

- `flutter run -d <device-id>` — run (use `flutter devices` to list; physical Android device needs USB debugging)
- `flutter analyze` — lint/static analysis
- `flutter test` — run tests
- `flutter pub get` — after editing `pubspec.yaml`

## Known broken things (do not trust blindly)

- `test/widget_test.dart` is the untouched Flutter template: it imports `package:si2_mobile_app/main.dart` (real package name is `forest_microfinance`, see `pubspec.yaml`) and references `MyApp` (real root widget is `ForestMicrofinanceApp`). `flutter test` fails out of the box — fix or replace the test rather than assuming regressions.
- `lib/services/mock_auth_service.dart` imports `package:http` but `http` is NOT declared in `pubspec.yaml` (resolves only as a transitive dep). `flutter analyze` flags it. Add it to `dependencies` when touching this file.

## Backend / auth

- `AuthService` (despite the file name `mock_auth_service.dart`, it is the REAL service) calls `http://10.0.2.2:8000/api/v1/auth/login` — `10.0.2.2` is the Android-emulator alias for the host machine's localhost. Backend must be running (Docker) or login fails with a connection error.
- On a physical device, `10.0.2.2` does NOT work — the host PC's LAN IP must be hardcoded in `AuthService.baseUrl` instead.
- Login uses OAuth2 form-encoded (`username`/`password`), 5s timeout; JWT is kept in a static in-memory field (`AuthService.tokenJWT`), not persisted.

## Theming (dual system — easy to get wrong)

There are two parallel theming mechanisms:
1. `MaterialApp` uses `AppTheme.lightTheme`/`darkTheme` (`lib/core/app_theme.dart`) driven by `ThemeProvider` (package:provider, in-memory only, dark by default, not persisted).
2. Screens also manually read `isDark` from `ThemeProvider` and pick from static palettes in `lib/core/theme/app_colors.dart` (e.g. `AppColors.darkCard` vs `AppColors.lightCard`).

Warning: `AppColors` ends with un-suffixed "compatibility aliases" (`background`, `surface`, `card`…) that are hard-bound to the DARK values. Do not use bare aliases in screens that must support light mode — use the explicit dark*/light* pairs like existing screens do.

## Conventions

- UI copy, labels, and user-facing error messages are in Spanish (es-419). Keep new UI strings in Spanish.
- Code comments are mixed Spanish/English; either is accepted.
- Navigation: only `/login` and `/dashboard` are registered routes; the main screen is an `IndexedStack` of 4 screens (`lib/screens/main_navigation_screen.dart`) — new tabs are added there.
- Fonts come from `google_fonts` (DM Sans / Manrope) applied per-widget, not via a global text theme only.

## Android specifics

- `android/app/build.gradle.kts` hardcodes `compileSdk = 37` and `targetSdk = 37` (deliberate change away from `flutter.compileSdkVersion`; see comments there). `applicationId`: `com.cooperativa.app.si2_mobile_app`.
- Biometrics via `local_auth` (`biometricOnly: true`); `USE_BIOMETRIC` permission is already in `AndroidManifest.xml`. Biometric login only reuses an in-memory token — it cannot restore a session after app restart.

## Repo state

- Several declared dependencies are currently unused (`camera`, `geolocator`, `flutter_animate`, `fl_chart`, `cached_network_image`, `intl`) — placeholders for future features; don't remove them without asking.
- Default branch: `main`. Commit style: conventional commits in Spanish or English (`feat: ...`).
