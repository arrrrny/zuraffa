/// `zfa zap` — the ZAP (Zuraffa Agent Protocol) CLI surface (spec 071,
/// issue #809).
///
/// - `zfa zap conform` — the conformance self-test (exit 0/1,
///   `--format text|json` per #778, `--drift-dir` gates the published
///   contract files against the code).
/// - `zfa zap serve` — the ZAP host: NDJSON over stdin/stdout.
/// - `zfa zap schema` — prints a draft-07 schema; `--export <dir>` writes
///   the schemas + golden examples (the publishable contract).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../zap/zap_conformance.dart';
import '../zap/zap_golden.dart';
import '../zap/zap_host.dart';
import '../zap/zap_protocol.dart';
import '../zap/zap_schema.dart';

class ZapCommand extends Command<void> {
  @override
  final String name = 'zap';

  @override
  final String description =
      'Zuraffa Agent Protocol (ZAP): open agent interop — conform, serve, '
      'schema (issue #809).';

  ZapCommand() {
    addSubcommand(ZapConformCommand());
    addSubcommand(ZapServeCommand());
    addSubcommand(ZapSchemaCommand());
  }

  @override
  Future<void> run() async {
    print('Usage: zfa zap <conform|serve|schema> [options]');
    print('');
    print(description);
    print('');
    print('Subcommands:');
    print(
      '  conform    Run the ZAP conformance self-test (goldens, '
      'rejections, reference client)',
    );
    print(
      '  serve      Run the ZAP host: NDJSON missions/evidence/ '
      'checkpoints/receipts on stdio',
    );
    print(
      '  schema     Print a ZAP JSON Schema; --export writes the full '
      'published contract',
    );
    exitCode = 64;
  }
}

class ZapConformCommand extends Command<void> {
  @override
  final String name = 'conform';

  @override
  final String description =
      'Run the ZAP conformance suite: schema self-integrity, golden '
      'examples, the malformed-message rejection table, and the reference '
      'client session.';

  ZapConformCommand() {
    argParser.addOption(
      'format',
      allowed: ['text', 'json'],
      defaultsTo: 'text',
      help:
          'Output format. json emits a single verdict object (CI-able, '
          'per #778).',
    );
    argParser.addOption(
      'drift-dir',
      help:
          'Directory holding the published contract (schemas/ + '
          'golden/); adds the drift gate comparing the files to the code.',
    );
  }

  @override
  Future<void> run() async {
    final args = argResults!;
    final jsonMode = (args['format'] as String? ?? 'text') == 'json';
    final driftDir = args['drift-dir'] as String?;

    final report = await ZapConformance.run(driftDir: driftDir);

    if (jsonMode) {
      // Single parseable verdict object — no prose (per #778).
      print(jsonEncode(report.toJson()));
    } else {
      print('ZAP Conformance Suite');
      print('=====================');
      for (final check in report.checks) {
        print('  ${check.ok ? '✓' : '✗'} ${check.name} — ${check.detail}');
      }
      print('');
      print(
        'zap: conform checks=${report.checks.length} '
        'passed=${report.passed} failed=${report.failed} — '
        '${report.ok ? 'OK' : 'FAIL'}',
      );
    }
    exitCode = report.ok ? 0 : 1;
  }
}

class ZapServeCommand extends Command<void> {
  @override
  final String name = 'serve';

  @override
  final String description =
      'Run the ZAP host over stdio: read NDJSON missions/checkpoints on '
      'stdin, write evidence/receipts to stdout (NDJSON only; logs go to '
      'stderr). Exits 0 at stdin EOF.';

  ZapServeCommand() {
    argParser.addOption(
      'cwd',
      help:
          'Working directory for mission step subprocesses '
          '(default: current directory).',
    );
    argParser.addOption(
      'checkpoint-dir',
      valueHelp: 'dir',
      help:
          'Directory for checkpoint snapshots (default: '
          '.zfa/zap/checkpoints under the working directory).',
    );
    argParser.addOption(
      'timeout',
      valueHelp: 'seconds',
      help: 'Default per-step timeout in seconds (1..600, default 60).',
    );
  }

