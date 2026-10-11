// Spec 1142 — adaptive layout contract: the Presentation table declares
// platform layout slots per feature, `zfa tdd view` emits an
// AdaptiveViewState skeleton with per-platform layout stubs (mobile,
// macos), and the coverage ledger traces each platform layout
// independently (a "mobile-only 100% traced" login is still missing
// macOS coverage) — rendered as a per-platform kind-coverage heatmap.
//
// Extends #1004 (skin contract slots) and #1102 (runtime skin auditor);
// the stub TODO placeholders follow the adaptive_layout_scaffold_builder
// pattern. Drives the public CLI surface (`zfa tdd view`) in-process
// against a TddFixture, mirroring the view_command_test.dart conventions:
//  U-1142-1: a Presentation contract declaring `adaptive_layouts: mobile,
//            macos` makes the view emit the AdaptiveViewState skeleton —
//            StatefulWidget + slot resolution + one layout stub per slot.
//  U-1142-2: each layout stub renders the composed scenario literals +
//            contract components AND carries the TODO placeholder
//            matching the adaptive_layout_scaffold_builder pattern; the
//            slot tokens never leak as component stand-ins.
//  U-1142-3: the generated skeleton is deterministic (byte-identical on
//            re-run inputs) and keeps the view-builder function name.
//  U-1142-4: no declared slots → the single-layout skeleton (zero drift
//            for features that never declare the contract).
//  U-1142-5: an unknown slot name refuses BEFORE any write
//            (errors-are-an-API) with a `--> fix:` line.
//  U-1142-6: per-platform ledger coverage — a green prover that
//            exercised only the mobile slot proves mobile rows, leaves
//            macos rows NOT-DONE (the aggregate is 100%, the platforms
//            are not).
//  U-1142-7: the heatmap renders per-platform kind-coverage
//            (kind × slot traced/total cells).
//  U-1142-8: the ledger artifacts render the platform section
//            (`# Platform Coverage Ledger` + heatmap) and the JSON
//            carries the per-platform rows.
//  U-1142-9: the contract parser reads the Presentation declaration and
//            refuses unknown slots by name.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/i18n_key_contract.dart';
import 'package:zuraffa/src/plugins/tdd/services/platform_coverage_ledger.dart';
import 'package:zuraffa/src/plugins/tdd/services/platform_layout_contract.dart';
import 'package:zuraffa/src/plugins/tdd/services/skin_event_trace.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';
import 'package:zuraffa/src/plugins/tdd/services/ui_ledger_projection.dart';
import 'package:zuraffa/src/tdd/services/ui_ledger_builder.dart';

import '../helpers/tdd_fixture.dart';

String genStyleWidgetStub(String id) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  return '''
// GENERATED STUB — `zfa tdd gen $id` (spec 044-test-tdd-generation).
library;

import 'package:flutter/material.dart';

/// View-builder subject for behavior $id.
///
/// Throws [UnimplementedError] until the real implementation lands.
Widget subject_$symbol() => throw UnimplementedError('subject_$symbol not implemented');
''';
}

