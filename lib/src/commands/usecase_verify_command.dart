import 'dart:io';

import 'package:args/command_runner.dart';
import '../cli/exit_protocol.dart';
import '../core/verdict_envelope.dart';
import '../plugins/usecase/conformance/usecase_gate.dart';
import '../plugins/usecase/usecase_plugin.dart';
import '../utils/string_utils.dart';

/// SPEC 1119 — `zfa usecase verify <Entity>`.
///
/// The per-method conformance gate: re-runs the contract the generator
/// prescribes against the generated `*_usecase.dart` files on disk
/// (grammar and gate share one derivation — spec #1127 principle) and
/// audits the entity drift (issue #1034 pattern: the create receipt
/// binds the entity source hash; divergence exits 1).
///
/// Exit 0 when every method's signature matches the contract and the
/// entity is not drifted; exit 1 with `--> fix:` lines on drift (the
/// same shape `zfa route verify` / `zfa service verify` use); exit 2 on
/// usage errors. `--json` emits ONE canonical verdict envelope (issue
/// #1105) as the LAST stdout line. Knobs resolve receipt-first with
/// flag overrides — the resolution `zfa service verify` uses.
class UseCaseVerifyCommand extends Command<void> {
  final UseCasePlugin plugin;

  /// Project root the receipt and the output tree resolve from.
  /// Defaults to the CWD (the CLI contract); injectable so tests can
  /// point at a temp fixture.
  final String? projectRoot;

  UseCaseVerifyCommand(this.plugin, {this.projectRoot}) {
    argParser.addMultiOption(
      'methods',
      abbr: 'm',
      splitCommas: true,
      help:
          'Override the audited method set (default: the create receipt, '
          'then conventional file discovery)',
    );
    argParser.addOption(
      'domain',
      help:
          'Override the domain folder (default: the receipt, then the '
          'entity snake case)',
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
      'Verify the generated usecases conform to the contract '
      '(signatures, variants, entity drift) — exit 1 with --> fix: lines '
      'on drift (spec 1119)';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty || rest.first.trim().isEmpty) {
      print(
        '❌ Usage: zfa usecase verify <Entity> [--json] [--methods m1,m2] '
        '[--domain d]',
      );
      print(
        ExitProtocol.fixLine(
          're-run with the entity the usecases were created from — '
          '`zfa usecase verify <Entity>` (e.g. zfa usecase verify Product)',
        ),
      );
      exitCode = ExitProtocol.usage;
      return;
    }

    final jsonMode = argResults?['json'] == true;
    final root = projectRoot ?? Directory.current.path;
    final entity = StringUtils.convertToPascalCase(rest.first.trim());
    if (entity.isEmpty) {
      print('❌ Error: `${rest.first}` does not name an entity');
      print(
        ExitProtocol.fixLine(
          're-run with the entity the usecases were created from — '
          '`zfa usecase verify <Entity>`',
        ),
      );
      exitCode = ExitProtocol.usage;
      return;
    }

    final methodsOverride = ((argResults?['methods'] as List?) ?? const [])
        .map((m) => m.toString().trim())
        .where((m) => m.isNotEmpty)
        .toList(growable: false);
    final domain = argResults?['domain'] as String?;

    final gate = UsecaseGate();
    final report = await gate.run(
      projectRoot: root,
      entity: entity,
      methods: methodsOverride,
      domain: domain,
    );

    if (jsonMode) {
      print(
        VerdictEnvelope(
          command: 'zfa usecase verify $entity',
          verdict: report.ok ? VerdictKind.pass : VerdictKind.fail,
          exitClass: report.ok ? ExitProtocol.success : ExitProtocol.failure,
          subject: VerdictSubject(kind: 'usecase', id: entity),
          findings: [
            // Per-method conformance findings, each carrying the audited
            // file + member the kind is about.
            for (final audit in report.audits)
              for (final finding in audit.findings)
                VerdictFinding(
                  kind: finding.kind,
                  member: finding.member,
                  file: audit.file,
                  fix: finding.fix,
                  extra: {'message': finding.message},
                ),
            // The drift gate speaks the same machine-stable kinds.
            if (report.drift?.drifted ?? false)
              VerdictFinding(
                kind: 'entity_drift',
                member: report.drift!.receiptSpecPath,
                fix:
                    're-generate the usecases from the current entity '
                    'source — `zfa usecase create $entity --force` (or '
                    'restore the entity source the receipt binds)',
                extra: {'message': report.drift!.detail},
              ),
          ],
          drifts: (report.drift?.drifted ?? false)
              ? [report.drift!.detail]
              : const <String>[],
          details: {
            'entity': entity,
            'methods': report.audits.map((a) => a.toJson()).toList(),
            'receiptBound': report.receiptBound,
            'entityDrift': report.drift?.toJson(),
            'domain': report.domain,
          },
        ).toJsonLine(),
      );
    } else {
      print('Usecase Verify — $entity');
      print('  methods   : ${report.methods.join(', ')}');
      print(
        '  receipt   : ${report.receiptBound ? 'bound' : 'not found '
                  '(gated by conformance alone)'}',
      );
      final drift = report.drift;
      if (drift != null) {
        print('  drift     : ${drift.detail}');
      }
      if (report.ok) {
        print(
          '✅ verified: every usecase signature matches the contract '
          '(conformance proven).',
        );
      } else {
        for (final audit in report.audits) {
          for (final finding in audit.findings) {
            print('❌ [${finding.kind}] ${finding.message}');
            print('   ${finding.fix}');
          }
        }
        if (drift != null && drift.drifted) {
          print('❌ [entity_drift] ${drift.detail}');
          print(
            ExitProtocol.fixLine(
              're-generate the usecases from the current entity source — '
              '`zfa usecase create $entity --force` (or restore the entity '
              'source the receipt binds)',
            ),
          );
        }
      }
    }
    exitCode = report.ok ? ExitProtocol.success : ExitProtocol.failure;
  }
}
