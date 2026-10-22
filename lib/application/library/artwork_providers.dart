import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Turns a stored artwork reference (e.g. `library:artwork/x.jpg`) into an
/// absolute file path; null when it cannot be resolved (e.g. on the web).
final artworkPathResolverProvider = Provider<String? Function(Uri artwork)>(
  (ref) =>
      (_) => null,
);
