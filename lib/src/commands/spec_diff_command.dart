/// `zfa spec diff` — spec↔code drift radar (issue #813, VISION 2030
/// Pillar C: Trust engine).
///
/// v0 slice: one-way, spec → expected artifact inventory → compare.
/// Reports a drift score, the offending pairs, and (with `--plan`) a
/// regeneration step list in planner-ready form. JSON output via `--json`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../core/project/project_root.dart';
import '../plugins/tdd/services/spec_parser.dart';

class SpecDiffCommand extends Command<void> {
  SpecDiffCommand() {
    argParser.addOption(
      'feature',
      help:
          'Feature directory under specs/ to diff (e.g. 001-foo). '
          'When omitted, every specs/<n>-<slug> directory is diffed.',
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help:
          'Project root containing specs/. Defaults to the detected '
          'project root.',
    );
    argParser.addFlag(
      'json',
      help: 'Emit the report as a single JSON object on stdout.',
      negatable: false,
    );
    argParser.addFlag(
      'plan',
      help: 'Emit only the regeneration step list (planner-ready).',
      negatable: false,
    );
  }

  @override
  String get name => 'diff';

  @override
  String get description =>
      'Detect drift between a spec and the generated code: behaviors '
      'specified but absent from code, code present that no behavior '
      'justifies, and entity fields that drifted from the spec typed '
      'field list. Reports a drift score, offending pairs, and (with '
      '--plan) a regeneration step list.';

  @override
  String get invocation => 'zfa spec diff [options]';

  @override
  Future<void> run() async {
    final projectRoot =
        (argResults!['project'] as String?) ?? ProjectRoot.safeCurrentPath();
    final feature = argResults!['feature'] as String?;
    final positional = argResults!.rest;
    final asJson = argResults!['json'] as bool;
    final planOnly = argResults!['plan'] as bool;

    final specsDir = Directory(p.join(projectRoot, 'specs'));
    final features = <String>[];
    if (feature != null && feature.isNotEmpty) {
      features.add(feature);
    } else if (positional.isNotEmpty) {
      features.add(positional.first);
    } else if (specsDir.existsSync()) {
      for (final e in specsDir.listSync()) {
        if (e is Directory) {
          features.add(p.basename(e.path));
        }
      }
      features.sort();
    }

    final entries = <Map<String, dynamic>>[];
    var totalDrift = 0;
    for (final f in features) {
      final featureDir = p.join(projectRoot, 'specs', f);
      final specFile = File(p.join(featureDir, 'spec.md'));
      final specExists = specFile.existsSync();
      final specMd = specExists ? specFile.readAsStringSync() : '';
      final specLines = specMd.split('\n');

      // Parse behaviors (best-effort; a spec with no scenarios yields none).
      final behaviorIds = <String>[];
      try {
        final behaviors = const SpecParser().parse(f, specMd);
        for (final b in behaviors) {
          behaviorIds.add(b.id);
        }
      } catch (_) {
        // No acceptance scenarios (or malformed) -> zero behaviors.
      }

      // Parse entities.
      List<SpecEntity> entities = const [];
      try {
        entities = const SpecParser().parseKeyEntities(specMd);
      } catch (_) {
        entities = const [];
      }

      // Registry (artifacts.json) if present.
      final registryFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
      final registryIds = <String>[];
      final registryRecords = <Map<String, dynamic>>[];
      if (registryFile.existsSync()) {
        try {
          final decoded = jsonDecode(registryFile.readAsStringSync());
          final records = (decoded is Map<String, dynamic>)
              ? (decoded['records'] as List? ?? const [])
              : (decoded is List ? decoded : const []);
          for (final r in records) {
            if (r is Map<String, dynamic>) {
              registryRecords.add(r);
              final id = r['behavior_id']?.toString();
              if (id != null && id.isNotEmpty) registryIds.add(id);
            }
          }
        } catch (_) {
          // Malformed registry -> treat as empty.
        }
      }

      final pairs = <Map<String, dynamic>>[];
      final plan = <String>[];

      // Behaviors specified but absent from the registry.
      final expectedSet = behaviorIds.toSet();
      final registrySet = registryIds.toSet();
      for (final b in behaviorIds) {
        if (!registrySet.contains(b)) {
          pairs.add({
            'kind': 'specified_absent',
            'behavior': b,
            'detail': 'behavior $b specified but absent from code/registry',
          });
          plan.add('regenerate behavior $b: zfa tdd gen $f --behavior $b');
        }
      }
      // Code present that no behavior justifies.
      for (final id in registryIds) {
        if (!expectedSet.contains(id)) {
          pairs.add({
            'kind': 'unjustified_code',
            'behavior': id,
            'detail': 'code present for $id that no behavior justifies',
          });
          plan.add(
            'remove unjustified artifact for $id (or add a spec behavior)',
          );
        }
      }
      // Registry records whose files are missing on disk.
      for (final r in registryRecords) {
        final testPath = r['test_path']?.toString();
        final subjectPath = r['subject_path']?.toString();
        if (testPath != null && testPath.isNotEmpty) {
          final f = File(p.join(projectRoot, testPath));
          if (!f.existsSync()) {
            pairs.add({
              'kind': 'missing_file',
              'path': testPath,
              'detail': 'registered test file missing: $testPath',
            });
            plan.add('regenerate missing test: $testPath');
          }
        }
        if (subjectPath != null && subjectPath.isNotEmpty) {
          final f = File(p.join(projectRoot, subjectPath));
          if (!f.existsSync()) {
            pairs.add({
              'kind': 'missing_file',
              'path': subjectPath,
              'detail': 'registered subject file missing: $subjectPath',
            });
            plan.add('regenerate missing subject: $subjectPath');
          }
        }
      }

      // Entity field drift.
      for (final ent in entities) {
        final snake = _toSnake(ent.name);
        final candidates = <String>[
          p.join(
            projectRoot,
            'lib',
            'src',
            'domain',
            'entities',
            snake,
            '$snake.dart',
          ),
          p.join(
            projectRoot,
            'lib',
            'src',
            'domain',
            'entities',
            '${ent.name}.dart',
          ),
          p.join(projectRoot, 'lib', 'domain', 'entities', '$snake.dart'),
        ];
        String? entityPath;
        for (final c in candidates) {
          if (File(c).existsSync()) {
            entityPath = c;
            break;
          }
        }
        // Also scan if not found.
        if (entityPath == null) {
          final dir = Directory(
            p.join(projectRoot, 'lib', 'src', 'domain', 'entities'),
          );
          if (dir.existsSync()) {
            for (final e in dir.listSync(recursive: true)) {
              if (e is File && p.basename(e.path) == '$snake.dart') {
                entityPath = e.path;
                break;
              }
            }
          }
        }

        final declared = <String>[for (final fld in ent.fields) fld.name];
        final declaredSet = declared.toSet();

        // spec line for this entity: find Key Entities row/bullet.
        final specLine = _entitySpecLine(specMd, ent.name);

        if (entityPath == null) {
          // Entity specified but no code file found.
          if (declared.isNotEmpty) {
            pairs.add({
              'kind': 'entity_absent',
              'entity': ent.name,
              'specLine': specLine,
              'detail':
                  'entity ${ent.name} specified but absent from code (spec line $specLine)',
            });
            plan.add(
              'create entity ${ent.name}: zfa entity create -n ${ent.name} ${declared.map((f) {
                final fld = ent.fields.firstWhere((x) => x.name == f);
                return '--field $f:${fld.type}';
              }).join(' ')}',
            );
          }
          continue;
        }

