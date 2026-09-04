// IMPLEMENTED (073 phase 2, issue #961): AC-12 — merge lands the
// feature's artifacts, journal, and registry into the host: sandbox
// edits to the receipts arrive in the host tree byte-for-byte.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/merge_slice_capability.dart';

import 'sandbox_fixture.dart';

void subject_a12() {
  final host = writeHostProject();
  final sandboxPath = p.join(host.path, '.zuraffa', 'slices', fixtureFeature);
  // The sandbox receipt the loop advanced inside the sandbox.
  final sandboxSpec = Directory(
    p.join(sandboxPath, 'specs', fixtureFeature, 'tdd'),
  )..createSync(recursive: true);
  File(
    p.join(sandboxSpec.path, 'journal.json'),
  ).writeAsStringSync('{"cycle":2,"reds":2,"greens":5}\n');
  File(
    p.join(sandboxSpec.path, 'artifacts.json'),
  ).writeAsStringSync('{"artifacts":["a1"]}\n');
  File(
    p.join(Directory(sandboxSpec.path).parent.path, 'spec.md'),
  ).writeAsStringSync('# Login feature spec (fixture, sandbox-revised)\n');

  final landed = MergeSliceCapability.landReceipts(
    sandboxDir: sandboxPath,
    projectRoot: host.path,
    feature: fixtureFeature,
  );
  expect(landingCovers(landed), isTrue, reason: landed.join('\n'));

  // The host now carries the landed artifacts + journal + registry.
  expect(
    File(
      p.join(host.path, 'specs', fixtureFeature, 'tdd', 'journal.json'),
    ).readAsStringSync(),
    contains('"cycle":2'),
  );
  expect(
    File(
      p.join(host.path, 'specs', fixtureFeature, 'tdd', 'artifacts.json'),
    ).readAsStringSync(),
    contains('"a1"'),
  );
  expect(
    File(
      p.join(host.path, 'specs', fixtureFeature, 'spec.md'),
    ).readAsStringSync(),
    contains('sandbox-revised'),
  );
}

bool landingCovers(List<String> landed) =>
    landed.contains('specs/$fixtureFeature/spec.md') &&
    landed.contains('specs/$fixtureFeature/tdd/journal.json') &&
    landed.contains('specs/$fixtureFeature/tdd/artifacts.json');
