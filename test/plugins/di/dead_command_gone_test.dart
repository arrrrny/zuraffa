import 'dart:io';

import 'package:test/test.dart';

/// SPEC 0974 (issue #974, order 1): the 427-LOC dead command file under
/// `lib/src/commands/` (the standalone `DiCommand`) must be DELETED — not
/// commented out — and nothing in the tree may reference it.
///
/// This is the grep gate the issue's acceptance criteria demand. The LIVE
/// command (`modular_di_command.dart`) is explicitly allowed to keep its
/// name and imports; only references to the DEAD standalone file count.
///
/// The probe tokens are built from adjacent string literals so this test
/// file itself never contains the literal token under test — a repo-wide
/// grep for the dead path must not self-match the gate that enforces it.
const String _deadToken = 'di' '_command' '.dart';
const String _deadPath = 'lib/src/commands/' 'di' '_command' '.dart';

void main() {
  final repoRoot = Directory.current.path;

  test('A1: the 427-LOC dead command file is deleted from the tree', () {
    final deadFile = File('$repoRoot/$_deadPath');
    expect(deadFile.existsSync(), isFalse,
        reason: 'the dead command must be deleted (issue #974 order 1)');
  });

  test(
    'U1: no source under lib/ references the dead command file',
    () async {
      final offenders = <String>[];
      final libDir = Directory('$repoRoot/lib');
      expect(libDir.existsSync(), isTrue, reason: 'run from repo root');

      await for (final entity in libDir.list(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;
        final content = await entity.readAsString();
        // The live command's own name contains the dead token as a
        // substring (`modular_` + token); it is the sanctioned rewiring
        // target, so occurrences preceded by `modular_` are not references
        // to the dead file.
        final sanitized = content.replaceAll('modular_$_deadToken', '');
        if (sanitized.contains(_deadToken)) {
          offenders.add(entity.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'these files reference the dead command (rewire them to '
            'ModularDiCommand per issue #974): ${offenders.join(', ')}',
      );
    },
  );

  test(
    'A1b: the dead standalone command class is gone from lib/src/commands',
    () {
      // Even a commented-out file would leave the class declaration
      // greppable under lib/src/commands. The live grammar lives in
      // ModularDiCommand; the dead divergent class must not exist anywhere.
      final commandsDir = Directory('$repoRoot/lib/src/commands');
      final declaring = commandsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => RegExp(
            r'^\s*(?:abstract\s+|final\s+|sealed\s+|base\s+)*class\s+DiCommand\b',
            multiLine: true,
          ).hasMatch(f.readAsStringSync()))
          .map((f) => f.path)
          .toList();

      expect(declaring, isEmpty,
          reason: 'the dead class is still declared in: ${declaring.join(', ')}');
    },
  );
}