        final source = File(entityPath).readAsStringSync();
        final onDisk = SpecParser.entityFieldNamesFromDartSource(source);
        final onDiskSet = onDisk.toSet();
        final missingOnDisk = declaredSet.difference(onDiskSet).toList()
          ..sort();
        final undeclared = onDiskSet.difference(declaredSet).toList()..sort();

        if (missingOnDisk.isNotEmpty || undeclared.isNotEmpty) {
          final detail =
              'entity ${ent.name} field drift: '
              'missing on disk [${missingOnDisk.join(', ')}], '
              'undeclared [${undeclared.join(', ')}] (spec line $specLine)';
          pairs.add({
            'kind': 'entity_field_drift',
            'entity': ent.name,
            'specLine': specLine,
            'missingOnDisk': missingOnDisk,
            'undeclared': undeclared,
            'detail': detail,
          });
          if (missingOnDisk.isNotEmpty) {
            plan.add(
              'add fields to ${ent.name}: ${missingOnDisk.join(', ')} (spec line $specLine)',
            );
          }
          if (undeclared.isNotEmpty) {
            plan.add(
              'remove undeclared fields from ${ent.name}: ${undeclared.join(', ')}',
            );
          }
        }
      }

      final drift = pairs.length;
      totalDrift += drift;
      entries.add({
        'feature': f,
        'spec': specExists ? 'specs/$f/spec.md' : null,
        'specLines': specLines.length,
        'behaviors': behaviorIds,
        'entities': entities.map((e) => e.name).toList(),
        'drift': drift,
        'pairs': pairs,
        'plan': plan,
      });
    }

    if (planOnly) {
      for (final e in entries) {
        final steps = (e['plan'] as List).cast<String>();
        if (steps.isEmpty) {
          stdout.writeln('plan: ${e['feature']} — no steps (drift 0)');
        } else {
          for (final s in steps) {
            stdout.writeln(s);
          }
        }
      }
      if (entries.isEmpty) {
        stdout.writeln('plan: no features');
      }
      exitCode = totalDrift > 0 ? 1 : 0;
      return;
    }

    if (asJson) {
      stdout.writeln(jsonEncode({'drift': totalDrift, 'features': entries}));
      exitCode = totalDrift > 0 ? 1 : 0;
      return;
    }

    stdout.writeln('spec diff — drift radar (v0)');
    stdout.writeln('project: $projectRoot');
    stdout.writeln('features: ${entries.length}');
    stdout.writeln('drift: $totalDrift');
    for (final e in entries) {
      stdout.writeln(
        '  ${e['feature']}: drift=${e['drift']} '
        'specLines=${e['specLines']}',
      );
      for (final pair in (e['pairs'] as List)) {
        stdout.writeln('    - ${pair['detail'] ?? pair}');
      }
      // Name spec line for entity drift.
      for (final pair in (e['pairs'] as List)) {
        if (pair is Map && pair['specLine'] != null) {
          stdout.writeln('      spec line: ${pair['specLine']}');
        }
      }
    }
    stdout.writeln('drift score: ${entries.isEmpty ? 0 : totalDrift}');
    exitCode = totalDrift > 0 ? 1 : 0;
  }

  String _toSnake(String name) {
    final buf = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final c = name[i];
      if (c.toUpperCase() == c && c.toLowerCase() != c && i > 0) {
        buf.write('_');
      }
      buf.write(c.toLowerCase());
    }
    return buf.toString();
  }

  int _entitySpecLine(String specMd, String entityName) {
    final lines = specMd.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains(entityName) &&
          (line.contains('Fields') ||
              line.contains('|') ||
              line.contains('**'))) {
        // Ensure it's in Key Entities-ish: contains entity name and a field-ish colon or table.
        if (line.contains(':') || line.contains('|')) {
          return i + 1;
        }
      }
    }
    // Fallback: first occurrence.
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(entityName)) return i + 1;
    }
    return 1;
  }
}
