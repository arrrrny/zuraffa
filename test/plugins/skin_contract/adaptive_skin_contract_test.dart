// Issue #1004 — the typed adaptive skin contract: model, parser, and
// JSON Schema. The contract is the DECLARATION (spec section `##
// Skin Contract`); the plan renders it into 04-SKIN.md as typed rows
// plus a machine-parseable JSON block (see
// plan_skin_contract_1004_test.dart for the CLI behavior).
//
// RED phase: the module does not exist yet.
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:zuraffa/src/skin/contract/adaptive_skin_contract.dart';
import 'package:zuraffa/src/skin/contract/adaptive_skin_contract_parser.dart';
import 'package:zuraffa/src/skin/contract/adaptive_skin_contract_schema.dart';

const String contractSpec = '''
# Spec

## Skin Contract

```yaml
Skin Contract:
  adaptive_slots: [mobile, ios, android, macos]
  platform_overrides:
    ios:
      home_indicator_safe_area: required
    macos:
      title_bar_alignment: trailing
  states: [initial, loading, data, error, empty]
  routes: [login, deal_list, settings]
```
''';

const String jsonFormSpec = '''
# Spec

## Skin Contract: login

```json
{
  "schemaVersion": "1",
  "routes": [{ "path": "/login", "view": "LoginPage" }],
  "states": [{ "view": "LoginPage", "loading": false, "error": "toaster", "empty": false }],
  "platformRows": [{ "view": "LoginPage", "mobile": true, "ios": true, "android": true, "macos": false }],
  "stateRows": [{ "view": "LoginPage", "row": "error-toaster", "kind": "observer" }]
}
```
''';

