// SPEC 1420 — the declared-routing seam exposes the FULL routing decision.
//
// `DeclaredRouting.declaredSignatureFor` returns only `result.signature`; a
// row-only Key Entity trace resolves (kind unit, surface entityPipeline,
// entityName <Entity>, signature null) and the entityPipeline surface was
// silently discarded at gen — the issue #1420 root cause. The remediation
// adds `declaredRoutingFor` (the full decision) and makes
// `declaredSignatureFor` delegate to it, byte-identical.
//
// Test map (fast tier):
//   U-1420-D1 — row-only entity trace → surface entityPipeline + entityName,
//               signature null.
//   U-1420-D2 — the legacy `declaredSignatureFor` contract on the SAME spec:
//               null (unchanged).
//   U-1420-D3 — the legacy contract on a scalar signature trace: the resolved
//               signature (the delegated path is preserved).
//   U-1420-D4 — a DOMAIN row WITH a signature: surface entityPipeline + the
//               signature — the contract lane never enters gen's synthesis
//               branch (its signature is non-null).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/declared_routing.dart';

void main() {
  late Directory tmp;
  const feature = '1420-declared-routing';
  const specMd =
      '''
# Spec: $feature

## Functional Requirements

- **FR-001**: `SharedAttachmentType` MUST expose exactly the four share
  attachment kinds in declaration order
- **FR-002**: the login use case authenticates the user

### Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| SharedAttachmentType | `kind: String` | the four share attachment kinds |

### Layer Contracts

**Domain**:
- `AuthRepo`: `login(AuthRequest) -> bool`
''';

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bug_1420_routing_');
    final featureDir = Directory(p.join(tmp.path, 'specs', feature));
    featureDir.createSync(recursive: true);
    File(p.join(featureDir.path, 'spec.md')).writeAsStringSync(specMd);
    Directory(p.join(featureDir.path, 'tdd')).createSync();
    File(p.join(featureDir.path, 'tdd', 'test-list.md')).writeAsStringSync('''
# Test List: $feature

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | exposes exactly the four share attachment kinds in declaration order | FR-001, SharedAttachmentType | PENDING |
| U2 | authenticates the user | FR-002, AuthRepo.login | PENDING |
''');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('U-1420-D1: row-only entity trace → surface entityPipeline + '
      'entityName, signature null', () async {
    final decision = await DeclaredRouting.declaredRoutingFor(
      cwd: tmp.path,
      featureName: feature,
      featureDir: p.join(tmp.path, 'specs', feature),
      behaviorId: 'U1',
    );

    expect(decision, isA<RoutingDecision>());
    final d = decision as RoutingDecision;
    expect(d.kind, BehaviorKind.unit);
    expect(d.surface, GenerationSurface.entityPipeline);
    expect(d.entityName, 'SharedAttachmentType');
    expect(d.signature, isNull, reason: 'Key Entity rows declare no methods');
  });

  test('U-1420-D2: legacy declaredSignatureFor contract on the SAME spec — '
      'null (the delegation is byte-identical)', () async {
    final signature = await DeclaredRouting.declaredSignatureFor(
      cwd: tmp.path,
      featureName: feature,
      featureDir: p.join(tmp.path, 'specs', feature),
      behaviorId: 'U1',
    );

    expect(signature, isNull);
  });

  test('U-1420-D3: legacy declaredSignatureFor on a scalar signature trace — '
      'the resolved signature', () async {
    final signature = await DeclaredRouting.declaredSignatureFor(
      cwd: tmp.path,
      featureName: feature,
      featureDir: p.join(tmp.path, 'specs', feature),
      behaviorId: 'U2',
    );

    expect(signature, isNotNull);
    expect(signature!.name, 'login');
    expect(signature.returnType, 'bool');
  });

  test('U-1420-D4: DOMAIN row with a signature → entityPipeline + the '
      'signature (never the synthesis branch)', () async {
    final decision = await DeclaredRouting.declaredRoutingFor(
      cwd: tmp.path,
      featureName: feature,
      featureDir: p.join(tmp.path, 'specs', feature),
      behaviorId: 'U2',
    );

    expect(decision, isA<RoutingDecision>());
    final d = decision as RoutingDecision;
    expect(d.surface, GenerationSurface.entityPipeline);
    expect(d.signature, isNotNull, reason: 'the contract lane keeps its path');
    expect(d.signature!.name, 'login');
  });
}
