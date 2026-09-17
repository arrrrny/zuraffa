// Spec 1693 (issue #1693) — the `zfa tdd run` pre-start preflight
// (RunEngineCommand.checkFeature) must not refuse after FORMAT-ONLY
// drift, and must still refuse after a real entity edit.
//
// This is the repro loop from the issue, driven at the preflight entry:
// certify an entity → the phase-2 refactor (`dart format lib/`, spec
// 1652) reformats the tree → re-run the gate. Pre-fix the second run
// refused ("CORE entity ... has a mock on disk that is NOT certified");
// with the format-canonical entity digest recorded in the receipt
// (spec 1693) the format-normalized source hashes equal and the run
// proceeds — while a real edit still refuses with the exact fix.
//
// (The gate-level red→green cycle lives in
// test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart;
// this file pins the same verdicts through the run preflight wiring.)
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/commands/run_engine_command.dart';

String canonicalDigestOf(String source) {
  final formatted = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  ).format(source);
  return sha256.convert(utf8.encode(formatted)).toString();
}

void main() {
  late Directory tempDir;
  late String projectRoot;
  late String featureDir;

  const certifiedSource = '''
class UserSession {
  final String id;
  final String token;
  const UserSession({required this.id, required this.token});
}
''';

  // The phase-2 `dart format` shape of the same declaration.
  const formatDriftedSource =
      'class UserSession {\n'
      '   final String id;\n'
      '      final String token;\n'
      '  const UserSession({required this.id,   required this.token});\n'
      '}';

  // A real edit after certification: a new field.
  const semanticDriftSource = '''
class UserSession {
  final String id;
  final String token;
  final String device;
  const UserSession({required this.id, required this.token});
}
''';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1693_preflight_');
    projectRoot = tempDir.path;
    featureDir = p.join(projectRoot, 'specs', '1693-format-drift');
    Directory(p.join(featureDir, 'tdd')).createSync(recursive: true);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void writeTestList() {
    File(p.join(featureDir, 'tdd', 'test-list.md')).writeAsStringSync(
      '# Test list\n\n'
      '## Key Entities\n\n'
      '| Entity | Fields |\n'
      '| --- | --- |\n'
      '| | |\n'
      '| UserSession | id:String,token:String |\n',
    );
  }

  void writeEntity(String source, {DateTime? modified}) {
    final file = File(
      p.join(
        projectRoot,
        'lib',
        'src',
        'domain',
        'entities',
        'user_session',
        'user_session.dart',
      ),
    );
    file.createSync(recursive: true);
    file.writeAsStringSync(source);
    if (modified != null) {
      file.setLastModifiedSync(modified);
    }
  }

  void writeMockDatasource() {
    final file = File(
      p.join(
        projectRoot,
        'lib',
        'src',
        'data',
        'datasources',
        'user_session',
        'user_session_mock_datasource.dart',
      ),
    );
    file.createSync(recursive: true);
    file.writeAsStringSync('// GENERATED - DO NOT EDIT\n');
  }

  void writeReceipt(String entityDigest, {DateTime? modified}) {
    final file = File(
      p.join(
        projectRoot,
        'test',
        'mock',
        'user_session',
        'mock-cert.UserSession.json',
      ),
    );
    file.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'schema': 1,
        'spec': 1001,
        'entity': 'UserSession',
        'interface': 'UserSessionDataSource',
        'contract_digest': 'abc123',
        'entity_digest': entityDigest,
        'methods': [
          {'name': 'get', 'satisfied': true},
          {'name': 'update', 'satisfied': true},
        ],
        'sandbox': const {
          'runner': 'dart',
          'analyze_issues': 0,
          'analyze_errors': 0,
        },
        'certified_at': '2026-09-17T00:00:00.000Z',
      }),
    );
    if (modified != null) {
      file.setLastModifiedSync(modified);
    }
  }

  final certifiedAt = DateTime(2026, 9, 17, 12);
  final refactoredAt = DateTime(2026, 9, 18, 12);

  test('the preflight certifies after phase-2 format-only drift — no second '
      'sandbox certification demanded (the #1693 repro, green)', () async {
    writeTestList();
    writeEntity(certifiedSource, modified: certifiedAt);
    writeMockDatasource();
    writeReceipt(canonicalDigestOf(certifiedSource), modified: certifiedAt);

    // Run #1: certified.
    final first = await RunEngineCommand.checkFeature(
      projectRoot: projectRoot,
      featureDir: featureDir,
    );
    expect(first.ok, isTrue, reason: first.blockedReason);
    expect(first.certified, ['UserSession']);

    // The phase-2 refactor formats the tree (bytes change, mtime moves,
    // the declaration does not).
    writeEntity(formatDriftedSource, modified: refactoredAt);

    // Run #2: must NOT refuse — format-only drift is not staleness.
    final second = await RunEngineCommand.checkFeature(
      projectRoot: projectRoot,
      featureDir: featureDir,
    );
    expect(second.ok, isTrue, reason: second.blockedReason);
    expect(second.certified, ['UserSession']);
    expect(second.uncertified, isEmpty);
  });

  test('the preflight still refuses after a real entity edit — the '
      'spec-1110 gate is intact through the run wiring', () async {
    writeTestList();
    writeEntity(certifiedSource, modified: certifiedAt);
    writeMockDatasource();
    writeReceipt(canonicalDigestOf(certifiedSource), modified: certifiedAt);

    // A field is added after certification.
    writeEntity(semanticDriftSource, modified: refactoredAt);

    final result = await RunEngineCommand.checkFeature(
      projectRoot: projectRoot,
      featureDir: featureDir,
    );
    expect(result.ok, isFalse);
    expect(result.blockedEntity, 'UserSession');
    expect(result.blockedReason, contains('stale'));
    expect(result.blockedFix, 'zfa mock create UserSession --certify');
  });
}
