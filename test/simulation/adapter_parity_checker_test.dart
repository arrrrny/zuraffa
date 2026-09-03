/// Bug #915 — the differential harness: fixture parity between mock and
/// real adapters.
///
/// The parity harness turns the landed #832 simulate adapters into the
/// realization measuring stick:
///
/// - **fixture contract** — one committed fixture pair per adapter
///   contract (`tdd/fixtures/<contract>/mock.json` + `real.json`),
///   consumed by BOTH the mock (source of responses) and the realize
///   differential (expected outputs from real).
/// - **schema-parity checker** — the mock fixture's shape must equal the
///   real response shape; drift is a NAMED verdict (field-level path +
///   both sides) with the drift exit class.
/// - **fault-injection parity** — the failure scenarios the mock
///   rehearses (timeouts, 5xx, corrupted payloads) must have real-lane
///   counterparts; a fault declared on only one side is a named verdict.
/// - **corpus rollup** — per-adapter parity scores surfaced in corpus
///   reports (status / audit), reported never invented.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/adapter_parity_checker.dart';

import '../plugins/tdd/helpers/corpus_fixture.dart';

/// Writes one committed fixture pair under
/// `<featureDir>/tdd/fixtures/<contract>/`.
Future<String> writeFixturePair(
  String featureDir,
  String contract, {
  Map<String, dynamic>? mock,
  Map<String, dynamic>? real,
}) async {
  final dir = Directory('$featureDir/tdd/fixtures/$contract')
    ..createSync(recursive: true);
  for (final (name, body) in [('mock.json', mock), ('real.json', real)]) {
    if (body == null) continue;
    File('${dir.path}/$name').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(body)}\n',
    );
  }
  return dir.path;
}

/// A matching mock/real pair for the rest-quotes contract: identical
/// shapes (field names, types, nesting), different VALUES (parity is
/// shape, not bytes).
Map<String, dynamic> matchingMock() => <String, dynamic>{
  'schema': 1,
  'bug': 915,
  'contract': 'rest-quotes',
  'adapterFamily': 'rest',
  'zorphyType': 'MarketQuote',
  'operations': {
    'GET /v1/quote/USD-TRY': {
      'symbol': 'USD-TRY',
      'price': 41.2,
      'change': -0.15,
      'source': {'name': 'market', 'tier': 1},
    },
    'GET /v1/search?q=kayak': {
      'results': [
        {'title': 'Kayak 1', 'price': 2499.0},
        {'title': 'Kayak 2', 'price': 3199.0},
      ],
    },
  },
  'faults': {
    'timeout': {'kind': 'timeout', 'detail': 'socket timeout after 30s'},
    'http-5xx': {'kind': 'http-5xx', 'status': 500},
    'corrupted-payload': {
      'kind': 'corrupted-payload',
      'detail': 'truncated body',
    },
  },
};

Map<String, dynamic> matchingReal() => <String, dynamic>{
  'schema': 1,
  'bug': 915,
  'contract': 'rest-quotes',
  'adapterFamily': 'rest',
  'zorphyType': 'MarketQuote',
  'operations': {
    'GET /v1/quote/USD-TRY': {
      'symbol': 'USD-TRY',
      'price': 41.75,
      'change': 0.4,
      'source': {'name': 'live-feed', 'tier': 2},
    },
    'GET /v1/search?q=kayak': {
      'results': [
        {'title': 'Sea Kayak', 'price': 2699.0},
      ],
    },
  },
  'faults': {
    'timeout': {'kind': 'timeout', 'detail': 'recorded real timeout'},
    'http-5xx': {'kind': 'http-5xx', 'status': 503},
    'corrupted-payload': {
      'kind': 'corrupted-payload',
      'detail': 'recorded real corruption',
    },
  },
};

