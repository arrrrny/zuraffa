// Issue #1004 ([ZIKZAK-REBUILD] Skin contract slots: adaptive-layout
// platform matrix in spec): `zfa tdd plan` on a spec whose `## Skin
// Contract` section declares the adaptive contract (adaptive_slots,
// platform_overrides, states, routes) emits typed contract rows into
// `tdd/04-SKIN.md` — platform rows, state-machine rows, route rows —
// plus a machine-parseable JSON contract block validated against a
// JSON Schema in this test.
//
// RED phase: plan knows nothing about the Skin Contract section — the
// contract-row assertions fail (04-SKIN.md carries only the
// AdaptiveViewSlots table).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

import '../../../helpers/project_root.dart';

const String feature = '004-login-ui';

/// The #1004 fixture: the canonical 004-login-ui spec carrying BOTH the
/// `## Lanes` split (issue #1000) and the `## Skin Contract` adaptive
/// declaration (issue #1004).
const String skinContractSpec = '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: 004-login-ui — the adaptive login skin

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller
3. **Given** a completed login **When** the session is active **Then** the app navigates to deal_list

## Functional Requirements

- **FR-001**: The system shall present the adaptive login view with the declared platform slots (mobile, ios, android, macos).

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
  - lane: BOTH
    behaviors: [A3 (acceptance: navigates to deal_list)]
    flutter_allowed: conditionally
