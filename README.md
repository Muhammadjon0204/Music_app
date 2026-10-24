# MusicLab

[![CI](https://github.com/Muhammadjon0204/Music_app/actions/workflows/ci.yml/badge.svg)](https://github.com/Muhammadjon0204/Music_app/actions/workflows/ci.yml)

Premium music player built with Flutter. iOS is the primary target; the
codebase is kept portable so Android can be supported later.

> Status: **Phase 15 — Jamendo, second catalog.** Creative Commons music from
> Jamendo's official API joins the online catalog: search and "popular"
> show both catalogs mixed in one list, without provider names; Now
> Playing credits Jamendo with a link to the track's page, as its terms
> require. Needs a Jamendo client ID at build time (see below).
> **Phase 14 — SoundCloud links.** Paste a SoundCloud track,
> playlist or profile link; it plays online in SoundCloud's official
> embedded player inside AURA, with its track list shown in AURA's style.
> Separate from AURA's queue, as SoundCloud's terms require.
> **Phase 13 — History and persistence.** Listening history
> (Library → История, "recently played" on Home), favorites for Audius
> tracks, and the queue restored after a restart, paused where it stopped.
> Online tracks are stored as references only (provider + ID).
> **Phase 12 — Player reliability.** Editable queue (play next,
> play last, remove, drag to reorder, VoiceOver actions), dead tracks
> skipped during auto-advance (bounded, never on network errors), seeks
> while loading kept, retry after a failure.
> **Phase 11 — Audius.** Real online catalog through the official
> Audius API: popular tracks on Home, search next to your library, real
> covers (with mirror fallback), streaming through the same player, and a
> link to each track's Audius page. No keys or secrets; Audius data is
> cached for the session only, as its API terms require.
> **Phase 10 — Provider foundation.** Async stream resolution, buffering
> and mid-stream error states, typed network failures.
> **Phase 8 — Background playback.** Music keeps playing in the
> background and on the lock screen; Control Center, AirPods and headphone
> buttons control it; calls and alarms pause and resume it; unplugging
> headphones pauses it (built and unit-tested; not yet verified on a
> device).
> **Phase 7 — Local library.** Import your own audio files from the
> Files app (copied into the app, deduplicated, tags and cover art read),
> favorites, playlists, albums, artists, sorting and search; the library
> survives restarts. Real playback via just_audio (iOS, Android, web, macOS);
> on Windows/Linux the player runs silently and says so. On the web the
> library lives in memory and offers four generated demo tones instead of
> import. Home shows clearly labelled **demo data** until the library has
> music.
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

Jamendo is enabled only when the build gets its client ID (a public app
identifier, kept out of Git anyway). Copy `dart_defines.example.json` to
`dart_defines.local.json` (ignored by Git), put your ID from
[devportal.jamendo.com](https://devportal.jamendo.com) in it, and add:

```bash
flutter run -d chrome --dart-define-from-file=dart_defines.local.json
```

Windows desktop:

```bash
flutter run -d windows
```

iOS (requires a Mac with Xcode):

```bash
flutter run -d ios
```

On Windows, Flutter needs **Developer Mode** (symlink support) to build
apps that use plugins such as just_audio:

```bash
start ms-settings:developers
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
- Display name: `MusicLab`
- iOS bundle ID / Android application ID: `com.example.*` placeholders —
  must be replaced with a real reverse-domain ID before any TestFlight or
  store build.

## Secrets

Never commit API keys, tokens, signing certificates or `.env` files.
See `.gitignore`.
