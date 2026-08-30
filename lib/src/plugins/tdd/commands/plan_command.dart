/// `zfa tdd plan <feature>` — read `spec.md`, emit `tdd/test-list.md`.
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../services/spec_parser.dart';
import '../tdd_plugin.dart';

class PlanCommand extends Command<void> {
  PlanCommand(this.plugin) {
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/<feature>/spec.md. When omitted, the '
          'current working directory is used. Tests pass the temp fixture '
          'root here instead of mutating Directory.current.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'plan';

  @override
  String get description =>
      'Read specs/<feature>/spec.md and emit '
      'specs/<feature>/tdd/test-list.md (one behavior per criterion).';

  @override
  String get invocation => 'zfa tdd plan <feature>';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      usageException('Feature name is required: zfa tdd plan <feature>');
    }
    final feature = rest.first;
    // Prefer an explicit --project root so the command never depends on the
    // process-global Directory.current. Falls back to CWD for real CLI use.
    final projectFlag = argResults?['project'] as String?;
    final repoRoot = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : Directory.current.path;
    final specPath = '$repoRoot/specs/$feature/spec.md';
    final specFile = File(specPath);
    if (!await specFile.exists()) {
      stderr.writeln('zfa tdd plan: spec not found at $specPath');
      throw StateError('zfa tdd plan: spec not found');
    }
    final specMd = await specFile.readAsString();

    final List<Behavior> behaviors;
    try {
      behaviors = const SpecParser().parse(feature, specMd);
    } on StateError catch (e) {
      stderr.writeln('zfa tdd plan: $e');
      throw StateError('zfa tdd plan: cannot derive behaviors');
    }

    final outDir = Directory('$repoRoot/specs/$feature/tdd');
    final outFile = File('${outDir.path}/test-list.md');
    final existing = <String, Behavior>{};
    if (await outFile.exists()) {
      final raw = await outFile.readAsString();
      for (final line in raw.split('\n')) {
        final m = RegExp(
          r'^\|\s*([A|U]\d+)\s*\|.*?\|\s*([A-Z0-9\-, ]+)\s*\|',
        ).firstMatch(line);
        if (m != null) {
          final id = m.group(1)!;
          final traces = m.group(2)!.trim();
          existing[traces] = Behavior(
            id: id,
            feature: feature,
            kind: id.startsWith('A')
                ? BehaviorKind.acceptance
                : BehaviorKind.unit,
            description: '',
            sourceCriterion: traces,
            target: '',
          );
        }
      }
    }

    final reconciled = <Behavior>[];
    for (final b in behaviors) {
      final prior = existing[b.sourceCriterion];
      if (prior != null && prior.kind == b.kind) {
        reconciled.add(
          Behavior(
            id: prior.id,
            feature: b.feature,
            kind: b.kind,
            description: b.description,
            sourceCriterion: b.sourceCriterion,
            target: b.target,
          ),
        );
      } else {
        reconciled.add(b);
      }
    }

    await outDir.create(recursive: true);
    await outFile.writeAsString(_render(feature, reconciled));

    final aCount = reconciled
        .where((b) => b.kind == BehaviorKind.acceptance)
        .length;
    final uCount = reconciled.where((b) => b.kind == BehaviorKind.unit).length;
    stdout.writeln(
      'zfa tdd plan: wrote $outFile with $aCount acceptance + $uCount unit '
      'behaviors (${reconciled.length} total).',
    );
  }

  String _render(String feature, List<Behavior> behaviors) {
    final acceptance = behaviors
        .where((b) => b.kind == BehaviorKind.acceptance)
        .toList();
    final unit = behaviors.where((b) => b.kind == BehaviorKind.unit).toList();

    final buf = StringBuffer()
      ..writeln('# Test List: $feature')
      ..writeln()
      ..writeln('## Outer loop: acceptance behaviors')
      ..writeln()
      ..writeln('One per acceptance criterion in `spec.md`.')
      ..writeln()
      ..writeln('| id | behavior | traces | state |')
      ..writeln('| -- | -------- | ------ | ----- |');
    for (final b in acceptance) {
      buf.writeln(
        '| ${b.id} | ${b.description} | ${b.sourceCriterion} | PENDING |',
      );
    }
    buf
      ..writeln()
      ..writeln('## Inner loop: unit behaviors')
      ..writeln()
      ..writeln('One per functional requirement in `spec.md`.')
      ..writeln()
      ..writeln('| id | behavior | traces | state |')
      ..writeln('| -- | -------- | ------ | ----- |');
    for (final b in unit) {
      buf.writeln(
        '| ${b.id} | ${b.description} | ${b.sourceCriterion} | PENDING |',
      );
    }
    buf.writeln();
    return buf.toString();
  }
}
