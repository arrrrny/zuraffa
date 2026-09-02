/// The differential corpus loader (bug #805 — generator differential
/// testing, vision slice v0).
///
/// The corpus is a directory shipped in the generator repo: each
/// entry is a directory carrying an `entry.json` (name, incident,
/// description, steps, artifact roots) beside a `project/` driven-app
/// scaffold that the generator under test is run against. Tiers are
/// plain subdirectories (`corpus/regression/...`); a directory that
/// carries an `entry.json` is an entry, anything else is recursed into
/// one level. Discovery is sorted for deterministic gate runs.
///
/// The four failure classes are distinct and never swallowed: a
/// missing corpus dir, a corpus with zero entries, corrupt entry JSON,
/// and an invalid entry (no steps, no project scaffold, or no name).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One step's spawn specification from `entry.json`.
class DifferentialStepSpec {
  const DifferentialStepSpec({required this.argv, String? label})
    : _label = label;

  /// The full argv after the generator entrypoint, before the
  /// runner-injected `--project`. `dart ...` steps run in the scratch
  /// project directly; `tdd ...` steps run through the worktree's
  /// `bin/zfa.dart`.
  final List<String> argv;

  final String? _label;

  /// The human-readable step name. The condensed form: `tdd gen U1`
  /// argv renders as `gen U1`, a `dart test test/tdd` step as
  /// `test test/tdd`; anything else is the argv, joined.
  String get label {
    final explicit = _label;
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (argv.length >= 3 && argv[0] == 'tdd') {
      return '${argv[1]} ${argv[2]}';
    }
    if (argv.length >= 3 && argv[0] == 'dart' && argv[1] == 'test') {
      return 'test ${argv.skip(2).join(" ")}';
    }
    return argv.join(' ');
  }

  /// True when the step is a `dart test` run (the pass/fail-count
  /// dimension of the vector).
  bool get isTestStep =>
      argv.length >= 2 && argv[0] == 'dart' && argv[1] == 'test';
}

/// One corpus entry: the incident it guards plus everything needed to
/// drive it against a materialized generator ref.
class DifferentialEntry {
  const DifferentialEntry({
    required this.name,
    required this.incident,
    required this.description,
    required this.steps,
    required this.artifactRoots,
    required this.projectDir,
  });

  final String name;

  /// The GitHub issue number whose regression this entry guards
  /// (e.g. 744 for the u2-flow hang); null when not incident-bound.
  final int? incident;

  final String description;

  final List<DifferentialStepSpec> steps;

  /// Scratch-project directories walked for the artifact inventory.
  final List<String> artifactRoots;

  /// Absolute path of the `project/` scaffold to copy per run.
  final String projectDir;
}

/// The loader's failure classes.
enum DifferentialCorpusFailure { missing, empty, corrupt, invalid }

/// Thrown by [DifferentialCorpus.load]; [kind] is the machine class,
/// [message] names the path / reason for the human report.
class DifferentialCorpusException implements Exception {
  DifferentialCorpusException(this.kind, this.message);

  final DifferentialCorpusFailure kind;
  final String message;

  @override
  String toString() => 'differential corpus ${kind.name}: $message';
}

class DifferentialCorpus {
  DifferentialCorpus._();

  /// Loads every entry under [corpusDir] in sorted order. Throws a
  /// [DifferentialCorpusException] for the missing/empty/corrupt/
  /// invalid classes; a directory without entry.json is ignored, not
  /// an error.
  static Future<List<DifferentialEntry>> load(String corpusDir) async {
    final dir = Directory(corpusDir);
    if (!dir.existsSync()) {
      throw DifferentialCorpusException(
        DifferentialCorpusFailure.missing,
        'no corpus directory at $corpusDir',
      );
    }

    final entryFiles = <String>[];
    await _collectEntryFiles(dir, entryFiles, depth: 0);
    if (entryFiles.isEmpty) {
      throw DifferentialCorpusException(
        DifferentialCorpusFailure.empty,
        'no entries found under $corpusDir (each entry needs an '
        'entry.json)',
      );
    }
    entryFiles.sort();

    // Deterministic gate order: by entry name, with the file path as
    // the tiebreaker when two tiers carry the same name.
    final parsed =
        [
          for (final file in entryFiles)
            (file: file, entry: _parseEntry(File(file))),
        ]..sort((a, b) {
          final byName = a.entry.name.compareTo(b.entry.name);
          return byName != 0 ? byName : a.file.compareTo(b.file);
        });
    return [for (final pair in parsed) pair.entry];
  }

  static Future<void> _collectEntryFiles(
    Directory dir,
    List<String> out, {
    required int depth,
  }) async {
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final entryFile = File(p.join(entity.path, 'entry.json'));
      if (entryFile.existsSync()) {
        out.add(entryFile.path);
      } else if (depth < 1) {
        await _collectEntryFiles(entity, out, depth: depth + 1);
      }
    }
  }

  static DifferentialEntry _parseEntry(File entryFile) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(entryFile.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw DifferentialCorpusException(
        DifferentialCorpusFailure.corrupt,
        '${entryFile.path} is not valid JSON: ${e.message}',
      );
    } on FileSystemException catch (e) {
      throw DifferentialCorpusException(
        DifferentialCorpusFailure.corrupt,
        '${entryFile.path} could not be read: ${e.message}',
      );
    }

    final name = (json['name'] as String?)?.trim() ?? '';
    final stepsRaw = json['steps'];
    final projectDir = p.join(entryFile.parent.path, 'project');
    if (name.isEmpty) {
      throw DifferentialCorpusException(
        DifferentialCorpusFailure.invalid,
        '${entryFile.path}: "name" is required',
      );
    }
    if (stepsRaw is! List || stepsRaw.isEmpty) {
      throw DifferentialCorpusException(
        DifferentialCorpusFailure.invalid,
        '${entryFile.path}: "steps" must be a non-empty list',
      );
    }
    if (!Directory(projectDir).existsSync()) {
      throw DifferentialCorpusException(
        DifferentialCorpusFailure.invalid,
        '${entryFile.path}: the project scaffold is missing at $projectDir',
      );
    }

    final steps = <DifferentialStepSpec>[];
    for (final raw in stepsRaw) {
      if (raw is! Map<String, dynamic>) {
        throw DifferentialCorpusException(
          DifferentialCorpusFailure.corrupt,
          '${entryFile.path}: each step must be an object',
        );
      }
      final argv = (raw['argv'] as List?)?.cast<String>();
      if (argv == null || argv.isEmpty) {
        throw DifferentialCorpusException(
          DifferentialCorpusFailure.corrupt,
          '${entryFile.path}: each step needs a non-empty "argv"',
        );
      }
      steps.add(
        DifferentialStepSpec(
          argv: argv,
          label: (raw['label'] as String?)?.trim().isEmpty == true
              ? null
              : raw['label'] as String?,
        ),
      );
    }

    final roots =
        (json['artifactRoots'] as List?)?.cast<String>() ??
        const ['test/tdd', 'lib/tdd'];

    return DifferentialEntry(
      name: name,
      incident: json['incident'] is int ? json['incident'] as int : null,
      description: (json['description'] as String?) ?? '',
      steps: steps,
      artifactRoots: roots,
      projectDir: projectDir,
    );
  }
}
