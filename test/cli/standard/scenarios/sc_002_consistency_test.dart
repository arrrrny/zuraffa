// SC-002 acceptance test: two CliApp instances built independently with
// different commands but the same CliContract agree on >= 80% of the
// consistency surface.
//
// Pure-Dart (FR-012): no package:flutter import.

import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

void main() {
  test('A2: two standard CliApps share >= 80% of the consistency surface', () {
    final appA = CliApp(name: 'appA', version: '0.1.0');
    final appB = CliApp(name: 'appB', version: '0.2.0');

    // The consistency surface is a list of field names from CliContract.
    // Two apps using CliContract.standard share 100% of it.
    final surfaceA = appA.contract.consistencySurface.toSet();
    final surfaceB = appB.contract.consistencySurface.toSet();

    // Intersection: fields both apps agree on (i.e. fields with the same
    // value in both contracts).
    final intersection = <String>{};
    for (final field in surfaceA.intersection(surfaceB)) {
      if (_fieldValuesAgree(appA.contract, appB.contract, field)) {
        intersection.add(field);
      }
    }

    // Union: the full set of fields either app exposes on the surface.
    final union = surfaceA.union(surfaceB);

    final overlap = intersection.length / union.length;
    expect(
      overlap,
      greaterThanOrEqualTo(0.80),
      reason: 'SC-002 requires >= 80% overlap; got ${(overlap * 100).round()}%',
    );
  });

  test('two apps with different commands but same contract meet SC-002', () {
    final appA = CliApp(name: 'appA', version: '0.1.0');
    appA.register(
      StandardCommand(
        name: 'greet',
        description: '',
        handler: (_) async => const SuccessResult(),
      ),
    );

    final appB = CliApp(name: 'appB', version: '0.2.0');
    appB.register(
      StandardCommand(
        name: 'list',
        description: '',
        handler: (_) async => const SuccessResult(),
      ),
    );

    // The two apps have different command sets but the same contract —
    // their consistency surface is identical.
    expect(appA.contract, equals(appB.contract));
    expect(
      appA.contract.consistencySurface,
      equals(appB.contract.consistencySurface),
    );

    // Compute the overlap (should be 1.0).
    final surfaceA = appA.contract.consistencySurface.toSet();
    final surfaceB = appB.contract.consistencySurface.toSet();
    final intersection = <String>{};
    for (final field in surfaceA.intersection(surfaceB)) {
      if (_fieldValuesAgree(appA.contract, appB.contract, field)) {
        intersection.add(field);
      }
    }
    final union = surfaceA.union(surfaceB);
    final overlap = intersection.length / union.length;
    expect(overlap, equals(1.0));
  });

  test('consistency surface checklist covers all required categories', () {
    final contract = CliContract.standard;
    final surface = contract.consistencySurface;

    // The spec's SC-002 enumerates: global flag names, help header, error
    // shape fields, output schema, exit-code vocabulary, unknown-command
    // behavior, ambiguous-name behavior. We map these to surface entries:
    expect(
      surface,
      contains('globalFlags.names'),
      reason: 'global flag names must be on the surface',
    );
    expect(
      surface,
      contains('helpHeader'),
      reason: 'help header must be on the surface',
    );
    expect(
      surface,
      contains('errorShapeFields'),
      reason: 'error shape fields must be on the surface',
    );
    expect(
      surface,
      contains('outputSchemaName'),
      reason: 'output schema must be on the surface',
    );
    expect(
      surface,
      contains('exitCode.success'),
      reason: 'exit-code vocabulary must be on the surface',
    );
    expect(
      surface,
      contains('exitCode.notFound'),
      reason:
          'unknown-command behavior (exitCode.notFound) must be on the surface',
    );
    expect(
      surface,
      contains('exitCode.conflict'),
      reason:
          'ambiguous-name behavior (exitCode.conflict) must be on the surface',
    );
  });
}

bool _fieldValuesAgree(CliContract a, CliContract b, String field) {
  switch (field) {
    case 'exitCode.success':
      return a.exitCode.success == b.exitCode.success;
    case 'exitCode.usage':
      return a.exitCode.usage == b.exitCode.usage;
    case 'exitCode.runtime':
      return a.exitCode.runtime == b.exitCode.runtime;
    case 'exitCode.notFound':
      return a.exitCode.notFound == b.exitCode.notFound;
    case 'exitCode.conflict':
      return a.exitCode.conflict == b.exitCode.conflict;
    case 'exitCode.versionMismatch':
      return a.exitCode.versionMismatch == b.exitCode.versionMismatch;
    case 'exitCode.circularRef':
      return a.exitCode.circularRef == b.exitCode.circularRef;
    case 'globalFlags.names':
      final an = a.globalFlags.map((f) => f.name).toSet();
      final bn = b.globalFlags.map((f) => f.name).toSet();
      return an.containsAll(bn) && bn.containsAll(an);
    case 'errorShapeFields':
      final ae = a.errorShapeFields.toSet();
      final be = b.errorShapeFields.toSet();
      return ae.containsAll(be) && be.containsAll(ae);
    case 'outputSchemaName':
      return a.outputSchemaName == b.outputSchemaName;
    case 'helpHeader':
      return a.helpHeader == b.helpHeader;
    default:
      return false;
  }
}
