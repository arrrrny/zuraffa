/// `SpecMigrator` — inject or refresh the `**Template Version**` treaty
/// pin in a `spec.md` (issue #990).
///
/// Bug #919 made the marker the grammar contract: a spec missing it (or
/// pinning an unknown version) is contract drift and `zfa tdd plan`
/// exits 3 before parsing. Until #990 the only fix was re-authoring the
/// spec from the zuraffa template by hand. The migrator gives plan a
/// migration path that changes ONE thing — the marker itself — and
/// nothing else:
///
/// * missing pin  -> the latest known marker is inserted at the top of
///   the file (the frontmatter position the template authors it in).
/// * stale pin    -> an unknown version is refreshed in place, on the
///   exact line it was declared, preserving every other byte.
/// * current pin  -> no-op (idempotent; the spec is returned untouched).
///
/// A marker mentioned inside a fenced code block (a "How to write a
/// spec" example) is documentation, not the treaty pin — the same rule
/// `SpecParser.parseTemplateVersion` enforces via fence stripping — so
/// the migrator's walk skips fenced lines when locating the pin and
/// never rewrites the example.
library;

import 'spec_parser.dart';

/// What [SpecMigrator.migrate] decided to do with the spec.
enum SpecMigrationAction {
  /// The spec already pins a known version — nothing was changed.
  none,

  /// The spec carried no (non-fenced) marker; one was inserted at the
  /// top of the file.
  inserted,

  /// The spec pinned an unknown/stale version; the marker line was
  /// refreshed to the latest known version in place.
  refreshed,
}

/// The outcome of a migration attempt: the (possibly rewritten) spec
/// content plus what happened to it.
class SpecMigrationResult {
  const SpecMigrationResult({
    required this.content,
    required this.action,
    this.previousVersion,
  });

  /// The spec content to persist — identical to the input when
  /// [action] is [SpecMigrationAction.none].
  final String content;

  /// What the migration did.
  final SpecMigrationAction action;

  /// The version the spec pinned before the migration, or null when it
  /// carried none.
  final String? previousVersion;

  bool get migrated => action != SpecMigrationAction.none;

  @override
  String toString() =>
      'SpecMigrationResult($action, previousVersion: $previousVersion)';
}

class SpecMigrator {
  const SpecMigrator();

  /// The same marker grammar `SpecParser` uses for the treaty-pin scan
  /// (bug #919) — the migrator must agree with the parser on what a pin
  /// looks like or the two walks could disagree at the gate.
  static final RegExp _templateVersionMarker = RegExp(
    r'^\s*\*\*template\s+version\*\*:\s*`?([^`\n]+?)`?\s*$',
    caseSensitive: false,
  );

  /// A fenced code block boundary (``` … ```). Walk state toggles on
  /// any fence line so markers inside examples are never rewritten.
  static final RegExp _fenceLine = RegExp(r'^[ \t]*```');

  /// Migrate [specMd] to [version] (defaults to the latest known
  /// template version). Never throws on a non-conformant spec — a
  /// missing pin is the normal migration input, not an error.
  SpecMigrationResult migrate(String specMd, {String? version}) {
    final target = version ?? SpecParser.latestTemplateVersion;
    final lines = specMd.split('\n');
    var inFence = false;
    for (var i = 0; i < lines.length; i++) {
      if (_fenceLine.hasMatch(lines[i])) {
        inFence = !inFence;
        continue;
      }
      if (inFence) continue;
      final m = _templateVersionMarker.firstMatch(lines[i].trim());
      if (m == null) continue;
      final declared = m.group(1)!.trim();
      if (SpecParser.knownTemplateVersions.contains(declared)) {
        // Already pinned to a known version — idempotent no-op.
        return SpecMigrationResult(
          content: specMd,
          action: SpecMigrationAction.none,
          previousVersion: declared,
        );
      }
      // Stale/unknown pin: refresh the declared line in place, every
      // other byte preserved.
      lines[i] = '**Template Version**: `$target`';
      return SpecMigrationResult(
        content: lines.join('\n'),
        action: SpecMigrationAction.refreshed,
        previousVersion: declared,
      );
    }
    // No (non-fenced) pin anywhere: insert at the very top — the
    // frontmatter position the zuraffa template authors the marker in —
    // followed by a blank line so the heading structure is untouched.
    return SpecMigrationResult(
      content: '**Template Version**: `$target`\n\n$specMd',
      action: SpecMigrationAction.inserted,
    );
  }
}
