/// Fence-aware cycle-log ENTRY sections (issue #1549) — the layer between
/// `splitCycleLogSections()` (issue #1467 / PR #1543) and the remaining
/// line-scanner readers of `tdd/cycle-log.md`.
///
/// PR #1543 made every `raw.split('\n## ')` reader fence-aware. Three
/// readers (`provenance_scanner.dart`, `ci_referee/failure_artifacts.dart`,
/// `ci_referee/feature_provenance_reader.dart`) scan the log LINE-BY-LINE
/// with their own state machines instead — and an in-fence `## Cycle:` line
/// (a markdown banner a test printed into its captured output) flips their
/// state as if a new entry had started: phantom `(refactor)` attributions,
/// truncated failure excerpts, green evidence credited to a behavior that
/// does not exist.
///
/// [parseCycleLogEntrySections] routes all three through the shared
/// splitter: a `## ` line inside a fenced code block can never start an
/// entry section. What each reader does with a section's BODY lines — its
/// own field grammar (`- kind:`, `changed:`, `- test:`, fence toggles) — is
/// unchanged; only the section source is fence-aware now.
///
/// Sections whose header is not a `Cycle:` header (the file's `# Cycle Log`
/// preamble, prose sections) are skipped: the readers only ever reacted to
/// `## Cycle:` lines, and machine-written logs carry no other `## ` headers
/// (`CycleLogEntry.toMarkdown()` writes `Cycle:` headers exclusively).
///
/// The `## <timestamp>: <behavior> (kind)` hand-written dialect never
/// matched `## Cycle:` and stays unmatched — this layer changes WHERE
/// sections come from, not what a header means.
library;

import 'cycle_log_sections.dart';

/// One `## Cycle:` entry section of a cycle-log: the parsed header plus the
/// section's body lines, verbatim.
class CycleLogEntrySection {
  const CycleLogEntrySection({required this.header, required this.bodyLines});

  /// Hoisted: compiling per `kind` access recompiled the pattern for every
  /// entry, per reader, per scan.
  static final RegExp _kindTail = RegExp(r'\(([^)]*)\)$');

  /// The header line WITHOUT the `## ` prefix, trimmed — e.g.
  /// `Cycle: B-001 (red)`. A byte-0 header keeps its prefix under the
  /// legacy `raw.split('\n## ')` contract (the split never separates byte
  /// 0); the iterator normalizes it away.
  final String header;

  /// The section's lines after the header line, verbatim — the entry's
  /// fields AND its fenced captured output (an in-fence `## Cycle:` line is
  /// body, never a section).
  final List<String> bodyLines;

  /// The behavior token after `Cycle:` — the header's first whitespace
  /// token (`CycleLogEntry.toMarkdown()` writes `## Cycle: <behavior>
  /// (<kind>)`). Empty when the header carries none.
  String get behavior {
    if (!header.startsWith('Cycle:')) return '';
    final rest = header.substring('Cycle:'.length).trim();
    return rest.split(' ').first;
  }

  /// The header's parenthesized kind tail — `red`, `green`, `refactor`,
  /// `error`, `refresh` — or null when the header carries no
  /// `(kind)` suffix.
  String? get kind {
    final match = _kindTail.firstMatch(header);
    return match?.group(1);
  }
}

/// Parse [raw] cycle-log markdown into its `## Cycle:` entry sections,
/// fence-aware: sections come from `splitCycleLogSections()`, so only a
/// column-0 `## ` line OUTSIDE a fenced code block can start one.
///
/// The first chunk (everything before the first header) is the file's
/// preamble and is skipped, as is every chunk whose header is not a
/// `Cycle:` header. Headerless or empty input yields an empty list —
/// never a throw.
List<CycleLogEntrySection> parseCycleLogEntrySections(String raw) {
  final sections = splitCycleLogSections(raw);
  final entries = <CycleLogEntrySection>[];
  for (var i = 0; i < sections.length; i++) {
    final lines = sections[i].split('\n');
    var header = lines.first.trim();
    // Byte-compat: the legacy `raw.split('\n## ')` keeps a byte-0 header's
    // `## ` prefix on the first chunk (only chunk 0 can carry it — every
    // later chunk had its prefix consumed as the split separator).
    if (i == 0 && header.startsWith('## ')) {
      header = header.substring('## '.length).trim();
    }
    if (!header.startsWith('Cycle:')) continue;
    entries.add(
      CycleLogEntrySection(header: header, bodyLines: lines.sublist(1)),
    );
  }
  return entries;
}
