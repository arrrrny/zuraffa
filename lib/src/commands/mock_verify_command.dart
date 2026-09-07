import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli/exit_protocol.dart';
import '../core/verdict_envelope.dart';
import '../models/generated_file.dart';
import '../plugins/mock/mock_plugin.dart';
import '../plugins/mock/services/mock_certification.dart';
import '../utils/string_utils.dart';

/// SPEC 1121 (issue #1121, order 1) — `zfa mock verify <Entity>`.
///
/// Read-only re-certification: re-runs the SAME certification gate
/// `zfa mock create <Entity> --certify` uses — [MockCertificationService.certify]
/// computes the `MockCertification` from the mock files already on disk and
/// the current entity source (interface members vs mock members, AST), then
/// [MockCertifier.gate] turns it into a `CertifyReport` (structural drift +
/// scoped `dart analyze`). Verify is NOT a duplicate of MockCertify: it
/// generates nothing, writes no receipt, and touches no registry — certify
/// stays the generation + certification combo.
///
/// Exit codes (spec 917, mirroring the sibling verify verb
/// `ServiceVerifyCommand`, spec 1127): 0 = conforms, 1 = drift / missing
/// artifacts (every finding carries a `--> fix:` line), 2 = usage.
/// `--json` emits one canonical `zuraffa.verdict.v1` envelope (issue #1105)
/// as the LAST stdout line; diagnostics go to stderr.
class MockVerifyCommand extends Command<void> {
  final MockPlugin plugin;

  /// Project root the mock tree resolves from. Defaults to the CWD (the CLI
  /// contract); injectable so tests can point at a temp fixture.
  final String? projectRoot;

  MockVerifyCommand(this.plugin, {this.projectRoot}) {
    argParser.addOption(
      'name',
      help: 'Entity name (alternative to the positional argument)',
    );
    argParser.addOption(
      'project',
      help:
          'Project root containing lib/src (defaults to the current '
          'working directory)',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit one canonical ${VerdictEnvelope.canonicalSchema} envelope '
          'on stdout (CI-able, issue #1105)',
    );
  }

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Re-run the certification gate against the mock files on disk '
      '(read-only) — exit 1 with --> fix: lines on drift (spec 1121)';