  @override
  Future<void> run() async {
    final args = argResults!;
    final cwd = args['cwd'] as String? ?? Directory.current.path;
    final checkpointDir =
        args['checkpoint-dir'] as String? ?? '$cwd/.zfa/zap/checkpoints';
    final timeoutSeconds = int.tryParse(args['timeout'] as String? ?? '60');

    final host = ZapHost(
      workingDirectory: cwd,
      checkpointDir: checkpointDir,
      defaultStepTimeout: Duration(
        seconds: timeoutSeconds == null || timeoutSeconds < 1
            ? 60
            : timeoutSeconds > 600
            ? 600
            : timeoutSeconds,
      ),
    );

    stderr
      ..writeln('zfa zap serve: ZAP $zapProtocolVersion on stdio (NDJSON)')
      ..writeln('  cwd: $cwd')
      ..writeln('  checkpoints: $checkpointDir');

    // Replies MUST flush per line: the client reads line-by-line.
    Future<void> emit(String reply) async {
      stdout.write(reply);
      await stdout.flush();
    }

    final lines = stdin
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());

    // Sequential processing: session state is order-sensitive.
    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        await host.handleLine(line, emit: emit);
      } catch (e) {
        // The host never dies on message problems; a genuinely unexpected
        // fault becomes an internal error envelope and serving continues.
        final fallback = <String, Object?>{
          'zap': zapProtocolVersion,
          'type': 'error',
          'id': 'x-internal',
          'ts': DateTime.now().toUtc().toIso8601String(),
          'code': 'internal',
          'message': 'unexpected host fault: $e',
        };
        await emit(ZapProtocol.encodeLine(fallback));
        stderr.writeln('internal error while handling a line: $e');
      }
    }
    stderr.writeln('zfa zap serve: stdin EOF, exiting 0');
    exitCode = 0;
  }
}

class ZapSchemaCommand extends Command<void> {
  @override
  final String name = 'schema';

  @override
  final String description =
      'Print a ZAP JSON Schema (draft-07), or export the full published '
      'contract (5 schemas + 4 golden examples) with --export.';

  ZapSchemaCommand() {
    argParser.addOption(
      'type',
      defaultsTo: 'mission',
      help: 'Which message type to print (${ZapSchema.types.join('|')}).',
    );
    argParser.addOption(
      'export',
      valueHelp: 'dir',
      help:
          'Export the published contract into <dir>/schemas/ and '
          '<dir>/golden/.',
    );
  }

  @override
  Future<void> run() async {
    final type = argResults!['type'] as String;
    final exportDir = argResults!['export'] as String?;

    if (!ZapSchema.types.contains(type)) {
      print(
        '❌ unknown ZAP message type "$type"; must be one of '
        '${ZapSchema.types.join('|')}',
      );
      print(usage);
      exitCode = 64;
      return;
    }

    if (exportDir == null) {
      print(
        const JsonEncoder.withIndent('  ').convert(ZapSchema.forType(type)),
      );
      return;
    }

    final schemasDir = Directory('$exportDir/schemas');
    final goldensDir = Directory('$exportDir/golden');
    await schemasDir.create(recursive: true);
    await goldensDir.create(recursive: true);

    for (final entry in ZapSchema.all.entries) {
      final file = File('${schemasDir.path}/${entry.key}.schema.json');
      await file.writeAsString(zapCanonicalJson(entry.value));
    }
    for (final goldenType in const [
      'mission',
      'evidence',
      'checkpoint',
      'receipt',
    ]) {
      final file = File('${goldensDir.path}/$goldenType.golden.json');
      await file.writeAsString(
        zapCanonicalJson(ZapGoldens.example(goldenType)),
      );
    }

    print(
      'exported: ${ZapSchema.types.length} schemas + 4 goldens -> '
      '$exportDir',
    );
    exitCode = 0;
  }
}
