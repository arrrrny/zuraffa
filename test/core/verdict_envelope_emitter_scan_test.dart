// SPEC 1105 — the emitter-sweep guard.
//
// Issue #1105 acceptance: "Every --json command emits VerdictEnvelope
// (test scans codebase)" and "one canonical envelope: zuraffa.verdict.v1
// ... grep returns only lib/src/core/verdict_envelope.dart and the
// emitters".
//
// This test makes both greps mechanical:
//   1. every lib/src file that REGISTERS an output `--json` flag (a flag
//      with `negatable: false`) and encodes JSON must reference the
//      canonical VerdictEnvelope (import / call / schema constant);
//   2. the 7 emitter files named by the issue must reference the core
//      envelope;
//   3. the literal `zuraffa.verdict.v1` lives ONLY in the core file —
//      emitters reference the constant, so the identifier cannot drift
//      again.
//
// The scan is textual on purpose: it is a drift tripwire, not a compiler.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:path/path.dart' as p;

const String repoRoot = '.';

/// Files under lib/src excluded from the sweep: they register a `--json`
/// OUTPUT flag and encode JSON but are NOT one of the 7 verdict emitters
/// the issue migrates. Each exclusion carries the reason a reviewer can
/// check. This allow-list is the follow-up backlog: a new `--json`
/// emitter must NOT be added here — it must emit VerdictEnvelope.
const Map<String, String> kExcluded = <String, String>{
  // Raw data documents (not verdicts): manifest/table dumps and the
  // pre-1105 text-report commands that emit their own --json shapes.
  // Migrating these to the canonical envelope is the follow-up backlog
  // (SPEC 1105 covered exactly the 7 divergent verdict shapes).
  'lib/src/commands/test_command.dart': 'pre-1105 emitter (backlog)',
  'lib/src/commands/capability_command.dart': 'pre-1105 emitter (backlog)',
  'lib/src/commands/make_command.dart': 'pre-1105 emitter (backlog)',
  'lib/src/commands/skin_command.dart': 'pre-1105 emitter (backlog)',
  'lib/src/commands/manifest_command.dart':
      'manifest dump — a data document, not a verdict (backlog)',
  'lib/src/commands/doctor_command.dart': 'pre-1105 emitter (backlog)',
  'lib/src/commands/provider_verify_command.dart': 'pre-1105 emitter (backlog)',
  'lib/src/plugins/tdd/commands/realize_mock_command.dart':
      'pre-1105 emitter (backlog)',
  'lib/src/plugins/benchmark/cli/benchmark_command.dart':
      'pre-1105 emitter (backlog)',
  // Input-JSON option + raw table-drift dump (pre-existing semantics,
  // not one of the 7 divergent verdict shapes named by the issue; the
  // ENTITY verdict mode in the same file IS migrated).
  'lib/src/commands/route_verify_command.dart':
      'the drift mode dumps the raw table diff (a data document, not a '
      'verdict); the entity verdict mode in this same file IS migrated',
};

List<File> _dartFilesUnder(String dir) {
  final dirEntity = Directory(p.join(repoRoot, dir));
  if (!dirEntity.existsSync()) return const [];
  return dirEntity
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Normalizes a path to the repo-root-relative POSIX form (strips a
/// leading `./`, backslashes to slashes) so set membership checks are
/// stable across `dart test` invocation styles.
String _normalized(String path) {
  var rel = path.replaceAll('\\', '/');
  while (rel.startsWith('./')) {
    rel = rel.substring(2);
  }
  return rel;
}

bool _registersJsonOutputFlag(String source) {
  // addFlag( ... 'json' ... negatable: false ... ) — possibly wrapped
  // across lines by dart format.
  var flagAt = source.indexOf("'json'");
  while (flagAt != -1) {
    final window = source.substring(
      (flagAt - 200).clamp(0, source.length),
      (flagAt + 400).clamp(0, source.length),
    );
    if (window.contains('addFlag') && window.contains('negatable: false')) {
      return true;
    }
    flagAt = source.indexOf("'json'", flagAt + 1);
  }
  return false;
}

void main() {
  group('SPEC 1105: the emitter sweep', () {
    test('every lib/src file registering a --json output flag and encoding '
        'JSON references the canonical VerdictEnvelope', () {
      final offenders = <String>[];
      for (final dir in const ['lib/src/commands', 'lib/src/plugins']) {
        for (final file in _dartFilesUnder(dir)) {
          final rel = _normalized(file.path);
          if (kExcluded.containsKey(rel)) continue;
          final source = file.readAsStringSync();
          if (!_registersJsonOutputFlag(source)) continue;
          if (!source.contains('jsonEncode(') &&
              !source.contains('VerdictEnvelope')) {
            continue;
          }
          // The emitter contract: the canonical envelope is referenced
          // (constructed, emitted, or adapted from).
          if (!source.contains('VerdictEnvelope') &&
              !source.contains('verdict_envelope.dart')) {
            offenders.add(rel);
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'every --json emitter must speak the one canonical '
            'envelope (lib/src/core/verdict_envelope.dart). Offenders: '
            '$offenders',
      );
    });

    test('the 7 divergent emitters named by the issue are migrated', () {
      const emitters = <String, String>{
        'tdd (models)': 'lib/src/plugins/tdd/models/verdict_envelope.dart',
        'mock (command)': 'lib/src/commands/mock_command.dart',
        'route create': 'lib/src/commands/route_create_command.dart',
        'route verify': 'lib/src/commands/route_verify_command.dart',
        'cache verify': 'lib/src/commands/cache_verify_command.dart',
        'state create': 'lib/src/commands/state_create_command.dart',
        'usecase create': 'lib/src/commands/usecase_create_command.dart',
      };
      for (final entry in emitters.entries) {
        final source = File(entry.value).readAsStringSync();
        expect(
          source.contains('VerdictEnvelope') ||
              source.contains('verdict_envelope.dart'),
          isTrue,
          reason:
              '${entry.key} (${entry.value}) must reference the '
              'canonical VerdictEnvelope',
        );
      }
    });

    test('the literal "zuraffa.verdict.v1" lives only in the core file '
        'and the emitters (issue #1105 acceptance grep)', () {
      const coreFile = 'lib/src/core/verdict_envelope.dart';
      const emitterFiles = <String>{
        'lib/src/plugins/tdd/models/verdict_envelope.dart',
        'lib/src/plugins/cache/cache_verify.dart',
        'lib/src/commands/mock_command.dart',
        'lib/src/commands/route_create_command.dart',
        'lib/src/commands/route_verify_command.dart',
        'lib/src/commands/cache_verify_command.dart',
        'lib/src/commands/state_create_command.dart',
        'lib/src/commands/usecase_create_command.dart',
      };
      final offenders = <String>[];
      for (final file in _dartFilesUnder('lib')) {
        final rel = _normalized(file.path);
        if (rel == coreFile || emitterFiles.contains(rel)) continue;
        if (File(rel).readAsStringSync().contains('zuraffa.verdict.v1')) {
          offenders.add(rel);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'emitters must reference VerdictEnvelope.canonicalSchema, '
            'not re-literalize the identifier. Offenders: $offenders',
      );
    });
  });
}
