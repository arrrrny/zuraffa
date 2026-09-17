// EPIC 3 / issue #1134, lane 1 — the adaptive layout contract resolves
// from BOTH declaration sources: the Presentation table's
// `adaptive_layouts` bullet (issue #1142) AND, when no Presentation
// bullet declares slots, the `## Skin Contract` `adaptive_slots`
// (issue #1004 — the contract drives generation). One declaration, one
// skeleton; features declaring neither keep the single-layout skeleton
// (zero drift).
//
//  U-1134-a1: resolve() honors the Presentation declaration FIRST —
//             the Presentation bullet wins over the Skin Contract.
//  U-1134-a2: resolve() falls back to the Skin Contract's
//             adaptive_slots when no Presentation bullet declares
//             slots (the #1004 declaration drives generation).
//  U-1134-a3: resolve() returns null when NEITHER declaration exists
//             (single-layout skeleton, zero drift for existing
//             features).
//  U-1134-a4: an unknown slot declared in the Skin Contract refuses
//             BY NAME (errors-are-an-API) — never a silent guess.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/contract/adaptive_skin_contract.dart';
import 'package:zuraffa/src/skin/contract/adaptive_skin_contract_parser.dart';
import 'package:zuraffa/src/plugins/tdd/services/platform_layout_contract.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

AdaptiveSkinContract? parseSkinContract(String yaml) =>
    parseAdaptiveSkinContract('''
# Spec

## Skin Contract

```yaml
Skin Contract:
$yaml
```
''');

void main() {
  const presentationSlots = LayerContract(
    layer: 'Presentation',
    interfaceName: 'adaptive_layouts',
    methods: ['mobile', 'macos'],
  );
  const presentationComponents = LayerContract(
    layer: 'Presentation',
    interfaceName: 'LoginForm',
    methods: ['ShadInput'],
  );
  const domainContract = LayerContract(
    layer: 'Domain',
    interfaceName: 'AuthRepository',
    methods: ['signIn'],
  );

  final skinContract = parseSkinContract('''
  adaptive_slots: [mobile, ios, android, macos]
  states: [initial, loading, data, error, empty]
  routes: [login, deal_list, settings]
''');

  test('U-1134-a1: the Presentation declaration wins over the Skin '
      'Contract (precedence)', () {
    expect(skinContract, isNotNull,
        reason: 'fixture contract must parse');
    final resolved = PlatformLayoutContract.resolve(
      contracts: const [
        presentationComponents,
        presentationSlots,
        domainContract,
      ],
      skinContract: skinContract,
    );
    // The Presentation bullet's [mobile, macos] — NOT the contract's
    // four runtime slots: the generated skeleton provides exactly the
    // layouts the Presentation table declares.
    expect(resolved?.slots, ['mobile', 'macos']);
  });

  test('U-1134-a2: the Skin Contract fallback drives the skeleton when '
      'no Presentation bullet declares slots', () {
    final resolved = PlatformLayoutContract.resolve(
      contracts: const [presentationComponents, domainContract],
      skinContract: skinContract,
    );
    expect(resolved?.slots, ['mobile', 'ios', 'android', 'macos']);
  });

  test('U-1134-a3: neither declaration → null (single-layout, zero '
      'drift)', () {
    expect(
      PlatformLayoutContract.resolve(
        contracts: const [presentationComponents, domainContract],
        skinContract: null,
      ),
      isNull,
    );
    expect(
      PlatformLayoutContract.resolve(
        contracts: const [presentationComponents],
        skinContract: AdaptiveSkinContract(
          adaptiveSlots: const [],
          platformOverrides: const {},
          states: const ['initial'],
          routeNames: const ['login'],
        ),
      ),
      isNull,
      reason: 'an empty contract slot list is no declaration',
    );
  });

  test('U-1134-a4: an unknown Skin Contract slot refuses BY NAME', () {
    final withUnknownSlot = parseSkinContract('''
  adaptive_slots: [mobile, watch]
  states: [initial]
  routes: [login]
''');
    expect(withUnknownSlot, isNotNull);
    expect(
      () => PlatformLayoutContract.resolve(
        contracts: const [presentationComponents],
        skinContract: withUnknownSlot,
      ),
      throwsA(
        isA<PlatformLayoutContractException>().having(
          (e) => e.message,
          'message',
          allOf(contains('watch'), contains('--> fix:')),
        ),
      ),
    );
  });

  test('U-1134-a5: the Presentation refusal shape is unchanged '
      '(guard pin, issue #1142)', () {
    const badSlot = LayerContract(
      layer: 'Presentation',
      interfaceName: 'adaptive_layouts',
      methods: ['mobile', 'watchos'],
    );
    expect(
      () => PlatformLayoutContract.resolve(
        contracts: const [badSlot],
        skinContract: skinContract,
      ),
      throwsA(isA<PlatformLayoutContractException>()),
      reason: 'a malformed Presentation slot still refuses — the '
          'contract fallback never masks a malformed declaration',
    );
  });
}