void main() {
  group('parser — the declaration forms', () {
    test('the canonical fenced yaml form parses with every field', () {
      final contract = parseAdaptiveSkinContract(contractSpec);
      expect(contract, isNotNull);
      expect(contract!.adaptiveSlots, ['mobile', 'ios', 'android', 'macos']);
      expect(contract.platformOverrides, {
        'ios': {'home_indicator_safe_area': 'required'},
        'macos': {'title_bar_alignment': 'trailing'},
      });
      expect(contract.states, ['initial', 'loading', 'data', 'error', 'empty']);
      expect(contract.routeNames, ['login', 'deal_list', 'settings']);
      expect(contract.schemaVersion, AdaptiveSkinContract.schemaVersionV1);
    });

    test('a bare (unfenced) body parses — the ## Lanes leniency rule', () {
      final spec = contractSpec
          .replaceAll('```yaml\n', '')
          .replaceAll('\n```', '\n');
      final contract = parseAdaptiveSkinContract(spec);
      expect(contract, isNotNull);
      expect(contract!.adaptiveSlots, isNotEmpty);
    });

    test('a fenced yaml block with the Skin Contract: key parses without '
        'a heading', () {
      final spec = '''
# Spec

No heading at all.

```yaml
Skin Contract:
  adaptive_slots: [mobile]
  platform_overrides: {}
  states: [initial, data]
  routes: [login]
```
''';
      final contract = parseAdaptiveSkinContract(spec);
      expect(contract, isNotNull);
      expect(contract!.routeNames, ['login']);
    });

    test('a spec without the section returns null', () {
      expect(parseAdaptiveSkinContract('# Spec\n\nNo contract.\n'), isNull);
    });

    test('the issue #1164 json-fenced form is not the adaptive contract', () {
      expect(parseAdaptiveSkinContract(jsonFormSpec), isNull);
    });
  });

  group('parser — errors name the offending key (errors are an API)', () {
    test('an unknown top-level key throws naming the key', () {
      final spec = contractSpec.replaceFirst(
        '  states: [initial, loading, data, error, empty]',
        '  states: [initial, loading, data, error, empty]\n'
            '  platform_matrix: [mobile]',
      );
      expect(
        () => parseAdaptiveSkinContract(spec),
        throwsA(
          isA<AdaptiveSkinContractParseException>().having(
            (e) => e.message,
            'message',
            contains('platform_matrix'),
          ),
        ),
      );
    });

    test('a missing required key throws naming the key', () {
      final spec = contractSpec.replaceFirst(
        '  states: [initial, loading, data, error, empty]\n',
        '',
      );
      expect(
        () => parseAdaptiveSkinContract(spec),
        throwsA(
          isA<AdaptiveSkinContractParseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('states'), contains('missing')),
          ),
        ),
      );
    });

    test('a duplicate key throws (drift, not last-wins)', () {
      final spec = contractSpec.replaceFirst(
        '  routes: [login, deal_list, settings]',
        '  routes: [login, deal_list, settings]\n'
            '  routes: [login]',
      );
      expect(
        () => parseAdaptiveSkinContract(spec),
        throwsA(
          isA<AdaptiveSkinContractParseException>().having(
            (e) => e.message,
            'message',
            contains('routes'),
          ),
        ),
      );
    });

    test('a platform override for an undeclared slot throws naming the '
        'platform', () {
      final spec = contractSpec.replaceFirst(
        '  adaptive_slots: [mobile, ios, android, macos]',
        '  adaptive_slots: [mobile, ios, android]',
      );
      expect(
        () => parseAdaptiveSkinContract(spec),
        throwsA(
          isA<AdaptiveSkinContractParseException>().having(
            (e) => e.message,
            'message',
            allOf(contains('macos'), contains('adaptive_slots')),
          ),
        ),
      );
    });
  });

  group('model — the typed contract', () {
    test('toJson is the machine contract: parseable, schema-shaped', () {
      final contract = parseAdaptiveSkinContract(contractSpec)!;
      final json = contract.toJson();
      final decoded = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], '1');
      expect(decoded['adaptiveSlots'], ['mobile', 'ios', 'android', 'macos']);
      expect(decoded['states'], [
        'initial',
        'loading',
        'data',
        'error',
        'empty',
      ]);
      expect(decoded['routes'], [
        {'target': 'login', 'screenClass': 'LoginScreen', 'path': '/login'},
        {
          'target': 'deal_list',
          'screenClass': 'DealListScreen',
          'path': '/deal_list',
        },
        {
          'target': 'settings',
          'screenClass': 'SettingsScreen',
          'path': '/settings',
        },
      ]);
      expect((decoded['platformOverrides'] as Map)['ios'], {
        'home_indicator_safe_area': 'required',
      });
    });

    test('the state machine: happy path chains, error/empty alternate', () {
      final contract = parseAdaptiveSkinContract(contractSpec)!;
      expect(contract.happyPathStates, ['initial', 'loading', 'data']);
      expect(contract.alternateStates, ['error', 'empty']);
      // No alternates declared: every state is happy-path.
      final noAlternates = AdaptiveSkinContract(
        adaptiveSlots: const ['mobile'],
        platformOverrides: const {},
        states: const ['initial', 'loading'],
        routeNames: const ['login'],
      );
      expect(noAlternates.happyPathStates, ['initial', 'loading']);
      expect(noAlternates.alternateStates, isEmpty);
    });

    test('route derivation: screen class and path from the target', () {
      final contract = parseAdaptiveSkinContract(contractSpec)!;
      final routes = contract.routeContracts;
      expect(routes.map((r) => (r.target, r.screenClass, r.path)), [
        ('login', 'LoginScreen', '/login'),
        ('deal_list', 'DealListScreen', '/deal_list'),
        ('settings', 'SettingsScreen', '/settings'),
      ]);
    });

    test('equality and hashCode cover every field', () {
      final a = parseAdaptiveSkinContract(contractSpec)!;
      final b = parseAdaptiveSkinContract(contractSpec)!;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final c = AdaptiveSkinContract(
        adaptiveSlots: a.adaptiveSlots,
        platformOverrides: a.platformOverrides,
        states: a.states,
        routeNames: ['other'],
      );
      expect(a, isNot(c));
    });
  });

  group('schema — generated from the model (no drift, no orphans)', () {
    test('the schema is draft 2020-12, closed, and requires every field', () {
      final schema = adaptiveSkinContractSchema();
      expect(schema[r'$schema'], contains('json-schema.org'));
      expect(schema['type'], 'object');
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], [
        'schemaVersion',
        'adaptiveSlots',
        'platformOverrides',
        'states',
        'routes',
      ]);
      expect(schema['properties'].keys.toSet(), {
        'schemaVersion',
        'adaptiveSlots',
        'platformOverrides',
        'states',
        'routes',
      });
      // The schema is itself JSON-serializable.
      expect(jsonDecode(jsonEncode(schema)), isA<Map<String, dynamic>>());
    });

    test('the routes def mirrors the route field table exactly', () {
      final schema = adaptiveSkinContractSchema();
      final defs = schema[r'$defs'] as Map<String, dynamic>;
      final routeDef = defs[adaptiveRouteDefName] as Map<String, dynamic>;
      expect(routeDef['additionalProperties'], isFalse);
      expect(routeDef['required'], [
        for (final f in AdaptiveRouteContract.fields) f.name,
      ]);
      expect(
        (routeDef['properties'] as Map).keys.toList(),
        AdaptiveRouteContract.fields.map((f) => f.name).toList(),
      );
      // The $ref pointer resolves to the def key (a drifted pointer
      // would silently dangle).
      final routesProp =
          (schema['properties'] as Map)['routes'] as Map<String, dynamic>;
      expect(
        (routesProp['items'] as Map)[r'$ref'],
        '#/\$defs/$adaptiveRouteDefName',
      );
    });

    test('a valid contract parses back through its own schema shape', () {
      final contract = parseAdaptiveSkinContract(contractSpec)!;
      final decoded =
          jsonDecode(jsonEncode(contract.toJson())) as Map<String, dynamic>;
      // Required keys present, no unknown keys.
      final schema = adaptiveSkinContractSchema();
      for (final required in (schema['required'] as List<dynamic>)) {
        expect(decoded.containsKey(required), isTrue);
      }
      expect(
        decoded.keys.where(
          (k) => !(schema['properties'] as Map).containsKey(k),
        ),
        isEmpty,
      );
    });
  });
}
