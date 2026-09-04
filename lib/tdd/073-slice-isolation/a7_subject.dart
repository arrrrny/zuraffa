// IMPLEMENTED (073 phase 2, issue #961): AC-7 — the sandbox's tdd
// journal and artifact registry contain the run's evidence, and the
// receipts live in the sandbox (read back without touching the host).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Future<void> subject_a7() async {
  final host = writeHostProject();
  final result = await cutSandbox(host);
  expect(result.success, isTrue, reason: result.message);

  final sandbox = sandboxDirOf(host);
  // The receipts live IN the sandbox and carry the run's evidence.
  final journal = readSandboxFile(
    sandbox,
    'specs/$fixtureFeature/tdd/journal.json',
  );
  expect(journal, contains('"cycle"'));
  expect(journal, contains('"reds"'));
  expect(journal, contains('"greens"'));
  readSandboxFile(sandbox, 'specs/$fixtureFeature/tdd/artifacts.json');

  // Reading the evidence requires nothing from the host tree: the
  // sandbox copy stands alone (same bytes as the cut, independent file).
  final sandboxJournal = File(
    p.join(sandbox, 'specs', fixtureFeature, 'tdd', 'journal.json'),
  );
  expect(sandboxJournal.statSync().type, FileSystemEntityType.file);
  expect(sandboxJournal.readAsStringSync(), contains('cycle'));
}
