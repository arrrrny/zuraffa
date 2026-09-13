/// `TddBaselineInit` — the ONE idempotent baseline-ensuring writer
/// sequence shared by `zfa tdd init` and the issue-#1528 entry preflight
/// (`zfa tdd run` / `zfa tdd gen`).
///
/// Extracted VERBATIM from `InitCommand._run` (spec 1528, FR-003): the
/// profile, `dart_test.yaml`, the spec template, the smoke test, the
/// Flutter app module + its runtime deps, the testing dev_dependencies,
/// and the opt-in skin dependency — each writer skip-if-present, each
/// failure collected. The observable `zfa tdd init` output (header, ✓/✗
/// lines, misfire block, ensured line) is byte-identical through the
/// injected sinks; the same `StateError` misfire throw is preserved
/// (errors-are-an-API, VISION §4).
///
/// The preflight consumes the same sequence in non-force, non-skin mode
/// and reads [BaselineInitReport.created] to log what it created; the
/// caller fail-closes when the sequence throws.
library;

import 'dart:io';

import 'package:yaml/yaml.dart';

import '../../../cli/writers/tdd/app_module_writer.dart';
import '../../../cli/writers/tdd/dart_test_yaml_writer.dart';
import '../../../cli/writers/tdd/pubspec_app_dependencies_patcher.dart';
import '../../../cli/writers/tdd/pubspec_dev_dependencies_patcher.dart';
import '../../../cli/writers/tdd/pubspec_skin_dependency_patcher.dart';
import '../../../cli/writers/tdd/smoke_test_writer.dart';
import '../../../cli/writers/tdd/spec_template_writer.dart';
import '../../../cli/writers/tdd/tdd_profile_writer.dart';
import '../models/tdd_profile.dart';

/// What one `ensure()` pass did: every artifact newly written or patched
/// (human-readable labels, for the preflight's created-artifact log) and
/// every writer failure (`<writer>: <message>`).
class BaselineInitReport {
  final List<String> created;
  final List<String> failures;

  const BaselineInitReport({required this.created, required this.failures});

  bool get ok => failures.isEmpty;
}

/// The misfire throw: a [StateError] (the pre-#1528 contract — the CLI
/// runner's generic handler and any `on StateError` catch keep working)
/// that ALSO carries the structured writer-failure list, so the #1528
/// preflight can journal violations without re-parsing the message.
class BaselineInitMisfire extends StateError {
  BaselineInitMisfire(super.message, {required this.failures});

  final List<String> failures;
}

class TddBaselineInit {
  const TddBaselineInit();

