/// `zfa tdd verdicts` — the machine contract's self-describing verb
/// (issue #969, T002).
///
/// Prints the verdict.v1 envelope schema, diff-stable, so agents and CI
/// can pin the exact contract without scraping prose. The output is
/// derived from a frozen map literal — no timestamps, no environment
/// probes, no locale-dependent ordering — which is what makes it
/// diff-stable (asserted by test).
library;

import 'dart:convert';

import 'package:args/command_runner.dart';

import '../../../core/verdict/verdict_envelope.dart' show VerdictResult;
import '../models/verdict_envelope.dart';
import '../services/verdict_emitter.dart';
import '../tdd_plugin.dart';

class VerdictsCommand extends Command<void> {
  VerdictsCommand(this.plugin) {
    argParser.addFlag(
      'schema',
      help:
          'Print the versioned verdict envelope schema (diff-stable, like '
          '`zfa ui schema`).',
      negatable: false,
    );
    argParser.addFlag(
      'json',
      help:
          'Emit a canonical zuraffa.verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #969).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Accepted for verb consistency; the schema is environment-'
          'independent and never reads the project.',
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  @override
  String get name => 'verdicts';

  @override
  String get description =>
      'Print the versioned verdict envelope schema every `zfa tdd` '
      'subcommand emits under --json (issue #969).';

  @override
  String get invocation => 'zfa tdd verdicts [--schema] [--json]';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    final schema = argResults?['schema'] as bool? ?? false;
    const encoder = JsonEncoder.withIndent('  ');
    if (schema) {
      // Diff-stable by construction: a frozen map literal rendered with
      // a fixed indent. No clock, no filesystem, no locale ordering.
      print(encoder.convert(_schemaDocument()));
      _verdict
        ..exitClass = 'ok'
        ..outcome = VerdictOutcome.pass;
      return;
    }
    // Default: the human summary of the machine contract.
    print(
      'verdicts: schema=${VerdictEnvelope.schema} — every `zfa tdd` '
      'subcommand emits the canonical envelope as its FINAL stdout line '
      'when --json is passed (EPIC 1150).',
    );
    print(
      '  keys: schema, command, result, exit_class, message, data, '
      'fix?, drifts, ts',
    );
    print('  results: ok | error | skipped | refused');
    print(
      '  use `zfa tdd verdicts --schema` for the full machine '
      'schema (diff-stable).',
    );
    _verdict
      ..exitClass = 'ok'
      ..outcome = VerdictOutcome.pass;
  }

  /// The schema document. KEEP THE ORDER FROZEN — the diff-stability
  /// test pins the rendered output byte-for-byte.
  Map<String, Object?> _schemaDocument() => {
    'schema': VerdictEnvelope.schema,
    'description':
        'The canonical JSON verdict envelope every `zfa tdd` subcommand '
        'emits as the FINAL stdout line when --json is passed '
        '(issue #969; EPIC 1150 unified the whole zfa fleet onto this '
        'one shape).',
    'keys': {
      'schema': {'type': 'string', 'const': VerdictEnvelope.schema},
      'command': {
        'type': 'string',
        'description':
            'the FULL invocation that emitted the envelope '
            '(e.g. "zfa tdd run", "zfa tdd corpus status")',
      },
      'result': {
        'type': 'string',
        'enum': [
          VerdictResult.ok.name,
          VerdictResult.error.name,
          VerdictResult.skipped.name,
          VerdictResult.refused.name,
        ],
        'description':
            'ok = the verb achieved its goal; error = the verb ran and '
            'gave an honest negative verdict (fail/gate/RED); '
            'skipped = an early honest stop (skip, nothing to do); '
            'refused = never ran as invoked (usage, gating)',
      },
      'exit_class': {
        'type': 'integer',
        'description':
            'the INT exit code the process exits with (SPEC 917 '
            'protocol: 0 success, 1 failure, 2 usage, 3 drift, '
            '4 conflict) — the envelope and `exit "\$?"` never '
            'disagree',
      },
      'message': {
        'type': 'string',
        'description': 'human-readable one-line summary of the verdict',
      },
      'data': {
        'type': 'object',
        'description':
            'command-specific payload. Legacy key surface preserved '
            'inside: verdict (pass|fail|stopped|error), exit_label '
            '(the verb\'s shipped taxonomy label), feature?, '
            'subject?, findings?, plus the verb\'s own details',
      },
      'fix': {
        'type': 'string',
        'optional': true,
        'description':
            'the machine-actionable remediation (the `--> fix:` '
            'content), when the path has one',
      },
      'drifts': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'drift/diff findings the verdict is about',
      },
      'ts': {
        'type': 'string',
        'format': 'iso-8601-utc',
        'description': 'when the verdict was emitted',
      },
    },
    'required_keys': const [
      'schema',
      'command',
      'result',
      'exit_class',
      'message',
      'data',
      'drifts',
      'ts',
    ],
    'legacy_key_migration': const {
      'verdict':
          'result (pass→ok, fail→error, stopped→skipped, '
          'error→error); raw name kept at data.verdict',
      'exit_class(string)':
          'exit_class(int) — the SPEC 917 exit code; '
          'the string label kept at data.exit_label',
      'details': 'merged into data verbatim',
      'feature': 'data.feature',
      'timestamp': 'ts',
    },
    'verbs': const [
      'compose',
      'corpus',
      'diff-check',
      'doctor',
      'fake',
      'func',
      'gen',
      'init',
      'make',
      'migrate-paths',
      'plan',
      'realize',
      'replay',
      'reset',
      'refactor',
      'referee',
      'run',
      'verdicts',
      'verify',
      'verify-red',
      'view',
      'wire',
    ],
  };
}
