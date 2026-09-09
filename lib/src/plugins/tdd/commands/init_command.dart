/// `zfa tdd init` — idempotently ensure the Part-1 TDD environment exists.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../../cli/writers/tdd/app_module_writer.dart';
import '../../../cli/writers/tdd/dart_test_yaml_writer.dart';
import '../../../cli/writers/tdd/pubspec_dev_dependencies_patcher.dart';
import '../../../cli/writers/tdd/pubspec_skin_dependency_patcher.dart';
import '../../../cli/writers/tdd/smoke_test_writer.dart';
import '../../../cli/writers/tdd/tdd_profile_writer.dart';
import '../services/verdict_emitter.dart';
import '../tdd_plugin.dart';
import '../../../core/project/project_root.dart';

class InitCommand extends Command<void> {
  InitCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root to initialize the TDD baseline in. When omitted, the '
          'current working directory is used. Tests pass the temp fixture '
          'root here instead of mutating Directory.current.',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      help:
          'Overwrite existing baseline files whose content differs from what '
          'the writers would generate. Without --force, `zfa tdd init` is '
          'strictly idempotent and refuses to clobber a file that was hand '
          'edited or generated under a different profile (e.g. Dart vs '
          'Flutter). With --force, those files are replaced in place.',
      negatable: false,
    );
    argParser.addFlag(
      'skin',
      help:
          'Opt into the SKIN lane (issue #1260): also adds the skin lane\'s '
          'CERTIFIED dependency — `zuraffa_ui: ^0.1.0`, the identified '
          'Zfa* vocabulary whose ZuraffaApp is the certified app shell — '
          'to the project pubspec under dependencies: (runtime, not dev). '
          'Refuses loudly on pure-Dart targets (zuraffa_ui is a Flutter '
          'SDK package).',
      negatable: false,
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'init';

  @override
  String get description =>
      'Idempotently ensure the TDD baseline exists in the current project '
      '(test/, dart_test.yaml, .specify/memory/tdd-profile.md, testing '
      'dev_dependencies).';

  @override
  String get invocation => 'zfa tdd init';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    // Prefer an explicit --project root so the command never depends on the
    // process-global Directory.current. Falls back to CWD for real CLI use.
    final projectFlag = argResults?['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find(anchorDir: 'specs');
    final isFlutter = await _isFlutterProject(cwd);
    final force = argResults?['force'] == true;
    // Issue #1260 remediation 2: skin-lane opt-in — the certified
    // dependency is added to the project's dependencies: (runtime).
    final skin = argResults?['skin'] == true;

    stdout.writeln(
      'zfa tdd init: ensuring TDD baseline in $cwd '
      '(${isFlutter ? "Flutter" : "Dart"})'
      '${force ? " (force: overwrite on content mismatch)" : ""}',
    );

    final failures = <String>[];

    try {
      final written = await TddProfileWriter(
        profile: isFlutter ? TddProfile.flutter : TddProfile.dart,
      ).write(cwd, force: force);
      stdout.writeln(
        written == null
            ? '   ✓ .specify/memory/tdd-profile.md (already present)'
            : '   ✓ .specify/memory/tdd-profile.md (created)',
      );
    } on StateError catch (e) {
      stdout.writeln('   ✗ .specify/memory/tdd-profile.md: $e');
      failures.add('tdd_profile_writer: $e');
    }

    try {
      final written = await const DartTestYamlWriter().write(cwd);
      stdout.writeln(
        written == null
            ? '   ✓ dart_test.yaml (already present)'
            : '   ✓ dart_test.yaml (created)',
      );
    } on StateError catch (e) {
      stdout.writeln('   ✗ dart_test.yaml: $e');
      failures.add('dart_test_yaml_writer: $e');
    }

    final appName = _deriveAppName(cwd);
    try {
      // Issue #664: gate the smoke-test flavor behind the project flavor —
      // a pure Dart package must not receive `package:flutter_test` imports
      // it cannot resolve.
      final written = await SmokeTestWriter(
        isFlutter: isFlutter,
      ).write(cwd, appName);
      stdout.writeln(
        written == null
            ? '   ✓ test/bootstrap_smoke_test.dart (already present)'
            : '   ✓ test/bootstrap_smoke_test.dart (created)',
      );
    } on StateError catch (e) {
      stdout.writeln('   ✗ test/bootstrap_smoke_test.dart: $e');
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
        stdout.writeln(
          written == null
              ? '   ✓ lib/app.dart (already present)'
              : '   ✓ lib/app.dart (created)',
        );
      } on StateError catch (e) {
        stdout.writeln('   ✗ lib/app.dart: $e');
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
        final added = await _ensureFlutterAppDependencies(cwd);
        if (added.isEmpty) {
          stdout.writeln(
            '   ✓ pubspec.yaml dependencies (app module: already declared)',
          );
        } else {
          stdout.writeln(
            '   ✓ pubspec.yaml dependencies (app module: added: '
            '${added.join(', ')})',
          );
        }
      } on FormatException catch (e) {
        stdout.writeln('   ✗ pubspec.yaml dependencies (app module): $e');
        failures.add('pubspec_app_dependencies_patcher: $e');
      } on StateError catch (e) {
        stdout.writeln('   ✗ pubspec.yaml dependencies (app module): $e');
        failures.add('pubspec_app_dependencies_patcher: $e');
      } on UnsupportedError catch (e) {
        stdout.writeln('   ✗ pubspec.yaml dependencies (app module): $e');
        failures.add('pubspec_app_dependencies_patcher: $e');
      }
    }

    try {
      final added = await PubspecDevDependenciesPatcher(
        isFlutter: isFlutter,
      ).ensure(cwd);
      if (added.isEmpty) {
        stdout.writeln('   ✓ pubspec.yaml dev_dependencies (already complete)');
      } else {
        stdout.writeln(
          '   ✓ pubspec.yaml dev_dependencies (added: ${added.join(', ')})',
        );
      }
    } on FormatException catch (e) {
      stdout.writeln('   ✗ pubspec.yaml dev_dependencies: $e');
      failures.add('pubspec_dev_dependencies_patcher: $e');
    } on StateError catch (e) {
      stdout.writeln('   ✗ pubspec.yaml dev_dependencies: $e');
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
        stdout.writeln('   ✗ pubspec.yaml dependencies (skin): $message');
        failures.add('pubspec_skin_dependency_patcher: $message');
      } else {
        try {
          final added = await const PubspecSkinDependencyPatcher().ensure(cwd);
          if (added.isEmpty) {
            stdout.writeln(
              '   ✓ pubspec.yaml dependencies (skin: zuraffa_ui already '
              'declared)',
            );
          } else {
            stdout.writeln(
              '   ✓ pubspec.yaml dependencies (added: ${added.join(', ')})',
            );
          }
        } on FormatException catch (e) {
          stdout.writeln('   ✗ pubspec.yaml dependencies (skin): $e');
          failures.add('pubspec_skin_dependency_patcher: $e');
        } on StateError catch (e) {
          stdout.writeln('   ✗ pubspec.yaml dependencies (skin): $e');
          failures.add('pubspec_skin_dependency_patcher: $e');
        } on UnsupportedError catch (e) {
          stdout.writeln('   ✗ pubspec.yaml dependencies (skin): $e');
          failures.add('pubspec_skin_dependency_patcher: $e');
        }
      }
    }

    if (failures.isNotEmpty) {
      stderr.writeln(
        '\nzfa tdd init: misfire — ${failures.length} writer(s) failed. '
        'Resolve the failures above and re-run `zfa tdd init`.',
      );
      for (final f in failures) {
        stderr.writeln('  - $f');
      }
      // Errors-are-an-API (VISION §4): the thrown message carries the
      // failure details too, so captured channels (wrappers, JSON
      // envelopes, `zfa tdd run` step logs) name the exact remedy without
      // needing the raw stderr transcript.
      throw StateError(
        'zfa tdd init: misfire — ${failures.length} writer(s) failed: '
        '${failures.join(' | ')}',
      );
    }

    stdout.writeln(
      '\nTDD baseline ensured. Run `flutter test` (or '
      '`dart test`) to confirm a green baseline.',
    );
    _verdict.details['failures'] = 0;
  }

  /// The runtime dependencies the day-zero Flutter app module
  /// (`lib/app.dart`) requires. Constraints mirror the codebase's
  /// canonical wiring (`DependencyWirer.standardSet` pins
  /// `zuraffa_flutter: ^6.0.0`; the repo itself resolves `get_it
  /// ^9.2.1`) so a self-healed pubspec stays on the same resolver
  /// graph the toolchain ships (issue #1349).
  static const Map<String, String> _flutterAppDependencies = {
    'zuraffa_flutter': '^6.0.0',
    'get_it': '^9.2.1',
  };

  /// Ensures the day-zero app module's runtime deps are declared under
  /// `dependencies:` in the project pubspec. Returns the entries that
  /// were added (empty when already complete).
  ///
  /// Same textual-patching discipline as `PubspecDevDependenciesPatcher`
  /// / `PubspecSkinDependencyPatcher`: the YAML is parsed for READ-ONLY
  /// detection (idempotent, hand-edit preserving) and patched TEXTUALLY
  /// so comments and formatting survive. Empty inline `dependencies: {}`
  /// mappings are expanded to block style; non-empty inline mappings are
  /// refused loudly instead of being mangled.
  Future<List<String>> _ensureFlutterAppDependencies(String cwd) async {
    final file = File('$cwd/pubspec.yaml');
    if (!await file.exists()) {
      throw StateError('pubspec.yaml not found at ${file.path}');
    }
    final raw = await file.readAsString();

    dynamic doc;
    try {
      doc = loadYaml(raw);
    } on YamlException catch (e) {
      throw FormatException(
        'pubspec.yaml at ${file.path} is not valid YAML: $e',
      );
    }
    if (doc is! Map) {
      throw FormatException(
        'pubspec.yaml at ${file.path} did not parse to a Map',
      );
    }
    final rawExisting = doc['dependencies'];
    if (rawExisting != null && rawExisting is! Map) {
      throw FormatException(
        'pubspec.yaml at ${file.path} has a non-map dependencies value',
      );
    }
    final existing = (rawExisting as Map?) ?? const {};

    final missing = <String>[];
    _flutterAppDependencies.forEach((pkg, constraint) {
      if (!existing.containsKey(pkg)) {
        missing.add('$pkg: $constraint');
      }
    });

    if (missing.isEmpty) return missing;

    final newContent = _patchDependenciesTextually(raw, missing);
    await file.writeAsString(newContent);
    return missing;
  }

  /// Inserts the missing entries at the END of the `dependencies:` block
  /// (before the next top-level key), preserving comments and formatting.
  String _patchDependenciesTextually(String raw, List<String> missing) {
    final lines = raw.split('\n');
    var depsIdx = -1;
    var endIdx = lines.length;
    var inlineEmpty = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final depsMatch = RegExp(r'^dependencies:\s*(.*)$').firstMatch(line);
      if (depsMatch != null) {
        final rest = depsMatch.group(1)!.trim();
        if (rest.isEmpty || rest == '{}') {
          depsIdx = i;
          inlineEmpty = rest == '{}';
          continue;
        }
        if (rest.startsWith('{')) {
          throw UnsupportedError(
            'Inline `dependencies: {...}` mappings are not supported by '
            'the tdd init app-dependency self-heal; use a block-style '
            '`dependencies:` section instead.',
          );
        }
      }
      if (depsIdx >= 0 && !inlineEmpty) {
        if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
          continue;
        }
        final leadingMatch = RegExp(r'^(\s*)').firstMatch(line);
        final leading = leadingMatch?.group(1) ?? '';
        if (leading.length < 2) {
          endIdx = i;
          break;
        }
      }
    }

    final buf = StringBuffer();
    if (depsIdx < 0) {
      // No dependencies section at all — append one.
      buf
        ..write(raw)
        ..write(raw.endsWith('\n') ? '' : '\n')
        ..writeln('dependencies:');
      for (final m in missing) {
        buf.writeln('  $m');
      }
      return buf.toString();
    }

    if (inlineEmpty) {
      for (var i = 0; i < lines.length; i++) {
        if (i == depsIdx) {
          buf.writeln('dependencies:');
          for (final m in missing) {
            buf.writeln('  $m');
          }
        } else {
          buf.writeln(lines[i]);
        }
      }
      return buf.toString();
    }

    for (var i = 0; i < lines.length; i++) {
      if (i == endIdx) {
        for (final m in missing) {
          buf.writeln('  $m');
        }
      }
      buf.writeln(lines[i]);
    }
    if (endIdx >= lines.length) {
      for (final m in missing) {
        buf.writeln('  $m');
      }
    }
    return buf.toString();
  }

  Future<bool> _isFlutterProject(String cwd) async {
    final pubspec = File('$cwd/pubspec.yaml');
    if (!await pubspec.exists()) return false;
    final raw = await pubspec.readAsString();
    return raw.contains('environment:') &&
        (raw.contains('flutter') || raw.contains('sdk: flutter'));
  }

  String _deriveAppName(String cwd) {
    final base = cwd.split(Platform.pathSeparator).last;
    return base.isEmpty ? 'myapp' : base;
  }
}
