# AURA

Premium music player built with Flutter. iOS is the primary target; the
codebase is kept portable so Android can be supported later.

> Status: **Phase 4 — Home and navigation.** Tabs (Home, Search, Library)
> work; Home shows clearly labelled **demo data**. No audio playback yet.
> Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) ·
> Design system: [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md).

## Requirements

| Tool | Version used | Notes |
|------|--------------|-------|
| Flutter | 3.47.7 (stable) | `flutter --version` |
| Dart | 3.13.5 | bundled with Flutter |
| Xcode | — | **Required for iOS builds. macOS only.** |
| Android SDK | — | Not installed yet; needed later for Android |
| Visual Studio Build Tools | 2026 | For the Windows desktop target |

## Getting started

```bash
flutter pub get
```

### Run

Web (Chrome):

```bash
flutter run -d chrome
```

Windows desktop:

```bash
flutter run -d windows
```

iOS (requires a Mac with Xcode):

```bash
flutter run -d ios
```

Web and Windows are development stand-ins only. iOS-specific behaviour
(audio session, background playback, lock-screen controls) can only be
verified on a Mac with Xcode, and some of it only on a physical iPhone.

## Quality checks

```bash
dart format lib test
flutter analyze
flutter test
```

## Project identifiers

- Dart package name: `music_app` (technical, not user-visible)
- Display name: `AURA`
- iOS bundle ID / Android application ID: `com.example.*` placeholders —
  must be replaced with a real reverse-domain ID before any TestFlight or
  store build.

## Secrets

Never commit API keys, tokens, signing certificates or `.env` files.
See `.gitignore`.
