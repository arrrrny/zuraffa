import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../core/policy/policy_gate.dart';
import '../core/policy/sign_off_ledger.dart';
import '../cli/exit_protocol.dart';

class PolicyCommand extends Command<void> {
  PolicyCommand() {
    addSubcommand(PolicyGatesCommand());
    addSubcommand(PolicyLedgerCommand());
  }

  @override
  final String name = 'policy';

  @override
  final String description =
      'Human checkpoints as policy: approval gates + sign-off ledger '
      '(issue #810).';

  @override
  Future<void> run() async {
    print('Usage: zfa policy <subcommand> [--format text|json]');
    print('');
    print(description);
    print('');
    print('Subcommands:');
    print('  gates    List the registered approval gates');
    print('  ledger   Inspect/verify the sign-off ledger');
    exitCode = ExitProtocol.usage;
  }
}

class PolicyGatesCommand extends Command<void> {
  PolicyGatesCommand() {
    argParser.addOption(
      'format',
      allowed: ['text', 'json'],
      defaultsTo: 'text',
      help: 'Output format (json is the machine contract, per #778).',
    );
  }

  @override
  final String name = 'gates';

  @override
  final String description = 'List the registered approval gates.';

  @override
  Future<void> run() async {
    final format = argResults!['format'] as String? ?? 'text';
    final list = PolicyGateRegistry.toJsonList();
    if (format == 'json') {
      stdout.writeln(
        jsonEncode(<String, dynamic>{'gates': list, 'count': list.length}),
      );
    } else {
      stdout.writeln('Policy gates (${list.length}):');
      for (final g in list) {
        stdout.writeln('  ${g['id']}  [${g['risk']}]  ${g['description']}');
      }
    }
    exitCode = ExitProtocol.success;
  }
}

class PolicyLedgerCommand extends Command<void> {
  PolicyLedgerCommand() {
    addSubcommand(PolicyLedgerVerifyCommand());
    addSubcommand(PolicyLedgerListCommand());
  }

  @override
  final String name = 'ledger';

  @override
  final String description = 'Inspect and verify the sign-off ledger.';

  @override
  Future<void> run() async {
    print('Usage: zfa policy ledger <verify|list> [--format text|json]');
    exitCode = ExitProtocol.usage;
  }
}

class PolicyLedgerVerifyCommand extends Command<void> {
  PolicyLedgerVerifyCommand() {
    argParser.addOption(
      'format',
      allowed: ['text', 'json'],
      defaultsTo: 'text',
    );
  }

  @override
  final String name = 'verify';

  @override
  final String description = 'Verify the sign-off ledger hash chain.';

  @override
  Future<void> run() async {
    final format = argResults!['format'] as String? ?? 'text';
    final ledger = SignOffLedger(projectRoot: Directory.current.path);
    final ok = await ledger.verify();
    if (format == 'json') {
      stdout.writeln(jsonEncode(<String, dynamic>{'ok': ok}));
    } else {
      stdout.writeln(
        ok
            ? 'sign-off ledger: OK (hash chain intact)'
            : 'sign-off ledger: FAIL (hash chain broken)',
      );
    }
    exitCode = ok ? ExitProtocol.success : ExitProtocol.failure;
  }
}

class PolicyLedgerListCommand extends Command<void> {
  PolicyLedgerListCommand() {
    argParser.addOption(
      'format',
      allowed: ['text', 'json'],
      defaultsTo: 'text',
    );
  }

  @override
  final String name = 'list';

  @override
  final String description = 'List sign-off ledger entries.';

  @override
  Future<void> run() async {
    final format = argResults!['format'] as String? ?? 'text';
    final ledger = SignOffLedger(projectRoot: Directory.current.path);
    final entries = await ledger.readAll();
    if (format == 'json') {
      stdout.writeln(
        jsonEncode(<String, dynamic>{
          'entries': entries.map((e) => e.toJson()).toList(),
          'count': entries.length,
        }),
      );
    } else {
      stdout.writeln('Sign-off ledger (${entries.length} entries):');
      for (final e in entries) {
        stdout.writeln(
          '  ${e.timestamp.toUtc().toIso8601String()}  ${e.gate}  '
          '${e.decision}  by ${e.identity}  (mission ${e.missionId})',
        );
      }
    }
    exitCode = ExitProtocol.success;
  }
}
