// Tests for the CycleLog service (spec 041-tdd-setup-plugin, U38-U39).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/cycle_entry.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_log.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('cycle_log_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test('append creates the file with a header if missing', () async {
    final log = CycleLog(tmpDir.path);
    final entry = CycleLogEntry(
      behaviorId: 'A1',
      kind: CycleEntryKind.red,
      runnerCommand: 'flutter test',
      exitCode: 1,
      capturedOutput: 'failure',
      classification: FailureClass.assertionFailure,
    );
    await log.append(entry);
    final file = File(p.join(tmpDir.path, 'tdd/cycle-log.md'));
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('# Cycle Log'));
    expect(content, contains('A1'));
    expect(content, contains('assertionFailure'));
  });

  test('append is strictly append-only — never edits existing entries',
      () async {
    final log = CycleLog(tmpDir.path);
    final entry1 = CycleLogEntry(
      behaviorId: 'A1',
      kind: CycleEntryKind.red,
      runnerCommand: 'cmd-1',
      exitCode: 1,
      capturedOutput: 'out-1',
      classification: FailureClass.assertionFailure,
    );
    final entry2 = CycleLogEntry(
      behaviorId: 'A2',
      kind: CycleEntryKind.green,
      runnerCommand: 'cmd-2',
      exitCode: 0,
      capturedOutput: 'out-2',
    );
    await log.append(entry1);
    await Future<void>.delayed(Duration(milliseconds: 10));
    await log.append(entry2);
    final content =
        File(p.join(tmpDir.path, 'tdd/cycle-log.md')).readAsStringSync();
    final idx1 = content.indexOf('cmd-1');
    final idx2 = content.indexOf('cmd-2');
    expect(idx1, greaterThanOrEqualTo(0));
    expect(idx2, greaterThan(idx1));
  });
}