  /// Ensure the TDD baseline exists under [projectRoot].
  ///
  /// [force] / [skin] mirror the `zfa tdd init` flags; the entry
  /// preflight always passes both false (idempotent, opt-out of skin).
  /// [onLine] receives the human-facing ✓ lines (byte-identical to the
  /// pre-#1528 `zfa tdd init` stdout); [onError] receives the ✗ lines
  /// and the misfire block (stderr for the command, the same sink for
  /// the preflight).
  Future<BaselineInitReport> ensure({
    required String projectRoot,
    bool force = false,
    bool skin = false,
    void Function(String line)? onLine,
    void Function(String line)? onError,
  }) async {
    final log = onLine ?? (_) {};
    final logError = onError ?? log;
    final cwd = projectRoot;
    final isFlutter = await _isFlutterProject(cwd);

    log(
      'zfa tdd init: ensuring TDD baseline in $cwd '
      '(${isFlutter ? "Flutter" : "Dart"})'
      '${force ? " (force: overwrite on content mismatch)" : ""}',
    );

    final failures = <String>[];
    final created = <String>[];

    try {
      final written = await TddProfileWriter(
        profile: isFlutter ? TddProfile.flutter : TddProfile.dart,
      ).write(cwd, force: force);
      if (written == null) {
        log('   ✓ .specify/memory/tdd-profile.md (already present)');
      } else {
        log('   ✓ .specify/memory/tdd-profile.md (created)');
        created.add('.specify/memory/tdd-profile.md');
      }
    } on StateError catch (e) {
      logError('   ✗ .specify/memory/tdd-profile.md: $e');
      failures.add('tdd_profile_writer: $e');
    }

    try {
      final written = await const DartTestYamlWriter().write(cwd);
      if (written == null) {
        log('   ✓ dart_test.yaml (already present)');
      } else {
        log('   ✓ dart_test.yaml (created)');
        created.add('dart_test.yaml');
      }
    } on StateError catch (e) {
      logError('   ✗ dart_test.yaml: $e');
      failures.add('dart_test_yaml_writer: $e');
    }

    // Issue #1480: the wiring verb propagates the AUTHORING grammar —
    // the spec template a spec-kit project actually receives must carry
    // the zuraffa-1.0 sections (`## Layer Contracts`, `traces:`) or every
    // spec-kit-authored spec dead-ends the unit lane. Absent → install;
    // grammarless (stock spec-kit scaffold) → replace with a loud
    // notice; already pinned to a known zuraffa version → untouched.
    try {
      final result = await const SpecTemplateWriter().write(cwd);
      if (result == null) {
        log('   ✓ .specify/templates/spec-template.md (already current)');
      } else {
        switch (result.action) {
          case SpecTemplateWriteAction.created:
            log(
              '   ✓ .specify/templates/spec-template.md (created: the '
              'zuraffa-1.0 authoring grammar)',
            );
            created.add('.specify/templates/spec-template.md');
          case SpecTemplateWriteAction.replaced:
            log(
              '   ✓ .specify/templates/spec-template.md (REPLACED: the '
              'previous template pinned no zuraffa template version and '
              'carried none of the authoring grammar — specs authored '
              'from it dead-ended the unit lane; issue #1480)',
            );
            created.add('.specify/templates/spec-template.md');
        }
      }
    } on StateError catch (e) {
      logError('   ✗ .specify/templates/spec-template.md: $e');
      failures.add('spec_template_writer: $e');
    }

    final appName = _deriveAppName(cwd);
    try {
      // Issue #664: gate the smoke-test flavor behind the project flavor —
      // a pure Dart package must not receive `package:flutter_test` imports
      // it cannot resolve.
      final written = await SmokeTestWriter(
        isFlutter: isFlutter,
      ).write(cwd, appName);
      if (written == null) {
        log('   ✓ test/bootstrap_smoke_test.dart (already present)');
      } else {
        log('   ✓ test/bootstrap_smoke_test.dart (created)');
        created.add('test/bootstrap_smoke_test.dart');
      }
    } on StateError catch (e) {
      logError('   ✗ test/bootstrap_smoke_test.dart: $e');
      failures.add('smoke_test_writer: $e');
    }

    // Issue #626: in a Flutter project the smoke test asserts the
    // zfa-generated app module (<AppName>Container in lib/app.dart), so
    // the baseline is only green when the module exists. Skip-if-exists —
    // existing user content is never touched (FR-008).
    if (isFlutter) {
      try {
        final written = await const AppModuleWriter(
          isFlutter: true,
        ).write(cwd, appName);
        if (written == null) {
          log('   ✓ lib/app.dart (already present)');
        } else {
          log('   ✓ lib/app.dart (created)');
          created.add('lib/app.dart');
        }
      } on StateError catch (e) {
        logError('   ✗ lib/app.dart: $e');
        failures.add('app_module_writer: $e');
      }

      // Issue #1349: the day-zero app module imports
      // `package:zuraffa_flutter/zuraffa_flutter.dart` and exposes a
      // `GetIt` registry — but init only self-healed the TESTING
      // dev_dependencies below. The runtime deps the generated module
      // requires were never declared, so every test failed to compile
      // and the promised day-zero baseline was red out of the box.
      // Same self-heal pass as the dev_dependencies patcher: ensure the
      // deps under `dependencies:` (runtime, not dev) — idempotent,
      // hand-edit preserving, comment/formatting safe.
      try {
        final added = await const PubspecAppDependenciesPatcher().ensure(cwd);
        if (added.isEmpty) {
          log('   ✓ pubspec.yaml dependencies (app module: already declared)');
        } else {
          log(
            '   ✓ pubspec.yaml dependencies (app module: added: '
            '${added.join(', ')})',
          );
          created.add(
            'pubspec.yaml dependencies (app module: ${added.join(', ')})',
          );
        }
      } on FormatException catch (e) {
        logError('   ✗ pubspec.yaml dependencies (app module): $e');
        failures.add('pubspec_app_dependencies_patcher: $e');
      } on StateError catch (e) {
        logError('   ✗ pubspec.yaml dependencies (app module): $e');
        failures.add('pubspec_app_dependencies_patcher: $e');
      } on UnsupportedError catch (e) {
        logError('   ✗ pubspec.yaml dependencies (app module): $e');
        failures.add('pubspec_app_dependencies_patcher: $e');
      }
    }

    try {
      final added = await PubspecDevDependenciesPatcher(
        isFlutter: isFlutter,
      ).ensure(cwd);
      if (added.isEmpty) {
        log('   ✓ pubspec.yaml dev_dependencies (already complete)');
      } else {
        log('   ✓ pubspec.yaml dev_dependencies (added: ${added.join(', ')})');
        created.add('pubspec.yaml dev_dependencies (${added.join(', ')})');
      }
    } on FormatException catch (e) {
      logError('   ✗ pubspec.yaml dev_dependencies: $e');
      failures.add('pubspec_dev_dependencies_patcher: $e');
    } on StateError catch (e) {
      logError('   ✗ pubspec.yaml dev_dependencies: $e');
      failures.add('pubspec_dev_dependencies_patcher: $e');
    }

    // Issue #1260 remediation 2: the skin lane's certified vocabulary is
    // opt-in. On a pure-Dart target the opt-in is a LOUD misfire (the
    // certified package needs the Flutter SDK — a silently corrupted
    // pubspec is the dishonest outcome), not a warning.
    if (skin) {
      if (!isFlutter) {
        final message =
            '--skin requires a Flutter project: zuraffa_ui (the skin '
            'lane\'s certified vocabulary) is a Flutter SDK package and '
            'cannot resolve in a pure-Dart target.';
        logError('   ✗ pubspec.yaml dependencies (skin): $message');
        failures.add('pubspec_skin_dependency_patcher: $message');
      } else {
        try {
          final added = await const PubspecSkinDependencyPatcher().ensure(cwd);
          if (added.isEmpty) {
            log(
              '   ✓ pubspec.yaml dependencies (skin: zuraffa_ui already '
              'declared)',
            );
          } else {
            log('   ✓ pubspec.yaml dependencies (added: ${added.join(', ')})');
            created.add('pubspec.yaml dependencies (${added.join(', ')})');
          }
        } on FormatException catch (e) {
          logError('   ✗ pubspec.yaml dependencies (skin): $e');
          failures.add('pubspec_skin_dependency_patcher: $e');
        } on StateError catch (e) {
          logError('   ✗ pubspec.yaml dependencies (skin): $e');
          failures.add('pubspec_skin_dependency_patcher: $e');
        } on UnsupportedError catch (e) {
          logError('   ✗ pubspec.yaml dependencies (skin): $e');
          failures.add('pubspec_skin_dependency_patcher: $e');
        }
      }
    }

    if (failures.isNotEmpty) {
      logError(
        '\nzfa tdd init: misfire — ${failures.length} writer(s) failed. '
        'Resolve the failures above and re-run `zfa tdd init`.',
      );
      for (final f in failures) {
        logError('  - $f');
      }
      // Errors-are-an-API (VISION §4): the thrown message carries the
      // failure details too, so captured channels (wrappers, JSON
      // envelopes, `zfa tdd run` step logs) name the exact remedy without
      // needing the raw stderr transcript.
      throw BaselineInitMisfire(
        'zfa tdd init: misfire — ${failures.length} writer(s) failed: '
        '${failures.join(' | ')}',
        failures: List.unmodifiable(failures),
      );
    }

    log(
      '\nTDD baseline ensured. Run `flutter test` (or '
      '`dart test`) to confirm a green baseline.',
    );
    return BaselineInitReport(
      created: List.unmodifiable(created),
      failures: const [],
    );
  }

  Future<bool> _isFlutterProject(String cwd) async {
    final pubspec = File('$cwd/pubspec.yaml');
    if (!await pubspec.exists()) return false;
    dynamic doc;
    try {
      doc = loadYaml(await pubspec.readAsString());
    } on YamlException catch (e) {
      throw FormatException(
        'pubspec.yaml at ${pubspec.path} is not valid YAML: $e',
      );
    }
    if (doc is! YamlMap) {
      throw FormatException(
        'pubspec.yaml at ${pubspec.path} did not parse to a Map',
      );
    }
    final dependencies = doc['dependencies'];
    if (dependencies == null) return false;
    if (dependencies is! YamlMap) {
      throw FormatException(
        'pubspec.yaml at ${pubspec.path} has a non-map dependencies value',
      );
    }
    return dependencies.containsKey('flutter');
  }

  String _deriveAppName(String cwd) {
    final base = cwd.split(Platform.pathSeparator).last;
    return base.isEmpty ? 'myapp' : base;
  }
}
