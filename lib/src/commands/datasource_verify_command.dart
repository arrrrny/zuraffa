import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli/exit_protocol.dart';
import '../plugins/datasource/datasource_verifier.dart';
import '../plugins/tdd/models/verdict_envelope.dart';

/// `zfa datasource verify <Entity>` (spec #1131, order 1).
///
/// The entity-conformance gate: verifies that the generated datasource
/// INTERFACE matches the ENTITY's field signatures — the entity class
/// exists and parses, the id-field type the interface wires into
/// UpdateParams/DeleteParams/ToggleParams is the type the entity actually
/// declares, and every standard CRUD method references the entity type it
/// serves. (The interface/implementation method-parity gate remains
/// `zfa datasource check` — this command is the other half of the A+
/// contract: the interface against the entity definition it was generated
/// FROM.)
///
/// Exit codes: 0 = conformant, 1 = drift or missing/malformed source
/// (always with a `--> fix:` line), 2 = usage (no entity argument).
///
/// `--json` emits exactly one canonical `verdict.v1` envelope (issue
/// #1105) as the LAST stdout line — `{schema, command, verdict,
/// exit_class, subject, findings, drifts, details, timestamp}` with
/// `subject: {kind: "datasource", entity: <Entity>}` and
/// `findings: [{kind, file, member, fix}]` — and no prose.
class DataSourceVerifyCommand extends Command<void> {
  /// Project root the entity/interface files are resolved against.
  /// Defaults to the current working directory, mirroring the check
  /// command and the receipt store; injectable so tests can point at a
  /// temp fixture.
  final String? projectRoot;

  /// Generator output root (`lib/src`); fixed in v5 but injectable for
  /// tests.
  final String outputDir;

  DataSourceVerifyCommand({this.projectRoot, this.outputDir = 'lib/src'}) {
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit a single canonical verdict.v1 envelope on stdout '
          '(CI-able, issue #1105).',
    );
    argParser.addOption(
      'id-field',
      help:
          'The entity id field the interface must conform to '
          '(defaults to `id`).',
      defaultsTo: 'id',
    );
  }

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Verify the datasource interface matches the entity field signatures '
      '(exit 1 with --> fix: on drift; spec #1131)';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const [];
    final jsonMode = argResults?['json'] == true;
    if (rest.isEmpty) {
      if (jsonMode) {
        VerdictEnvelope.emit(
          command: 'datasource verify',
          outcome: VerdictOutcome.error,
          exitClass: 'insufficient-input',
          subject: const {'kind': 'datasource'},
          details: const {'fix': 'zfa datasource verify <Entity>'},
        );
      } else {
        print('❌ Usage: zfa datasource verify <Entity>');
        print('   Example: zfa datasource verify Product');
      }
      exitCode = ExitProtocol.usage;
      return;
    }

    final entity = rest.first;
    final idField = argResults?['id-field'] as String? ?? 'id';
    final root = projectRoot ?? _safeCwd();

    // The gate itself never throws on a malformed entity — verify() parses
    // defensively and reports what it could not read (spec #1131 order 4).
    final report = await const DatasourceVerifier().verify(
      projectRoot: root,
      outputDir: outputDir,
      entity: entity,
      idField: idField,
    );

    if (jsonMode) {
      VerdictEnvelope.emit(
        command: 'datasource verify',
        outcome: report.ok ? VerdictOutcome.pass : VerdictOutcome.fail,
        exitClass: report.exitClass,
        subject: {'kind': 'datasource', 'entity': entity},
        findings: report.findings
            .map(
              (f) => <String, Object?>{
                'kind': f.kind,
                'file': f.file,
                'member': f.member,
                'fix': f.fix,
              },
            )
            .toList(growable: false),
        drifts: report.findings
            .map((f) => '${f.file}: ${f.detail}')
            .toList(growable: false),
        details: {
          if (report.entitySourcePath != null)
            'entitySource': report.entitySourcePath,
          if (report.interfacePath != null) 'interface': report.interfacePath,
          'idField': report.idField,
          if (report.entityFieldType != null)
            'idFieldType': report.entityFieldType,
          'entityFields': report.entityFields
              .map((f) => f.toJson())
              .toList(growable: false),
          'methodsChecked': report.methodsChecked
              .map((m) => m.name)
              .toList(growable: false),
        },
      );
      exitCode = report.ok ? 0 : 1;
      return;
    }

    if (report.ok) {
      print(
        '✅ datasource verify OK for `$entity`: the interface matches the '
        'entity field signatures '
        '(${report.methodsChecked.length} methods checked, id-field '
        '`${report.idField}`: ${report.entityFieldType ?? '(none)'}).',
      );
      exitCode = 0;
      return;
    }

    print(
      '❌ datasource verify failed for `$entity`: '
      '${report.findings.length} finding(s) between the entity definition '
      'and `${entity}DataSource`.',
    );
    for (final finding in report.findings) {
      print(
        '   [${finding.kind}] ${finding.member} — ${finding.detail} '
        '(${finding.file})',
      );
      print(finding.fixLine);
    }
    exitCode = 1;
  }

  static String _safeCwd() {
    try {
      return Directory.current.path;
    } catch (_) {
      return '.';
    }
  }
}
