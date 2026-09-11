// Bug #1480 (fix lever 1) — the spec↔contract mapping is decoupled from
// spec.md: `zfa tdd plan` reads contract rows and FR traces from the
// feature's `contracts/*.md` files (the contracts directory the planning
// phase already writes) in addition to spec.md, so a spec-kit-authored
// spec WITHOUT inline zuraffa grammar resolves its unit lane as DECLARED
// instead of dead-ending the unit lane at make (vacuous-green).
//
// Fix contract:
//   - rows from contracts/*.md merge with spec.md rows (duplicate row
//     names across sources REFUSE naming both — never a silent win)
//   - criterion-keyed traces (`- **FR-001**: traces: Row`) bind by FR id,
//     filling behaviors with no inline spec trace
//   - an FR traced from BOTH spec.md and a contracts file REFUSES
//   - a criterion trace naming an unknown FR WARNS (parity with #1319)
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const _grammarlessSpec = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1480-decoupled

## Functional Requirements

- **FR-001**: the system formats the user's template into a rendered string
- **FR-002**: the system persists the rendered result

## Acceptance Scenarios

1. **Given** a rendered template **When** the user opens the page **Then** the
   rendered content is shown.
   **Type**: acceptance
''';

const _contractsFile = '''
# Contract: rendering seam (held beside the spec, issue #1480)

## Layer Contracts

**Function**:
- `Formatter`: `format(Template) -> String`

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| RenderedResult | `text: String` | The rendered output the loop persists |

## Contract Traces

- **FR-001**: traces: Formatter.format
- **FR-002**: traces: RenderedResult
''';

Future<(Directory, String)> _feature(String spec, {String? contracts}) async {
  final tmp = Directory.systemTemp.createTempSync('decoupled1480_');
  final featureDir = p.join(tmp.path, 'specs', '1480-decoupled');
  await Directory(featureDir).create(recursive: true);
  await File(p.join(featureDir, 'spec.md')).writeAsString(spec);
  if (contracts != null) {
    final contractsDir = Directory(p.join(featureDir, 'contracts'));
    await contractsDir.create(recursive: true);
    await File(
      p.join(contractsDir.path, 'layer-contracts.md'),
    ).writeAsString(contracts);
  }
  return (tmp, featureDir);
}

Future<String> _plan(Directory tmp, [List<String> extra = const []]) async {
  final runner = CliRunner(exitOnCompletion: false);
  final out = await runner.runCapturing([
    'tdd',
    'plan',
    '1480-decoupled',
    '--project',
    tmp.path,
    ...extra,
  ]);
  return out;
}

void main() {
  late Directory tmpDir;
  late String featureDir;

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    CliRunner.lastDispatchedExitCode = 0;
  });

  group('bug #1480 — the mapping may live in contracts/*.md', () {
    test('U1+A1: a grammarless spec + a contracts file plans DECLARED '
        '(unit lane routes by the declared contract row, exit 0)', () async {
      (tmpDir, featureDir) = await _feature(
        _grammarlessSpec,
        contracts: _contractsFile,
      );

      final out = await _plan(tmpDir);

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason:
            'the declared mapping lives beside the spec — the plan must '
            'resolve it (issue #1480): out was\n$out',
      );
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(testList.existsSync(), isTrue, reason: out);
      final routing = testList.readAsStringSync();
      expect(
        routing,
        contains('[declared: contract row: Formatter'),
        reason:
            'U1 must route by the contract row declared in the contracts '
            'file — not the legacy fallback; routing was\n$routing',
      );
      expect(routing, isNot(contains('[fallback:')));
    });

    test('U1b: a criterion trace naming an UNKNOWN FR warns and the plan '
        'still proceeds (parity with the #1319 unbound warning)', () async {
      (tmpDir, featureDir) = await _feature(
        _grammarlessSpec,
        contracts: _contractsFile.replaceFirst(
          '- **FR-001**: traces: Formatter.format',
          '- **FR-001**: traces: Formatter.format\n'
              '- **FR-999**: traces: Formatter.format',
        ),
      );

      final out = await _plan(tmpDir);

      expect(
        out,
        contains('FR-999'),
        reason: 'the unknown criterion trace is warned about (not silent)',
      );
      expect(
        containsIgnoringCase(out, 'warning'),
        isTrue,
        reason: 'the message is a warning, not a refusal: out was\n$out',
      );
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(
        testList.existsSync(),
        isTrue,
        reason: 'a warning never blocks the plan',
      );
    });

    test('U5a: a contract row declared in BOTH spec.md and the contracts '
        'file refuses naming both sources (never a silent win)', () async {
      final bothRows = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1480-decoupled

## Layer Contracts

**Function**:
- `Formatter`: `format(Template) -> String`

## Functional Requirements

- **FR-001**: the system formats the user's template

## Acceptance Scenarios

1. **Given** a template **When** it renders **Then** the string returns.
   **Type**: acceptance
''';
      (tmpDir, featureDir) = await _feature(
        bothRows,
        contracts: _contractsFile,
      );

      final out = await _plan(tmpDir);

      expect(
        CliRunner.lastDispatchedExitCode,
        2,
        reason:
            'duplicate declaration across sources refuses (exit 2): '
            'out was\n$out',
      );
      expect(out, contains('Formatter'));
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(
        testList.existsSync(),
        isFalse,
        reason: 'a refused plan writes no artifacts',
      );
    });

    test('U5b: an FR traced from BOTH spec.md and the contracts file refuses '
        'naming both (double declaration)', () async {
      final inlineTraced = _grammarlessSpec.replaceFirst(
        '- **FR-001**: the system formats the user\'s template into a rendered string',
        '- **FR-001**: the system formats the user\'s template into a rendered string\n'
            '            traces: SomethingElse',
      );
      (tmpDir, featureDir) = await _feature(
        inlineTraced,
        contracts: _contractsFile,
      );

      final out = await _plan(tmpDir);

      expect(
        CliRunner.lastDispatchedExitCode,
        2,
        reason: 'a double-declared trace refuses (exit 2): out was\n$out',
      );
      expect(out, contains('FR-001'));
      final testList = File(p.join(featureDir, 'tdd', 'test-list.md'));
      expect(
        testList.existsSync(),
        isFalse,
        reason: 'a refused plan writes no artifacts',
      );
    });
  });
}

bool containsIgnoringCase(String haystack, String needle) =>
    haystack.toLowerCase().contains(needle.toLowerCase());
