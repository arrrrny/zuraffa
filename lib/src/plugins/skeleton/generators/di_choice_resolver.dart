/// Resolves `--di auto` against the working project's existing DI config
/// (042, FR-009).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/bone.dart';

/// Resolves a requested `--di` value into a final [DiChoice].
///
/// `mock` and `firebase` resolve directly from the flag. `auto` scans the
/// working project's `pubspec.yaml` and `zfa.yaml` for firebase references:
/// found → `firebase` (`auto-detected`); not found → `mock`
/// (`auto-fallback`).
class DiChoiceResolver {
  /// Resolves [requested] (`mock`, `firebase`, or `auto`) for the project at
  /// [projectRoot].
  ///
  /// Throws [ArgumentError] for values other than the three documented ones.
  DiChoice resolve({required String requested, required String projectRoot}) {
    if (requested == 'auto') {
      final detected = _detectFirebase(projectRoot);
      return DiChoice.auto().resolve(detectedBackend: detected);
    }
    return DiChoice.fromFlag(requested).resolve();
  }

  /// Returns [BoneBackendKind.firebase] when the project's `pubspec.yaml` or
  /// `zfa.yaml` references firebase, otherwise null.
  BoneBackendKind? _detectFirebase(String projectRoot) {
    for (final configName in const ['pubspec.yaml', 'zfa.yaml']) {
      final file = File(p.join(projectRoot, configName));
      if (!file.existsSync()) continue;
      if (file.readAsStringSync().toLowerCase().contains('firebase')) {
        return BoneBackendKind.firebase;
      }
    }
    return null;
  }
}
