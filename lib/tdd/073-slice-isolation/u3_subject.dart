// IMPLEMENTED (073 phase 2, issue #961): the loop's receipts live
// inside the sandbox — a real cut carries the feature's journal and
// registry byte-for-byte, so the tdd loop can run with the sandbox as
// project root and its evidence stays in the sandbox, never the host
// (FR-003).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'sandbox_fixture.dart';

Future<Object?> subject_u3() async {
  final host = writeHostProject();
  addTearDown(() => host.deleteSync(recursive: true));

  final result = await cutSandbox(host);
  expect(result.success, isTrue, reason: result.message);

  final sandbox = sandboxDirOf(host);
  final journal = readSandboxFile(sandbox, 'specs/$fixtureFeature/tdd/journal.json');
  final registry = readSandboxFile(
    sandbox,
    'specs/$fixtureFeature/tdd/artifacts.json',
  );
  // The receipts are the loop's evidence, copied verbatim — the
  // sandbox carries its own run history, not a pointer into the host.
  expect(journal, equals(File(p.join(host.path, 'specs', fixtureFeature, 'tdd', 'journal.json')).readAsStringSync()));
  expect(journal, contains('"cycle"'));
  expect(registry, contains('"artifacts"'));
  return null;
}
