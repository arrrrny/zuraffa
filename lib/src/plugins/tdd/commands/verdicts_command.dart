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
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
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
      'subcommand emits the versioned envelope as its FINAL stdout line '
      'when --json is passed.',
    );
    print(
      '  keys: schema, command, feature?, verdict, exit_class, fix?, '
      'drifts, details, timestamp',
    );
    print('  verdicts: pass | fail | stopped | error');
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
        'The versioned JSON verdict envelope every `zfa tdd` subcommand '
        'emits as the FINAL stdout line when --json is passed '
        '(issue #969).',
    'keys': {
      'schema': {'type': 'string', 'const': VerdictEnvelope.schema},
      'command': {
        'type': 'string',
        'description': 'the leaf verb that emitted the envelope',
      },
      'feature': {
        'type': 'string',
        'optional': true,
        'description': 'the feature the verb operated on, when known',
      },
      'verdict': {
        'type': 'string',
        'enum': [
          VerdictOutcome.pass.name,
          VerdictOutcome.fail.name,
          VerdictOutcome.stopped.name,
          VerdictOutcome.error.name,
        ],
        'description':
            'pass = the verb achieved its goal; fail = honest refusal or '
            'gate failure; stopped = an early honest stop (skip, usage); '
            'error = could not assess',
      },
      'exit_class': {
        'type': 'string',
        'description':
            'the verb\'s shipped exit-taxonomy label (ok on exit 0; '
            'command-specific classes otherwise). The envelope carries '
            'the label — it never changes a taxonomy.',
      },
      'fix': {
        'type': 'string',
        'optional': true,
        'description':
            'the machine-actionable remediation (the `--> fix:` content), '
            'when the path has one',
      },
      'drifts': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'drift/diff findings the verdict is about',
      },
      'details': {
        'type': 'object',
        'description':
            'command-specific key/values mirroring the human summary line',
      },
      'timestamp': {
        'type': 'string',
        'format': 'iso-8601-utc',
        'description': 'when the verdict was emitted',
      },
    },
    'required_keys': const [
      'schema',
      'command',
      'verdict',
      'exit_class',
      'drifts',
      'details',
      'timestamp',
    ],
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
