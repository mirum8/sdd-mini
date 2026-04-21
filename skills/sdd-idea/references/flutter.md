---
name: flutter
summary: Flutter + Riverpod + sqflite. Mobile apps for iOS/Android. SDD does not automate the scaffold — Android SDK / Xcode must be on the host.
impl_mode: handoff
---

## When to pick this stack

Pick this for a mobile app: an offline-first tracker, a gym-set logger, travel notes with camera / GPS, anything where a web page wouldn't cut it (no push, cold-start lag, mobile UX mismatch). Flutter gives a single codebase for iOS + Android, Riverpod is a modern state-management choice, and sqflite provides local SQLite for offline storage.

## Minimal MVP tech

- Flutter 3.24+ (Dart 3.5+)
- `flutter_riverpod: ^2.5` — state management
- `sqflite: ^2.3` — local SQLite
- `path_provider: ^2.1` — device filesystem paths
- `go_router: ^14.0` — navigation (when there are more than 3 screens)
- `flutter_test` (built-in) — unit + widget tests
- `integration_test` (built-in) — e2e on device/emulator
- Android Studio or Xcode — to build and run on a simulator

## Phase 1 recipe (handoff)

SDD does not automate Flutter (requires Android SDK / Xcode, which is outside the Docker + git bar). Claude builds Phase 1 from this recipe — the commands below run on the host, either manually or via a Claude session in the same directory.

**What Phase 1 must produce:**

1. `flutter create --org com.<your-handle> --project-name <slug> .` in an empty folder.
2. Add the deps listed above to `pubspec.yaml`, then `flutter pub get`.
3. Arrange the code:

        lib/
        ├── main.dart            — entry point + ProviderScope
        ├── app.dart             — MaterialApp + router
        ├── router.dart          — go_router routes
        ├── features/
        │   └── home/
        │       ├── home_screen.dart
        │       └── home_providers.dart
        ├── data/
        │   └── database.dart    — sqflite initialization
        └── core/
            └── theme.dart       — Material 3 theme

4. `main.dart`:

        void main() => runApp(const ProviderScope(child: MyApp()));

5. Home screen shows the project name as a heading and a placeholder for the first feature. This delivers the emotional hook early.
6. First tests:
   - `test/features/home/home_screen_test.dart` — widget test that the heading renders.
   - `test/data/database_test.dart` — that the DB opens and creates the expected table.

### Running

- Android: `flutter run -d emulator-5554` (start Android Studio → AVD Manager first).
- iOS: `flutter run -d "iPhone 15"` (Xcode required).
- Hot reload: `r` in the `flutter run` terminal.

### Host environment

- `~/Library/Android/sdk` (macOS) or `$ANDROID_HOME` — Android SDK.
- `xcode-select --install` + a simulator from Xcode — for iOS.
- `flutter doctor` — reports what's missing.

## How to test

- All tests: `flutter test`
- Coverage: `flutter test --coverage` → `coverage/lcov.info`
- Readable report: `genhtml coverage/lcov.info -o coverage/html` (requires `lcov`)
- Threshold: 100% on changed files under `lib/`; omit `main.dart`, `app.dart`, generated `*.g.dart`.

Covered:
- Every Riverpod notifier/provider — states, edge cases.
- Every screen widget — widget test that key elements render.
- Every DB function in `data/`.

Not covered:
- `main.dart`, `app.dart` — boot and router.
- Generated files (`*.g.dart`, `*.freezed.dart`).
- Pure styling widgets without logic.

## Do not bring in

- React Native, Ionic, Xamarin — outside this skill's scope.
- Firebase (Auth, Firestore, Functions) at MVP — vendor lock-in plus setup overhead.
- GetX, BLoC — Riverpod covers both use cases.
- Hive / Isar instead of sqflite — SQLite is more portable and Claude has more experience with it.
- Prod signing, CI/CD, TestFlight — MVP lives on the emulator/simulator and the dev device.
- Custom theming before base UX works — start from Material 3 defaults.
