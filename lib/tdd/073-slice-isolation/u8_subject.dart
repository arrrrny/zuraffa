// IMPLEMENTED (073 phase 2, issue #961): errors-are-an-API — every
// refusal across cut/verify/merge names the offending path, reference,
// or check with a `--> fix:` hint, and the generated wiring carries the
// same refusals (FR-008).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/cut_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/merge_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/generators/sandbox_scaffold.dart';

import 'sandbox_fixture.dart';

Object? subject_u8() {
  final host = writeHostProject();
  final manifest = fixtureManifest(host);

  // cut: a malformed slice name refuses with the offending value + fix.
  String nameRefusal;
  try {
    CutSliceCapability.sandboxDirFor(host.path, '../escape');
    nameRefusal = 'no refusal';
  } on ArgumentError catch (e) {
    nameRefusal = e.toString();
  }
  expect(nameRefusal, contains('../escape'), reason: 'the offender is named');
  expect(nameRefusal, contains('--> fix:'));

  // merge: an absent verdict refuses naming the missing check + fix.
  final dir = Directory.systemTemp.createTempSync('u8-gate-');
  final gate = MergeSliceCapability.gateOnVerdict(dir.path, sliceName: fixtureFeature);
  expect(gate, isNotNull);
  expect(gate!.message, contains('no verify verdict'));
  expect(gate.message, contains('--> fix:'));

  // The runtime harness refusals: unrouted path and unbound token,
  // each naming the offender with a fix hint.
  String unrouted;
  try {
    SliceRouteTable(const []).resolve('/settings');
    unrouted = 'no refusal';
  } on StateError catch (e) {
    unrouted = e.message.toString();
  }
  expect(unrouted, contains('/settings'));
  expect(unrouted, contains('--> fix:'));

  String unbound;
  try {
    SandboxLocator().resolve('dependencies/unknown');
    unbound = 'no refusal';
  } on StateError catch (e) {
    unbound = e.message.toString();
  }
  expect(unbound, contains('dependencies/unknown'));
  expect(unbound, contains('--> fix:'));

  // The GENERATED wiring carries the same refusal contracts.
  final router = SandboxScaffold.router(routes: const [
    SandboxRoute(path: '/login', page: 'LoginPage'),
  ]);
  expect(router, contains('--> fix:'));
  final di = SandboxScaffold.di(bindings: [
    SandboxBinding(
      dependency: 'FirebaseAuth',
      kind: 'service',
      mockArtifact: manifest.dependencies.first.mockArtifact,
    ),
  ]);
  expect(di, contains('--> fix:'));
  return null;
}
