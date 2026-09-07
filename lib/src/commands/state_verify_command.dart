import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli/exit_protocol.dart';
import '../core/verdict_envelope.dart';
import '../plugins/state/state_plugin.dart';
import '../plugins/state/state_verifier.dart';
import '../utils/string_utils.dart';

/// SPEC 1126 (issue #1126, order 1) — `zfa state verify <Entity>`.
///
/// The state drift gate: compares the current state class on disk
/// against the contract the create run recorded in the stable receipt
/// (`.zfa/receipts/state-<entity>.json`, spec 1126 order 2) and reports
/// which contract methods match, which are STALE (the entity changed
/// and the state was not regenerated; the state bytes were hand-edited
/// after create) and which are MISSING from the parsed class. Exit 0 on
/// clean; exit 1 with one `--> fix:` line per finding on drift; exit 2
/// on usage. `--json` emits ONE canonical `VerdictEnvelope` envelope
/// (the schema identifier literal lives only in
/// `lib/src/core/verdict_envelope.dart`; issue #1105)
/// as the last stdout line (SPEC 1105; mirrors `zfa service verify`).
///
/// Registered manually on [StateCommand] (the `manualSubcommandNames`
/// hook, issue #761): the generic runner has no `verify` verb.
class StateVerifyCommand extends Command<void> {
  final StatePlugin plugin;

  /// Project root receipts and the output tree resolve from. Defaults to
  /// the CWD (the CLI contract); injectable so tests can point at a
  /// temp fixture.
  final String? projectRoot;

  StateVerifyCommand(this.plugin, {this.projectRoot}) {
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit one canonical ${VerdictEnvelope.canonicalSchema} envelope '
          'on stdout (CI-able, issue #1105)',
    );
    argParser.addMultiOption(
      'methods',
      abbr: 'm',
      help:
          'Override the audited methodset (default: the create receipt '
          'contract)',
    );
    argParser.addOption(
      'domain',
      help:
          'The domain folder the state file lives under (default: the '
          'receipt, then the entity snake name)',
    );
  }

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Verify a state class against its create receipt (match / stale / '
      'missing per contract method) — exit 1 with --> fix: lines on '
      'drift (spec 1126)';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty || rest.first.trim().isEmpty) {
      print('❌ Usage: zfa state verify <Entity> [--json] [--methods ...]');
      print(
        ExitProtocol.fixLine(
          're-run with the entity the state was created from — '
          '`zfa state verify <Entity>` (e.g. zfa state verify Product)',
        ),
      );
      exitCode = ExitProtocol.usage;
      return;
    }

    final jsonMode = argResults?['json'] == true;
    final root = projectRoot ?? _safeCwd();
    final entity = StringUtils.convertToPascalCase(rest.first.trim());
    if (entity.isEmpty) {
      print('❌ Error: `${rest.first}` does not name an entity');
      print(
        ExitProtocol.fixLine(
          're-run with the entity the state was created from — '
          '`zfa state verify <Entity>`',
        ),
      );
      exitCode = ExitProtocol.usage;
      return;
    }

    final rawMethodsOverride = (argResults?['methods'] as List<String>?)
        ?.expand((entry) => entry.split(','))
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList(growable: false);
    // package:args hands back an EMPTY list (not null) for an unpassed
    // multi-option — an empty override must fall through to the receipt
    // contract, never silence it.
    final methodsOverride =
        (rawMethodsOverride == null || rawMethodsOverride.isEmpty)
        ? null
        : rawMethodsOverride;

    final report = await const StateVerifier().verify(
      projectRoot: root,
      outputDir: plugin.outputDir,
      entity: entity,
      methods: methodsOverride,
      domain: argResults?['domain'] as String?,
    );

    if (jsonMode) {
      print(
        VerdictEnvelope(
          command: 'zfa state verify $entity',
          verdict: report.ok ? VerdictKind.pass : VerdictKind.fail,
          exitClass: report.ok ? ExitProtocol.success : ExitProtocol.failure,
          subject: VerdictSubject(kind: 'state', id: entity),
          findings: report.findings
              .map(
                (f) => VerdictFinding(
                  kind: f.kind,
                  member: f.method,
                  file: f.file,
                  fix: f.fix,
                ),
              )
              .toList(growable: false),
          details: {
            'stateClass': report.stateClass,
            'stateFile': report.stateFile,
            'receipt': report.receiptFile,
            'methodsMatched': report.methodsMatched,
            'methodsStale': report.methodsStale,
            'methodsMissing': report.methodsMissing,
          },
        ).toJsonLine(),
      );
    } else {
      _printText(report, root);
    }
    exitCode = report.ok ? ExitProtocol.success : ExitProtocol.failure;
  }

  void _printText(StateVerifyReport report, String root) {
    print('State Verify (receipt contract — spec 1126)');
    print('============================================');
    print('Entity: ${report.entity} — class ${report.stateClass}');
    print('  file    : ${report.stateFile ?? '(no state file found)'}');
    print(
      '  methods : ${report.methodsMatched.length} match, '
      '${report.methodsStale.length} stale, '
      '${report.methodsMissing.length} missing',
    );

    void listing(String label, List<String> methods) {
      if (methods.isEmpty) return;
      final members = methods
          .map((m) => '$m → is${StringUtils.toContinuous(m)}')
          .join(', ');
      print('  $label: $members');
    }

    listing('  match ', report.methodsMatched);
    listing('  stale ', report.methodsStale);
    listing('  missing', report.methodsMissing);

    if (report.ok) {
      print(
        '✓ state verified: every contract method matches the class and '
        'all digests are clean.',
      );
      return;
    }

    print('');
    print('Findings (${report.findings.length}):');
    for (final finding in report.findings) {
      final member = finding.method.isEmpty ? '' : '${finding.method}: ';
      print('  [${finding.kind}] $member${finding.detail}');
      print('    file: ${finding.file}');
      print('    ${finding.fix}');
    }
    print('');
    print('state verify: ${report.findings.length} finding(s) — FAIL');
  }

  static String _safeCwd() {
    try {
      return Directory.current.path;
    } catch (_) {
      return '.';
    }
  }
}