/// Seed a Presentation contract declaring the [slots] as the feature's
/// platform layout contract (issue #1142). An empty [slots] seeds a
/// Presentation contract with NO layout declaration (zero-drift shape).
Future<void> seedAdaptivePresentationContract(
  TddFixture fx,
  List<String> slots,
) async {
  final list = File(fx.testListPath);
  await list.parent.create(recursive: true);
  await list.writeAsString('''
# Test List: ${fx.featureName}

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-001 | the login page shows 'Welcome back' with a sign in button | FR-001 | PENDING |

## Layer contracts

### Presentation

- `LoginSection`: `ShadInput` for email and password, `ShadButton` for Sign In
${slots.isEmpty ? '' : '- `adaptive_layouts`: ${slots.map((s) => '`$s`').join(', ')}'}

### Domain

- `AuthRepository`: `signIn`
''');
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    await Directory('${fx.root.path}/lib').create(recursive: true);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  Future<String> runView({String? id = 'A-001'}) {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(<String>[
      'tdd',
      'view',
      ?id,
      '--project',
      fx.root.path,
    ]);
  }

  test('U-1142-1: declared slots emit the AdaptiveViewState skeleton with '
      'per-platform layout stubs', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back' with a sign in button",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedAdaptivePresentationContract(fx, ['mobile', 'macos']);

    final out = await runView();

    expect(exitCode, 0, reason: 'out: $out');
    expect(
      out,
      contains(
        'view: behavior=A-001 outcome=scaffolded feature=${fx.featureName}',
      ),
    );
    expect(out, contains('mobile, macos — AdaptiveViewState'));
    final subject = await File(fx.subjectPathOf('A-001')).readAsString();
    // The AdaptiveViewState shape: StatefulWidget + slot resolution +
    // one branch per declared slot (the production login shape).
    expect(subject, contains('class A001View extends StatefulWidget {'));
    expect(
      subject,
      contains('State<A001View> createState() => _A001ViewState();'),
    );
    expect(subject, contains('String _resolveSlot(BuildContext context)'));
    expect(subject, contains("if (width < 600) return 'mobile';"));
    expect(subject, contains('case TargetPlatform.macOS:'));
    expect(subject, contains("'macos' => const A001ViewMacosLayout"));
    // Both platform layout stubs exist (mobile AND macos).
    expect(
      subject,
      contains('class A001ViewMobileLayout extends StatelessWidget {'),
    );
    expect(
      subject,
      contains('class A001ViewMacosLayout extends StatelessWidget {'),
    );
    // Per-slot keys identify the resolved branch (the production
    // `login-slot-<slot>` pattern).
    expect(subject, contains("Key('a001-slot-mobile')"));
    expect(subject, contains("Key('a001-slot-macos')"));
  });

  test('U-1142-2: each layout stub composes the declared surfaces AND '
      'carries the adaptive_layout_scaffold_builder TODO placeholder; '
      'slot tokens never leak as stand-ins', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back' with a sign in button",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedAdaptivePresentationContract(fx, ['mobile', 'macos']);

    final out = await runView();
    expect(exitCode, 0, reason: 'out: $out');

    final subject = await File(fx.subjectPathOf('A-001')).readAsString();
    // Scenario literals + declared components render inside EACH
    // platform layout so the paired test can flip green on every
    // declared slot.
    final mobileBlock = subject.substring(
      subject.indexOf('class A001ViewMobileLayout'),
    );
    expect(mobileBlock, contains("Text('Welcome back')"));
    expect(mobileBlock, contains('TextField(),'));
    final macosStart = subject.indexOf('class A001ViewMacosLayout');
    final macosBlock = subject.substring(macosStart);
    expect(macosBlock, contains("Text('Welcome back')"));
    // The TODO placeholder matches the adaptive_layout_scaffold_builder
    // pattern: `TODO: Implement <view> <target> layout`.
    expect(
      mobileBlock,
      contains("Text('TODO: Implement A001View mobile layout'"),
    );
    expect(
      macosBlock,
      contains("Text('TODO: Implement A001View macos layout'"),
    );
    // The slot-declaration tokens are NOT component stand-ins (the RED
    // repro rendered Text('mobile') / Text('macos') stand-ins).
    expect(subject, isNot(contains("Text('mobile')")));
    expect(subject, isNot(contains("Text('macos')")));
  });

  test('U-1142-3: deterministic — identical inputs render byte-identical '
      'adaptive skeletons', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back' with a sign in button",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedAdaptivePresentationContract(fx, ['mobile', 'macos']);

    final first = await runView();
    final rendered = await File(fx.subjectPathOf('A-001')).readAsString();

    // Reset to a fresh stub with the same inputs; re-run.
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    final second = await runView();
    final rerendered = await File(fx.subjectPathOf('A-001')).readAsString();

    expect(exitCode, 0, reason: 'first: $first / second: $second');
    expect(rerendered, rendered);
    // The view-builder function name is preserved (044 ownership).
    expect(rendered, contains('Widget subject_a_001() => A001View();'));
  });

  test('U-1142-4: no declared slots → the single-layout skeleton '
      '(zero drift)', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back' with a sign in button",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedAdaptivePresentationContract(fx, []);

    final out = await runView();
    expect(exitCode, 0, reason: 'out: $out');
    final subject = await File(fx.subjectPathOf('A-001')).readAsString();
    expect(subject, contains('class A001View extends StatelessWidget {'));
    expect(subject, isNot(contains('StatefulWidget')));
    expect(subject, isNot(contains('MacosLayout')));
  });

  test('U-1142-5: an unknown slot name refuses BEFORE any write '
      '(errors-are-an-API)', () async {
    await fx.registerBehavior(
      id: 'A-001',
      description: "the login page shows 'Welcome back' with a sign in button",
    );
    await File(
      fx.subjectPathOf('A-001'),
    ).writeAsString(genStyleWidgetStub('A-001'));
    await seedAdaptivePresentationContract(fx, ['mobile', 'pocketwatch']);

    final out = await runView();
    expect(exitCode, 1, reason: 'out: $out');
    expect(out, contains('unknown platform layout slot "pocketwatch"'));
    expect(out, contains('--> fix:'));
    expect(out, contains('outcome=runner-error'));
    // Refusal means no write: the stub is untouched.
    final subject = await File(fx.subjectPathOf('A-001')).readAsString();
    expect(subject, contains('UnimplementedError'));
  });

  test('U-1142-6: per-platform tracing — mobile-only evidence leaves '
      'macos rows NOT-DONE while the aggregate is green', () async {
    final surfaces = UiLedgerProjection.rows(
      behaviors: [
        const LedgerBehaviorInput(
          id: 'A-001',
          description: "the login page shows 'Welcome back'",
        ),
      ],
      keys: I18nKeyTable.empty,
      componentTokens: const [],
      greenBehaviors: {'A-001'},
    );
    expect(
      surfaces.every((r) => r.state == 'DONE'),
      isTrue,
      reason: 'aggregate is 100% traced',
    );

    // A-001 emitted a skin-event for mobile ONLY (issue #1005 stream).
    final trace = SkinEventTrace.parse(
      'skin-event: behavior=A-001 slot=mobile\n',
      phase: SkinPhase.green,
    );
    final rows = PlatformCoverageLedger.derive(
      aggregate: surfaces,
      slots: ['mobile', 'macos'],
      behaviorSlots: PlatformCoverageLedger.slotsFromTrace(trace),
    );

    final mobileRows = rows.where((r) => r.slot == 'mobile').toList();
    final macosRows = rows.where((r) => r.slot == 'macos').toList();
    expect(mobileRows, isNotEmpty);
    expect(macosRows, isNotEmpty);
    expect(
      mobileRows.every((r) => r.state == 'DONE'),
      isTrue,
      reason: 'mobile evidence proves the mobile rows',
    );
    expect(
      macosRows.every((r) => r.state == 'NOT-DONE'),
      isTrue,
      reason:
          'a mobile-only 100% traced login is still missing macOS '
          'coverage',
    );
  });

  test(
    'U-1142-7: the heatmap renders per-platform kind-coverage cells',
    () async {
      final surfaces = UiLedgerProjection.rows(
        behaviors: [
          const LedgerBehaviorInput(
            id: 'A-001',
            description:
                "the login page shows 'Welcome back' with a sign in button",
          ),
        ],
        keys: I18nKeyTable.empty,
        componentTokens: const [],
        greenBehaviors: {'A-001'},
      );
      final trace = SkinEventTrace.parse(
        'skin-event: behavior=A-001 slot=mobile\n',
        phase: SkinPhase.green,
      );
      final rows = PlatformCoverageLedger.derive(
        aggregate: surfaces,
        slots: ['mobile', 'macos'],
        behaviorSlots: PlatformCoverageLedger.slotsFromTrace(trace),
      );

      final heatmap = PlatformCoverageLedger.kindCoverageHeatmap(rows, [
        'mobile',
        'macos',
      ]);
      // The heatmap is a table: one row per kind, one cell per slot, each
      // cell carrying the traced/total fraction.
      expect(heatmap, contains('## Platform coverage heatmap'));
      expect(heatmap, contains('| kind | mobile | macos |'));
      expect(heatmap, contains('| text '));
      expect(heatmap, matches(RegExp(r'\| text \| 1/1 \| 0/1 \|')));
    },
  );

  test('U-1142-8: the ledger artifacts render the platform section and '
      'the JSON carries the per-platform rows', () async {
    final surfaces = UiLedgerProjection.rows(
      behaviors: [
        const LedgerBehaviorInput(
          id: 'A-001',
          description: "the login page shows 'Welcome back'",
        ),
      ],
      keys: I18nKeyTable.empty,
      componentTokens: const [],
    );
    final rows = PlatformCoverageLedger.derive(
      aggregate: surfaces,
      slots: ['mobile', 'macos'],
      behaviorSlots: const {},
    );
    final md =
        '${UiLedgerBuilder.toMarkdown(surfaces)}\n'
        '${PlatformCoverageLedger.toMarkdown(rows)}';
    expect(md, contains('# UI Surface Ledger'));
    expect(md, contains('# Platform Coverage Ledger'));
    expect(md, contains('## Platform coverage heatmap'));
    expect(md, contains('mobile'));
    expect(md, contains('macos'));

    final decoded =
        jsonDecode(PlatformCoverageLedger.toJson(rows)) as List<dynamic>;
    expect(decoded, hasLength(2 * surfaces.length));
    expect(decoded.first, containsPair('slot', 'mobile'));
    expect(
      decoded.map((r) => r['slot']),
      everyElement(anyOf('mobile', 'macos')),
    );
  });

  test('U-1142-9: the contract parser reads the Presentation declaration '
      'and refuses unknown slots by name', () {
    final contracts = const SpecParser().parseLayerContracts('''
### Layer Contracts

**Presentation**:
- `LoginSection`: `ShadInput`, `ShadButton`
- `adaptive_layouts`: `mobile`, `macos`

**Domain**:
- `AuthRepository`: `signIn`
''');
    final contract = PlatformLayoutContract.fromContracts(contracts);
    expect(contract, isNotNull);
    expect(contract!.slots, ['mobile', 'macos']);

    // Domain-layer declarations never contribute.
    final domainOnly = PlatformLayoutContract.fromContracts([
      const LayerContract(
        layer: 'Domain',
        interfaceName: 'adaptive_layouts',
        methods: ['mobile'],
      ),
    ]);
    expect(domainOnly, isNull);

    // Unknown slot refuses by name (errors-are-an-API).
    expect(
      () => PlatformLayoutContract.fromContracts([
        const LayerContract(
          layer: 'Presentation',
          interfaceName: 'adaptive_layouts',
          methods: ['mobile', 'pocketwatch'],
        ),
      ]),
      throwsA(
        isA<PlatformLayoutContractException>().having(
          (e) => e.message,
          'message',
          contains('pocketwatch'),
        ),
      ),
    );
  });
}