  @override
  Future<void> run() async {
    final results = argResults;
    // SPEC 917 / #904: --name is the manifest-driven spelling of the
    // positional EntityName (positional keeps precedence, issue #771).
    final flaggedName = results?['name'] as String?;
    final positional = results?.rest.isNotEmpty == true
        ? results!.rest.first.trim()
        : null;
    if ((positional == null || positional.isEmpty) &&
        (flaggedName == null || flaggedName.isEmpty)) {
      final usage = 'zfa mock verify <Entity> [--json] [--project <dir>]';
      final fix = ExitProtocol.fixLine(
        're-run with the entity whose mock is verified — `$usage` '
        '(after `zfa mock create <Entity> --certify`)',
      );
      if (results?['json'] == true) {
        stderr.writeln('❌ Usage: $usage');
        stderr.writeln(fix);
      } else {
        // ignore: avoid_print
        print('❌ Usage: $usage');
        // ignore: avoid_print
        print(fix);
      }
      exitCode = ExitProtocol.usage;
      return;
    }

    final jsonMode = results?['json'] == true;
    final projectFlag = results?['project'] as String?;
    final root =
        projectRoot ??
        (projectFlag == null || projectFlag.isEmpty
            ? Directory.current.path
            : p.absolute(projectFlag));
    final entity = StringUtils.convertToPascalCase(
      (positional ?? flaggedName!).trim(),
    );
    if (entity.isEmpty) {
      _refuse(
        jsonMode: jsonMode,
        entity: entity,
        kind: 'usage',
        message: '`${positional ?? flaggedName}` does not name an entity',
        fix:
            're-run with the entity whose mock is verified — '
            '`zfa mock verify <Entity>`',
        code: ExitProtocol.usage,
      );
      return;
    }

    // ── Artifact resolution: the entity-mode datasource pair, exactly the
    //    shapes MockCertificationService.certify resolves for generation. ──
    final entitySnake = StringUtils.camelToSnake(entity);
    final interfaceClass = '${entity}DataSource';
    final mockClass = '${entity}MockDataSource';
    final interfacePath = p.join(
      plugin.outputDir,
      'data',
      'datasources',
      entitySnake,
      '${entitySnake}_datasource.dart',
    );
    final mockPath = p.join(
      plugin.outputDir,
      'data',
      'datasources',
      entitySnake,
      '${entitySnake}_mock_datasource.dart',
    );
    final mockDataPath = p.join(
      plugin.outputDir,
      'data',
      'mock',
      '${entitySnake}_mock_data.dart',
    );

    if (!File(p.join(root, mockPath)).existsSync()) {
      _refuse(
        jsonMode: jsonMode,
        entity: entity,
        kind: 'missing_file',
        message: 'no mock datasource found for $entity ($mockPath)',
        fix:
            'generate it first — `zfa mock create $entity --certify` '
            '(the gate cannot audit a file that does not exist)',
        code: ExitProtocol.failure,
        member: mockClass,
        file: mockPath,
      );
      return;
    }
    if (!File(p.join(root, interfacePath)).existsSync()) {
      _refuse(
        jsonMode: jsonMode,
        entity: entity,
        kind: 'missing_file',
        message:
            'no interface found for $entity ($interfacePath) — '
            'nothing to conform to',
        fix:
            'restore the entity datasource interface or regenerate — '
            '`zfa mock create $entity --certify`',
        code: ExitProtocol.failure,
        member: interfaceClass,
        file: interfacePath,
      );
      return;
    }

    // ── The shared conformance shape (AC: same machinery as MockCertify). ──
    // The on-disk fixtures ride into the certification as digest-bound
    // artifacts; the AST reads are pure (no writes anywhere).
    final fixtures = <GeneratedFile>[
      if (File(p.join(root, mockDataPath)).existsSync())
        GeneratedFile(path: mockDataPath, type: 'mock_data', action: 'created'),
    ];
    final certification = await MockCertificationService.certify(
      entity: entity,
      outputDir: plugin.outputDir,
      files: fixtures,
      projectRoot: root,
    );
    final report = await MockCertifier().gate(
      certification: certification,
      projectRoot: root,
    );

    // Structured findings, mapped from the SAME certification the gate
    // consumed: the gate's fix lines are ordered (missing → invented →
    // analyze), so the analyze tail is what remains after the structural
    // prefix.
    final structuralCount =
        (certification.missingMethods.isNotEmpty ? 1 : 0) +
        (certification.inventedMethods.isNotEmpty ? 1 : 0);
    final analyzeLines = report.fixLines.length > structuralCount
        ? report.fixLines.sublist(structuralCount)
        : const <String>[];
    final findings = <VerdictFinding>[
      for (final m in certification.missingMethods)
        VerdictFinding(
          kind: 'missing_method',
          member: m,
          file: certification.mockFile,
          fix:
              'implement the missing '
              '${certification.interfaceClass ?? 'the declared interface'} '
              'member(s): ${certification.missingMethods.join(', ')}',
        ),
      for (final m in certification.inventedMethods)
        VerdictFinding(
          kind: 'invented_method',
          member: m,
          file: certification.mockFile,
          fix:
              'correct the member(s) '
              '${certification.mockClass ?? 'the mock'} does not declare in '
              '${certification.interfaceClass ?? 'the declared interface'}: '
              '${certification.inventedMethods.join(', ')}',
        ),
      for (final line in analyzeLines)
        VerdictFinding(
          kind: 'analyze_error',
          file: certification.mockFile,
          fix: line.replaceFirst(RegExp(r'^--> fix:\s*'), ''),
        ),
    ];

    if (jsonMode) {
      VerdictEnvelope.emit(
        VerdictEnvelope(
          command: 'zfa mock verify $entity',
          verdict: report.passed ? VerdictKind.pass : VerdictKind.fail,
          exitClass: report.passed
              ? ExitProtocol.success
              : ExitProtocol.failure,
          subject: VerdictSubject(kind: 'mock', id: entity),
          findings: findings,
          drifts: report.fixLines,
          details: {
            'entity': entity,
            'mockFile': certification.mockFile,
            'interfaceFile': certification.interface,
            'readOnly': true,
            'certification': certification.toEnvelopeJson(),
          },
        ),
      );
    } else {
      // ignore: avoid_print
      print('Mock Verify — $entity');
      // ignore: avoid_print
      print(
        '  interface : ${certification.interface} '
        '(${certification.interfaceClass ?? '-'})',
      );
      // ignore: avoid_print
      print(
        '  mock      : ${certification.mockFile} '
        '(${certification.mockClass ?? '-'})',
      );
      // ignore: avoid_print
      print('  registry  : ${certification.registryId}');
      if (report.passed) {
        // ignore: avoid_print
        print(
          '✅ verified: the mock conforms to '
          '${certification.interfaceClass ?? 'its contract'} '
          '(conformance proven).',
        );
      } else {
        for (final finding in findings) {
          // ignore: avoid_print
          print('❌ [${finding.kind}] ${finding.member ?? finding.file}');
          // ignore: avoid_print
          print('   --> fix: ${finding.fix}');
        }
      }
    }
    exitCode = report.passed ? ExitProtocol.success : ExitProtocol.failure;
  }

  void _refuse({
    required bool jsonMode,
    required String entity,
    required String kind,
    required String message,
    required String fix,
    required int code,
    String? member,
    String? file,
  }) {
    if (jsonMode) {
      VerdictEnvelope.emit(
        VerdictEnvelope(
          command: 'zfa mock verify $entity',
          verdict: VerdictKind.fail,
          exitClass: code,
          subject: VerdictSubject(kind: 'mock', id: entity),
          findings: [
            VerdictFinding(kind: kind, member: member, file: file, fix: fix),
          ],
          details: {'entity': entity, 'readOnly': true},
        ),
      );
      stderr.writeln(ExitProtocol.fixLine(fix));
    } else {
      // ignore: avoid_print
      print('❌ [$kind] $message');
      // ignore: avoid_print
      print(ExitProtocol.fixLine(fix));
    }
    exitCode = code;
  }
}
