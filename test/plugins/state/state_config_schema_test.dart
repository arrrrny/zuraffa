// Spec 1126 (order 4) — the state config schema + the unknown-key gate.
//
// `StatePlugin.configSchema` was the pre-#1122 empty
// `{'type': 'object', 'properties': {}}` that silently accepts
// anything. It must declare the vocabulary `generateWithContext`
// actually reads — `methods` (array), `no-entity` (boolean),
// `domain` (string) — and `validateStateConfig` must reject unknown
// keys, type mismatches, and refuse an empty schema outright (the
// route/#1122 precedent). The capability path is the real unknown-key
// surface: JSON args have no args-package type enforcement.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/state/capabilities/create_state_capability.dart';
import 'package:zuraffa/src/plugins/state/state_plugin.dart';

void main() {
  late StatePlugin plugin;

  setUp(() {
    plugin = StatePlugin(outputDir: 'lib/src');
  });

  test('SC-1126-f: configSchema declares the real config vocabulary', () {
    final props = plugin.configSchema['properties'] as Map;
    expect(
      props.keys.toSet(),
      equals({'methods', 'no-entity', 'domain'}),
      reason: 'exactly the inputs generateWithContext reads',
    );
    expect((props['methods'] as Map)['type'], 'array');
    expect(((props['methods'] as Map)['items'] as Map)['type'], 'string');
    expect((props['no-entity'] as Map)['type'], 'boolean');
    expect((props['domain'] as Map)['type'], 'string');
  });

  test('SC-1126-g: validateStateConfig accepts real values', () {
    expect(
      validateStateConfig({
        'methods': ['get', 'getList'],
        'no-entity': false,
        'domain': 'catalog',
      }),
      isEmpty,
    );
  });

  test('SC-1126-h: validateStateConfig rejects unknown keys', () {
    final violations = validateStateConfig({'methd': 'get'});
    expect(violations, hasLength(1));
    expect(violations.single, contains('methd'));
    expect(
      violations.single,
      contains('methods'),
      reason: 'the violation names the allowed vocabulary',
    );
  });

  test('SC-1126-i: validateStateConfig rejects wrong types', () {
    expect(
      validateStateConfig({'methods': 'get'}),
      hasLength(1),
      reason: 'methods is array-typed',
    );
    expect(
      validateStateConfig({'no-entity': 'yes'}),
      hasLength(1),
      reason: 'no-entity is boolean-typed',
    );
    expect(
      validateStateConfig({'domain': 3}),
      hasLength(1),
      reason: 'domain is string-typed',
    );
  });

  test('SC-1126-j: validateStateConfig refuses an empty {} schema', () {
    final violations = validateStateConfig(
      {
        'methods': ['get'],
      },
      schema: {'type': 'object', 'properties': {}},
    );
    expect(violations, hasLength(1));
    expect(violations.single, contains('empty'));
  });

  test('SC-1126-k: the capability refuses a malformed JSON config '
      '(success: false, never a crash)', () async {
    final capability = CreateStateCapability(plugin, projectRoot: null);
    final result = await capability.execute({
      'name': 'Product',
      'methods': ['get'],
      'force': true,
      'methd': 'bogus', // unknown config key via the JSON surface
    });
    expect(result.success, isFalse);
    expect(result.message, contains('methd'));
    expect(result.message, contains('methods'));
  });

  test(
    'SC-1126-l: the capability still accepts the declared vocabulary',
    () async {
      final capability = CreateStateCapability(plugin, projectRoot: null);
      // A no-entity config exercises the domain/no-entity inputs without
      // needing an entity file; success (receipt or not) is the contract.
      final result = await capability.execute({
        'name': 'Product',
        'no-entity': true,
        'domain': 'catalog',
        'force': true,
        'dryRun': true,
      });
      expect(
        result.success,
        isTrue,
        reason: 'declared vocabulary must pass the gate: ${result.message}',
      );
    },
  );
}