void main() {
  late Directory workspace;
  late String featureDir;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa-parity-915');
    featureDir = '${workspace.path}/specs/067-tdd-realize-mock-swap';
  });

  tearDown(() async {
    await workspace.delete(recursive: true);
  });

  group('fixture contract (mock.json + real.json per adapter contract)', () {
    test('loads a committed pair and preserves contract provenance', () async {
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: matchingReal(),
      );
      final fixtures = AdapterContractFixtures.load(featureDir, 'rest-quotes');
      expect(fixtures.contract, 'rest-quotes');
      expect(fixtures.mock['zorphyType'], 'MarketQuote');
      expect(fixtures.real['adapterFamily'], 'rest');
    });

    test(
      'a missing side is an incomplete verdict, never a silent pass',
      () async {
        await writeFixturePair(featureDir, 'rest-quotes', mock: matchingMock());
        final report = AdapterParityChecker.checkContract(
          featureDir,
          'rest-quotes',
        );
        expect(report.verdict, ParityVerdict.incomplete);
        expect(report.detail, contains('real.json'));
      },
    );

    test('an unknown contract dir is incomplete with the named path', () async {
      final report = AdapterParityChecker.checkContract(
        featureDir,
        'no-such-contract',
      );
      expect(report.verdict, ParityVerdict.incomplete);
      expect(report.detail, contains('no-such-contract'));
    });
  });

  group('schema-parity checker (shape, not bytes)', () {
    test('matching shapes across both lanes is a match verdict', () async {
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: matchingReal(),
      );
      final report = AdapterParityChecker.checkContract(
        featureDir,
        'rest-quotes',
      );
      expect(report.verdict, ParityVerdict.match);
      expect(report.drifts, isEmpty);
    });

    test('field-name drift is named with the field-level path', () async {
      final real = matchingReal()
        ..['operations']['GET /v1/quote/USD-TRY']['ticker'] = 'USD-TRY'
        ..['operations']['GET /v1/quote/USD-TRY'].remove('symbol');
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: real,
      );
      final report = AdapterParityChecker.checkContract(
        featureDir,
        'rest-quotes',
      );
      expect(report.verdict, ParityVerdict.drift);
      expect(
        report.drifts.map((d) => d.toString()).join('\n'),
        contains('symbol'),
      );
    });

    test('type drift (string vs number) is a named verdict', () async {
      final real = matchingReal()
        ..['operations']['GET /v1/quote/USD-TRY']['price'] = '41.75';
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: real,
      );
      final report = AdapterParityChecker.checkContract(
        featureDir,
        'rest-quotes',
      );
      expect(report.verdict, ParityVerdict.drift);
      final text = report.drifts.map((d) => d.toString()).join('\n');
      expect(text, contains('price'));
      expect(text, contains('number'));
      expect(text, contains('string'));
    });

    test('nesting drift (object vs leaf) is a named verdict', () async {
      final real = matchingReal()
        ..['operations']['GET /v1/quote/USD-TRY']['source'] = 'live-feed';
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: real,
      );
      final report = AdapterParityChecker.checkContract(
        featureDir,
        'rest-quotes',
      );
      expect(report.verdict, ParityVerdict.drift);
      final text = report.drifts.map((d) => d.toString()).join('\n');
      expect(text, contains('source'));
      expect(text, contains('object'));
    });

    test('int vs double is the same number type, never false drift', () async {
      final real = matchingReal()
        ..['operations']['GET /v1/quote/USD-TRY']['change'] = 0;
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: real,
      );
      final report = AdapterParityChecker.checkContract(
        featureDir,
        'rest-quotes',
      );
      expect(report.verdict, ParityVerdict.match);
    });

    test('list element shape drift is caught', () async {
      final real = matchingReal()
        ..['operations']['GET /v1/search?q=kayak'] = {
          'results': ['Sea Kayak'],
        };
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: real,
      );
      final report = AdapterParityChecker.checkContract(
        featureDir,
        'rest-quotes',
      );
      expect(report.verdict, ParityVerdict.drift);
      final text = report.drifts.map((d) => d.toString()).join('\n');
      expect(text, contains('results'));
      expect(text, contains('object'));
      expect(text, contains('string'));
    });

    test(
      'the drift exit class is 2 (named verdict, machine contract)',
      () async {
        final real = matchingReal()
          ..['operations']['GET /v1/quote/USD-TRY']['price'] = '41.75';
        await writeFixturePair(
          featureDir,
          'rest-quotes',
          mock: matchingMock(),
          real: real,
        );
        final report = AdapterParityChecker.checkContract(
          featureDir,
          'rest-quotes',
        );
        expect(report.exitCode, 2);
      },
    );
  });

  group('fault-injection parity (mock failures triggerable against real)', () {
    test('fault kinds present on both sides replay as parity', () async {
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: matchingReal(),
      );
      final report = AdapterParityChecker.checkContract(
        featureDir,
        'rest-quotes',
        full: true,
      );
      expect(report.verdict, ParityVerdict.match);
      expect(report.faultDrifts, isEmpty);
    });

    test('a timeout rehearsed by the mock but missing on the real lane '
        'is a named fault drift', () async {
      final real = matchingReal()..remove('faults');
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: real,
      );
      final report = AdapterParityChecker.checkContract(
        featureDir,
        'rest-quotes',
        full: true,
      );
      expect(report.verdict, ParityVerdict.drift);
      final text = report.faultDrifts.map((d) => d.toString()).join('\n');
      expect(text, contains('timeout'));
      expect(text, contains('http-5xx'));
      expect(text, contains('corrupted-payload'));
    });

    test(
      'shape parity alone does not run the fault gate without --full',
      () async {
        final real = matchingReal()..remove('faults');
        await writeFixturePair(
          featureDir,
          'rest-quotes',
          mock: matchingMock(),
          real: real,
        );
        final report = AdapterParityChecker.checkContract(
          featureDir,
          'rest-quotes',
        );
        expect(report.faultDrifts, isEmpty);
      },
    );
  });

  group(
    'corpus rollup (per-adapter parity scores, reported never invented)',
    () {
      test('scores each contract and rolls the feature up', () async {
        await writeFixturePair(
          featureDir,
          'rest-quotes',
          mock: matchingMock(),
          real: matchingReal(),
        );
        await writeFixturePair(
          featureDir,
          'auth-users',
          mock: matchingMock()..['contract'] = 'auth-users',
          real: matchingReal()..['contract'] = 'auth-users',
        );
        final rollup = AdapterParityChecker.rollupForFeature(featureDir);
        expect(rollup.contracts, ['auth-users', 'rest-quotes']);
        expect(rollup.matched, 2);
        expect(rollup.drifted, 0);
        expect(rollup.score, 1.0);
      });

      test('a drifted contract lowers the score and is named', () async {
        final real = matchingReal()
          ..['operations']['GET /v1/quote/USD-TRY']['price'] = '41.75';
        await writeFixturePair(
          featureDir,
          'rest-quotes',
          mock: matchingMock(),
          real: real,
        );
        final rollup = AdapterParityChecker.rollupForFeature(featureDir);
        expect(rollup.drifted, 1);
        expect(rollup.score, 0.0);
        expect(rollup.summaryLine, contains('drifted=1'));
      });

      test('a feature with no contract fixtures has a null score', () async {
        final rollup = AdapterParityChecker.rollupForFeature(featureDir);
        expect(rollup.contracts, isEmpty);
        expect(rollup.score, isNull);
        expect(rollup.summaryLine, contains('contracts=0'));
      });
    },
  );

  group('zfa tdd diff-check (the command surface)', () {
    Future<(int, String)> runZfa(List<String> args) async {
      final runner = CliRunner(exitOnCompletion: false);
      final output = await runner.runCapturing(args);
      return (exitCode, output);
    }

    test('registers under the tdd command', () async {
      final (code, output) = await runZfa(['tdd', '--help']);
      expect(code, 0);
      expect(output, contains('diff-check'));
    });

    test('matching fixture pair exits 0 with the machine summary', () async {
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: matchingReal(),
      );
      final (code, output) = await runZfa([
        'tdd',
        'diff-check',
        '--project',
        workspace.path,
        '--feature',
        '067-tdd-realize-mock-swap',
      ]);
      expect(code, 0, reason: output);
      expect(output, contains('diff-check: contracts=1 matched=1 drifted=0'));
      expect(output, contains('result=match'));
    });

    test('drift exits 2 and names the field-level difference', () async {
      final real = matchingReal()
        ..['operations']['GET /v1/quote/USD-TRY']['price'] = '41.75';
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: real,
      );
      final (code, output) = await runZfa([
        'tdd',
        'diff-check',
        '--project',
        workspace.path,
        '--feature',
        '067-tdd-realize-mock-swap',
      ]);
      expect(code, 2, reason: output);
      expect(output, contains('result=drift'));
      expect(output, contains('price'));
    });

    test('--full runs the fault-injection parity gate too', () async {
      final real = matchingReal()..remove('faults');
      await writeFixturePair(
        featureDir,
        'rest-quotes',
        mock: matchingMock(),
        real: real,
      );
      final (code, output) = await runZfa([
        'tdd',
        'diff-check',
        '--project',
        workspace.path,
        '--feature',
        '067-tdd-realize-mock-swap',
        '--full',
      ]);
      expect(code, 2, reason: output);
      expect(output, contains('fault drift'));
      expect(output, contains('timeout'));
    });

    test(
      'incomplete fixture sets refuse honestly without a false verdict',
      () async {
        await writeFixturePair(featureDir, 'rest-quotes', mock: matchingMock());
        final (code, output) = await runZfa([
          'tdd',
          'diff-check',
          '--project',
          workspace.path,
          '--feature',
          '067-tdd-realize-mock-swap',
        ]);
        expect(code, 1, reason: output);
        expect(output, contains('result=incomplete'));
        expect(output, contains('real.json'));
      },
    );
  });

  group('corpus rollup surface (corpus status / corpus audit)', () {
    test(
      'corpus status surfaces the parity score for features with '
      'committed contract fixtures, and no line for features without',
      () async {
        final fx = await CorpusFixture.create();
        try {
          await fx.writeManifest([
            (name: 'f1-parity', ready: true, reason: ''),
            (name: 'f2-plain', ready: true, reason: ''),
          ]);
          await writeFixturePair(
            '${fx.root.path}/specs/f1-parity',
            'rest-quotes',
            mock: matchingMock(),
            real: matchingReal(),
          );
          final runner = CliRunner(exitOnCompletion: false);
          final out = await runner.runCapturing([
            'tdd',
            'corpus',
            'status',
            '--project',
            fx.root.path,
          ]);
          expect(out, contains('parity: f1-parity contracts=1 matched=1'));
          expect(out, contains('score=1.00'));
          expect(out, isNot(contains('parity: f2-plain')));
        } finally {
          fx.dispose();
          exitCode = 0;
        }
      },
    );

    test('corpus audit surfaces the parity rollup for spec features with '
        'committed contract fixtures', () async {
      final fx = await CorpusFixture.create();
      try {
        final lib = Directory('${fx.root.path}/lib/src')
          ..createSync(recursive: true);
        File('${lib.path}/main.dart').writeAsStringSync('void main() {}\n');
        await writeFixturePair(
          '${fx.root.path}/specs/f1-parity',
          'rest-quotes',
          mock: matchingMock(),
          real: matchingReal(),
        );
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'corpus',
          'audit',
          '--project',
          fx.root.path,
        ]);
        expect(out, contains('parity: f1-parity contracts=1 matched=1'));
      } finally {
        fx.dispose();
        exitCode = 0;
      }
    });
  });
}