```

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

/// The inline JSON Schema (draft 2020-12 subset) the emitted contract
/// block is validated against: the typed shape of the #1004 adaptive
/// skin contract.
const Map<String, dynamic> adaptiveContractSchema = {
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  'type': 'object',
  'additionalProperties': false,
  'required': [
    'schemaVersion',
    'adaptiveSlots',
    'platformOverrides',
    'states',
    'routes',
  ],
  'properties': {
    'schemaVersion': {'const': '1'},
    'adaptiveSlots': {
      'type': 'array',
      'items': {'type': 'string', 'pattern': '^[a-z][a-z0-9_]*\$'},
    },
    'platformOverrides': {
      'type': 'object',
      'additionalProperties': {
        'type': 'object',
        'additionalProperties': {'type': 'string'},
      },
    },
    'states': {
      'type': 'array',
      'items': {'type': 'string', 'pattern': '^[a-z][a-z0-9_]*\$'},
    },
    'routes': {
      'type': 'array',
      'items': {r'$ref': '#/\$defs/adaptiveRoute'},
    },
  },
  r'$defs': {
    'adaptiveRoute': {
      'type': 'object',
      'additionalProperties': false,
      'required': ['target', 'screenClass', 'path'],
      'properties': {
        'target': {'type': 'string', 'pattern': '^[a-z][a-z0-9_]*\$'},
        'screenClass': {'type': 'string', 'pattern': '^[A-Z][A-Za-z0-9]*\$'},
        'path': {'type': 'string', 'pattern': '^/'},
      },
    },
  },
};

/// Validates a decoded contract against [adaptiveContractSchema] — the
/// subset of JSON Schema semantics this schema uses (type, const,
/// required, additionalProperties, enum-less patterns, \$ref into
/// \$defs). Returns the violation list; empty = valid.
List<String> schemaViolations(Map<String, dynamic> contract) {
  final violations = <String>[];

  void checkObject(
    Map<String, dynamic> obj,
    Map<String, dynamic> def,
    String where,
  ) {
    for (final required in (def['required'] as List<dynamic>)) {
      if (!obj.containsKey(required)) {
        violations.add('$where: missing "$required"');
      }
    }
    final properties = def['properties'] as Map<String, dynamic>;
    for (final key in obj.keys) {
      if (!properties.containsKey(key)) {
        violations.add('$where: unknown field "$key"');
      }
    }
    for (final entry in properties.entries) {
      final value = obj[entry.key];
      if (value == null) continue;
      final prop = entry.value as Map<String, dynamic>;
      if (prop.containsKey('const') && prop['const'] != value) {
        violations.add('$where: "${entry.key}" must be "${prop['const']}"');
      }
      if (prop['type'] == 'string' && value is! String) {
        violations.add('$where: "${entry.key}" must be a string');
      }
      if (prop['type'] == 'array' && value is! List) {
        violations.add('$where: "${entry.key}" must be an array');
      }
      if (prop['type'] == 'object' && value is! Map) {
        violations.add('$where: "${entry.key}" must be an object');
      }
      if (prop.containsKey('pattern') &&
          value is String &&
          !RegExp(prop['pattern'] as String).hasMatch(value)) {
        violations.add(
          '$where: "${entry.key}" value "$value" violates the pattern',
        );
      }
      if (prop.containsKey(r'$ref')) {
        final defs = adaptiveContractSchema[r'$defs'] as Map<String, dynamic>;
        final refName = (prop[r'$ref'] as String).split('/').last;
        final refDef = defs[refName] as Map<String, dynamic>;
        for (final (index, row) in (value as List).indexed) {
          if (row is Map<String, dynamic>) {
            checkObject(row, refDef, '$where.${entry.key}[$index]');
          } else {
            violations.add('$where.${entry.key}[$index]: must be an object');
          }
        }
      }
      if (prop['type'] == 'array' &&
          prop.containsKey('items') &&
          value is List) {
        final items = prop['items'] as Map<String, dynamic>;
        for (final (index, item) in value.indexed) {
          if (items['type'] == 'string' && item is! String) {
            violations.add('$where.${entry.key}[$index]: must be a string');
          }
          if (items.containsKey('pattern') &&
              item is String &&
              !RegExp(items['pattern'] as String).hasMatch(item)) {
            violations.add(
              '$where.${entry.key}[$index]: "$item" violates the pattern',
            );
          }
        }
      }
      if (prop['type'] == 'object' &&
          value is Map &&
          prop.containsKey('additionalProperties') &&
          prop['additionalProperties'] is Map) {
        final valueSpec = prop['additionalProperties'] as Map<String, dynamic>;
        for (final entry2 in value.entries) {
          if (valueSpec['type'] == 'object' && entry2.value is! Map) {
            violations.add(
              '$where.${entry.key}.${entry2.key}: must be an object',
            );
          }
          if (valueSpec['type'] == 'string' && entry2.value is! String) {
            violations.add(
              '$where.${entry.key}.${entry2.key}: must be a string',
            );
          }
          if (valueSpec['type'] == 'object' && entry2.value is Map) {
            for (final entry3 in entry2.value.entries) {
              if (entry3.value is! String) {
                violations.add(
                  '$where.${entry.key}.${entry2.key}.${entry3.key}: must be a string',
                );
              }
            }
          }
        }
      }
    }
  }

  checkObject(contract, adaptiveContractSchema, 'contract');
  return violations;
}

/// Extracts the fenced ```json block under the `## Skin contract
/// (machine)` section of a skin plan; null when absent.
String? extractMachineContract(String skinPlan) {
  final section = RegExp(
    '^##\\s+Skin contract',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(skinPlan);
  if (section == null) return null;
  final region = skinPlan.substring(section.end);
  final open = RegExp('^```json\\s*\$', multiLine: true).firstMatch(region);
  if (open == null) return null;
  final close = region.indexOf('```', open.end);
  if (close < 0) return null;
  return region.substring(open.end, close).trim();
}

void main() {
  late Directory tmpDir;
  late String featureDir;
  late String tddDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('plan_skin_1004_');
    featureDir = p.join(tmpDir.path, 'specs', feature);
    tddDir = p.join(featureDir, 'tdd');
    Directory(tddDir).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedSpec(String spec) async {
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  }

  List<String> planArgs() => ['tdd', 'plan', '--project', tmpDir.path, feature];

  File laneFile(String name) => File(p.join(tddDir, name));

  Future<String> planSuccessfully() async {
    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(planArgs());
    expect(exitCode, 0, reason: out);
    return laneFile('04-SKIN.md').readAsString();
  }

  group('issue #1004 — plan renders the skin contract rows', () {
    test('04-SKIN.md carries the platform, state-machine, and route '
        'contract sections', () async {
      await seedSpec(skinContractSpec);
      final skin = await planSuccessfully();
      expect(
        skin.contains('## Platform contract'),
        isTrue,
        reason: 'the platform-contract section is present',
      );
      expect(
        skin.contains('## State machine contract'),
        isTrue,
        reason: 'the state-machine contract section is present',
      );
      expect(
        skin.contains('## Route contract'),
        isTrue,
        reason: 'the route-contract section is present',
      );
      expect(
        skin.toLowerCase().contains('## skin contract'),
        isTrue,
        reason: 'the machine contract section is present',
      );
    });

    test('platform rows: every adaptive slot with its overrides, tied to '
        'the skin behaviors', () async {
      await seedSpec(skinContractSpec);
      final skin = await planSuccessfully();
      // Scope to the platform-contract section so the Adaptive view
      // slots table (same `| ios |` shape) never shadows the rows.
      final platformSection = skin.substring(
        skin.indexOf('## Platform contract'),
      );
      final platformRows = platformSection
          .substring(0, platformSection.indexOf('## State machine'))
          .split('\n');
      // One row per adaptive platform.
      for (final platform in ['mobile', 'ios', 'android', 'macos']) {
        expect(
          platformRows.any((l) => l.startsWith('| $platform |')),
          isTrue,
          reason: 'platform row "$platform" rendered',
        );
      }
      // Platform overrides refine the row contract (the issue example:
      // "ios: home_indicator safe area; macos: title bar trailing").
      final iosRow = platformRows.firstWhere((l) => l.startsWith('| ios |'));
      expect(
        iosRow.contains('home_indicator_safe_area: required'),
        isTrue,
        reason: 'the ios override renders: $iosRow',
      );
      final macosRow = platformRows.firstWhere(
        (l) => l.startsWith('| macos |'),
      );
      expect(
        macosRow.contains('title_bar_alignment: trailing'),
        isTrue,
        reason: 'the macos override renders: $macosRow',
      );
      // Per SKIN behavior: the rows carry the skin-lane behavior ids.
      expect(
        platformRows
            .firstWhere((l) => l.startsWith('| mobile |'))
            .contains('W1'),
        isTrue,
        reason: 'the platform rows reference the skin behaviors',
      );
    });

    test('state-machine rows: initial -> loading -> data with error/empty '
        'alternates', () async {
      await seedSpec(skinContractSpec);
      final skin = await planSuccessfully();
      final lines = skin.split('\n');
      expect(
        lines
            .firstWhere((l) => l.startsWith('| initial |'))
            .contains('initial -> loading'),
        isTrue,
      );
      expect(
        lines
            .firstWhere((l) => l.startsWith('| loading |'))
            .contains('loading -> data'),
        isTrue,
      );
      expect(
        lines.firstWhere((l) => l.startsWith('| data |')).contains('terminal'),
        isTrue,
      );
      expect(
        lines
            .firstWhere((l) => l.startsWith('| error |'))
            .contains('alternate'),
        isTrue,
      );
      expect(
        lines
            .firstWhere((l) => l.startsWith('| empty |'))
            .contains('alternate'),
        isTrue,
      );
    });

    test('route rows: navigation target, screen class, route path', () async {
      await seedSpec(skinContractSpec);
      final skin = await planSuccessfully();
      expect(skin.contains('| login | LoginScreen | /login |'), isTrue);
      expect(
        skin.contains('| deal_list | DealListScreen | /deal_list |'),
        isTrue,
      );
      expect(
        skin.contains('| settings | SettingsScreen | /settings |'),
        isTrue,
      );
    });

    test(
      'the machine contract is JSON-parseable and schema-validated',
      () async {
        await seedSpec(skinContractSpec);
        final skin = await planSuccessfully();
        final json = extractMachineContract(skin);
        expect(json, isNotNull, reason: 'the fenced JSON block exists');
        // JSON-parseable: the exit criterion's literal check.
        final decoded = jsonDecode(json!) as Map<String, dynamic>;
        // Schema-validated: typed shape, no drift, no orphans.
        expect(schemaViolations(decoded), isEmpty);
        // The contract mirrors the spec declaration.
        expect(decoded['schemaVersion'], '1');
        expect(decoded['adaptiveSlots'], ['mobile', 'ios', 'android', 'macos']);
        expect((decoded['platformOverrides'] as Map<String, dynamic>)['ios'], {
          'home_indicator_safe_area': 'required',
        });
        expect(
          (decoded['platformOverrides'] as Map<String, dynamic>)['macos'],
          {'title_bar_alignment': 'trailing'},
        );
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
      },
    );

    test('TestListReader still resolves every behavior row (the contract '
        'sections are declarative, not behaviors)', () async {
      await seedSpec(skinContractSpec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 0, reason: out);
      final rows = await TestListReader(featureDir).read();
      expect(
        rows.map((r) => r.id).toSet(),
        containsAll(['A1', 'A2', 'A3', 'U1', 'W1']),
      );
    });
  });

  group('issue #1004 — plan refuses a broken skin contract', () {
    test('a Skin Contract with no ## Lanes section refuses (the contract '
        'rides the SKIN lane)', () async {
      final spec = skinContractSpec.replaceFirst(
        RegExp(r'## Lanes[\s\S]*?(?=## Skin Contract)'),
        '',
      );
      expect(spec.contains('## Lanes'), isFalse, reason: 'lanes removed');
      await seedSpec(spec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 2, reason: out);
      expect(
        out.contains('Lanes'),
        isTrue,
        reason: 'the refusal names the missing ## Lanes declaration',
      );
      expect(laneFile('04-SKIN.md').existsSync(), isFalse);
      expect(laneFile('test-list.md').existsSync(), isFalse);
    });

    test('an unknown contract key refuses naming the key', () async {
      final spec = skinContractSpec.replaceFirst(
        '  states: [initial, loading, data, error, empty]',
        '  states: [initial, loading, data, error, empty]\n'
            '  platform_matrix: [mobile]',
      );
      await seedSpec(spec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 2, reason: out);
      expect(
        out.contains('platform_matrix'),
        isTrue,
        reason: 'the refusal names the unknown key',
      );
      expect(laneFile('04-SKIN.md').existsSync(), isFalse);
    });

    test('adaptive_slots disagreeing with the SKIN lane refuses naming '
        'the drift', () async {
      final spec = skinContractSpec.replaceFirst(
        '  adaptive_slots: [mobile, ios, android, macos]\n'
            '  platform_overrides:',
        '  adaptive_slots: [mobile, ios]\n  platform_overrides:',
      );
      await seedSpec(spec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 2, reason: out);
      expect(
        out.toLowerCase().contains('adaptive_slots'),
        isTrue,
        reason: 'the refusal names the adaptive_slots drift',
      );
      expect(laneFile('04-SKIN.md').existsSync(), isFalse);
    });
  });

  group('issue #1004 — the real 004-login-ui spec and the template', () {
    late String repoRoot;

    setUp(() async {
      repoRoot = await findProjectRoot();
    });

    test('the spec for 004-login-ui contains the explicit Skin Contract '
        'section and plans green', () async {
      final specFile = File(
        p.join(repoRoot, 'example', 'specs', feature, 'spec.md'),
      );
      expect(specFile.existsSync(), isTrue);
      final spec = specFile.readAsStringSync();
      expect(
        RegExp(
          '^##\\s+Skin Contract',
          multiLine: true,
          caseSensitive: false,
        ).hasMatch(spec),
        isTrue,
        reason: 'the section heading is present',
      );
      for (final declared in [
        'adaptive_slots: [mobile, ios, android, macos]',
        'home_indicator_safe_area: required',
        'title_bar_alignment: trailing',
        'states: [initial, loading, data, error, empty]',
        'routes: [login, deal_list, settings]',
      ]) {
        expect(
          spec.contains(declared),
          isTrue,
          reason: 'the spec declares `$declared`',
        );
      }
      // The real spec file plans green with the contract rows.
      await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(planArgs());
      expect(exitCode, 0, reason: out);
      final skin = await laneFile('04-SKIN.md').readAsString();
      expect(skin.contains('## Platform contract'), isTrue);
      expect(skin.contains('## State machine contract'), isTrue);
      expect(skin.contains('## Route contract'), isTrue);
      expect(extractMachineContract(skin), isNotNull);
    });

    test('the spec template documents the Skin Contract grammar', () async {
      final template = File(
        p.join(repoRoot, '.specify', 'templates', 'spec-template.md'),
      ).readAsStringSync();
      for (final documented in [
        '## Skin Contract',
        'adaptive_slots: [mobile, ios, android, macos]',
        'platform_overrides:',
        'home_indicator_safe_area: required',
        'title_bar_alignment: trailing',
        'states: [initial, loading, data, error, empty]',
        'routes: [login, deal_list, settings]',
      ]) {
        expect(
          template.contains(documented),
          isTrue,
          reason: 'the template documents `$documented`',
        );
      }
    });
  });
}
