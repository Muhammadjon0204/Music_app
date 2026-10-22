# AURA

[![CI](https://github.com/Muhammadjon0204/Music_app/actions/workflows/ci.yml/badge.svg)](https://github.com/Muhammadjon0204/Music_app/actions/workflows/ci.yml)

Premium music player built with Flutter. iOS is the primary target; the
codebase is kept portable so Android can be supported later.

> Status: **Phase 5 — Player UI.** Tabs, Home, mini player, Now Playing
> and the queue work. Home shows clearly labelled **demo data**, and the
> player is a **silent demo player** ("Демо · без звука") until the audio
> engine lands in Phase 6.
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

The test suite covers:

| Folder | What it guards |
|---|---|
| `test/architecture/` | Layer boundaries, no hard-coded colors, demo data wired only in `main.dart` |
| `test/domain/`, `test/core/`, `test/application/` | Models, invariants, config, debounce, error handling |
| `test/presentation/` | Components, screens, navigation, contrast, localization |
| `test/stress/` | Every screen on 6 devices (incl. landscape, iPad) × 4 iOS text sizes up to ×3.0 with safe areas; edge cases; VoiceOver labels, 44 pt tap targets and rendered text contrast; Reduce Motion; iOS swipe-back |

## Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push to
`main` and every pull request:

1. **Linux** — format check, `flutter analyze`, all tests in random order.
2. **macOS 26 / Xcode** — `flutter build ios --simulator` on a real Mac
   runner, so iOS build breakages show up without a local Mac.

Flutter is installed from the official repository at the pinned version;
third-party actions are pinned by commit SHA. The simulator build needs no
code signing, so the workflow uses no secrets. It does **not** replace
testing on a physical iPhone (background audio, lock screen, Bluetooth).

## Project identifiers

- Dart package name: `music_app` (technical, not user-visible)
- Display name: `AURA`
- iOS bundle ID / Android application ID: `com.example.*` placeholders —
  must be replaced with a real reverse-domain ID before any TestFlight or
  store build.

## Secrets

Never commit API keys, tokens, signing certificates or `.env` files.
See `.gitignore`.
