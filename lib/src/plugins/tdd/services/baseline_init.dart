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
import '../models/cycle_entry.dart' show formatPhaseDuration;
import '../models/tdd_profile.dart';
import 'pub_pre_resolver.dart';

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
  /// Issue #1653: the pre-resolver pays the cold dependency-resolution
  /// cost at init time when the dependency writers newly inject entries.
  /// Injectable so unit tests never spawn a real `pub get`.
  const TddBaselineInit({this.preResolver = const PubPreResolver()});

  final PubPreResolver preResolver;

  /// Ensure the TDD baseline exists under [projectRoot].
  ///
  /// [force] / [skin] mirror the `zfa tdd init` flags; the entry
  /// preflight always passes both false (idempotent, opt-out of skin).
  /// [mutation] is the issue-#1653 opt-in: when true the dev-deps writer
  /// also injects `mutation_test: ^1.8.0` (the `tdd verify` lane's tool).
  /// DEFAULT FALSE — the analyzer-versioned graph deferred a multi-minute
  /// cold cost into every fresh project's first analyze-class pass.
  /// [onLine] receives the human-facing ✓ lines (byte-identical to the
  /// pre-#1528 `zfa tdd init` stdout); [onError] receives the ✗ writer
  /// lines (stdout for the command, pre-#1528, so a CI log parser keeps
  /// the diagnosis); [onMisfire] receives the trailing misfire block
  /// (stderr for the command, pre-#1528 — the only part that ever went
  /// there). When omitted, both fall back to [onLine]'s sink — which is
  /// what the entry preflight relies on (one sink for all three).
  Future<BaselineInitReport> ensure({
    required String projectRoot,
    bool force = false,
    bool skin = false,
    bool mutation = false,
    void Function(String line)? onLine,
    void Function(String line)? onError,
    void Function(String line)? onMisfire,
  }) async {
    final log = onLine ?? (_) {};
    final logError = onError ?? log;
    final logMisfire = onMisfire ?? logError;
    final cwd = projectRoot;
    final isFlutter = await _isFlutterProject(cwd);

    log(
      'zfa tdd init: ensuring TDD baseline in $cwd '
      '(${isFlutter ? "Flutter" : "Dart"})'
      '${force ? " (force: overwrite on content mismatch)" : ""}',
    );

    final failures = <String>[];
    final created = <String>[];
    // Issue #1653: what the dependency writers newly injected — the
    // pre-resolve fires only when something was added (an idempotent pass
    // that added nothing must not re-pay the resolution cost).
    var devDepsAdded = 0;
    var appDepsAdded = 0;
    var skinDepsAdded = 0;

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
          appDepsAdded = added.length;
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
        // Issue #1653: mutation_test is OPT-IN — `--mutation` on
        // `zfa tdd init`, never the default baseline, never the #1528
        // preflight's auto-init.
        includeMutationTest: mutation,
      ).ensure(cwd);
      if (added.isEmpty) {
        log('   ✓ pubspec.yaml dev_dependencies (already complete)');
      } else {
        log('   ✓ pubspec.yaml dev_dependencies (added: ${added.join(', ')})');
        created.add('pubspec.yaml dev_dependencies (${added.join(', ')})');
        devDepsAdded = added.length;
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
            skinDepsAdded = added.length;
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

    // Issue #1653 (Ask 2): pay the cold-resolution cost at INIT time. Any
    // newly injected dependency entry (dev_dependencies, the #1349 app
    // module deps, the #1260 skin dep) enlarges the package config, and the
    // FIRST analyze-class pass over it pays a multi-minute cold cost —
    // measured at 8m32s when mutation_test's analyzer-versioned graph was
    // still unconditional. Init spawns the project's resolver itself and
    // prints the elapsed time, so the cost is paid here, loudly, instead of
    // surfacing as a surprise inside the first refactor of a `zfa tdd run`.
    // An idempotent pass that added NOTHING skips the resolver: no repeated
    // network/cache cost on every init.
    if (devDepsAdded > 0 || appDepsAdded > 0 || skinDepsAdded > 0) {
      final report = await preResolver.resolve(
        projectRoot: cwd,
        isFlutter: isFlutter,
      );
      if (report.unavailable) {
        // The resolver binary could not even start (e.g. no `flutter` on
        // PATH for a Flutter target) — nothing was PROVEN broken. Warn
        // loudly; never misfire on it (fail-closed would be dishonest
        // here), but never let the skip be silent either.
        log(
          '   ⚠ pub resolution skipped: ${report.unavailableReason} — the '
          'first analyze-class pass will pay the cold resolution '
          '(issue #1653)',
        );
      } else if (!report.ok) {
        final tail = report.output.length > 800
            ? report.output.substring(report.output.length - 800)
            : report.output;
        logError(
          '   ✗ pub resolution (${report.binary} '
          '${report.args.join(' ')}): exited '
          '${report.exitCode ?? 'killed at the deadline'} — the injected '
          'baseline does not resolve (issue #1653)',
        );
        logError(tail);
        failures.add(
          'pub_pre_resolver: ${report.binary} pub get exited '
          '${report.exitCode ?? 'timed out'} — resolve the dependency '
          'failure and re-run `zfa tdd init`',
        );
      } else {
        log(
          '   ✓ pub resolution: ${report.binary} '
          '${report.args.join(' ')} '
          '(${formatPhaseDuration(report.elapsed!)}) — cold cost paid '
          'at init time (issue #1653)',
        );
      }
    }

    if (failures.isNotEmpty) {
      logMisfire(
        '\nzfa tdd init: misfire — ${failures.length} writer(s) failed. '
        'Resolve the failures above and re-run `zfa tdd init`.',
      );
      for (final f in failures) {
        logMisfire('  - $f');
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
