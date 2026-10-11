// Unit behaviors for the shared fence-aware entry-sections iterator
// (spec 1549): the layer between `splitCycleLogSections()` (issue #1467)
// and the three remaining line-scanner readers (issue #1549). A `## `
// line inside a fenced code block must never start an entry section.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/cycle_log_entry_sections.dart';

void main() {
  test('parses the Cycle header grammar', () {
    final entries = parseCycleLogEntrySections('''
# Cycle Log

## Cycle: B-001 (red)

- behavior: B-001
- kind: red
- exit: 1
''');
    expect(entries, hasLength(1));
    expect(entries.first.header, 'Cycle: B-001 (red)');
    expect(entries.first.behavior, 'B-001');
    expect(entries.first.kind, 'red');
    expect(entries.first.bodyLines, contains('- kind: red'));
  });

  test('skips the preamble and non-Cycle sections', () {
    final entries = parseCycleLogEntrySections('''
# Cycle Log

Some prose.

## Notes: not an entry

- kind: green

## Cycle: B-002 (green)

- behavior: B-002
''');
    expect(entries, hasLength(1));
    expect(entries.first.behavior, 'B-002');
    // The non-Cycle section's body lines are not attributed to anything.
    expect(entries.first.bodyLines.any((l) => l.contains('Notes')), isFalse);
  });

  test('keeps an in-fence Cycle line in the body', () {
    final captured =
        '00:00 +0: loading test\n'
        '## Cycle: PHANTOM (green)\n'
        '- kind: green\n';
    final entries = parseCycleLogEntrySections('''
# Cycle Log

## Cycle: B-001 (red)

- behavior: B-001
- kind: red
- output:
```
$captured```
''');
    expect(entries, hasLength(1), reason: 'no phantom section');
    expect(entries.first.behavior, 'B-001');
    expect(
      entries.first.bodyLines.join('\n'),
      contains('## Cycle: PHANTOM (green)'),
      reason: 'captured output is evidence — it stays in the body, verbatim',
    );
  });

  test('parses a byte-0 header with its legacy ## prefix', () {
    // The legacy `raw.split('\n## ')` contract keeps a byte-0 header's
    // `## ` prefix on the first chunk; the iterator normalizes it.
    final entries = parseCycleLogEntrySections('''
## Cycle: B-001 (red)

- behavior: B-001

## Cycle: B-002 (green)

- behavior: B-002
''');
    expect(entries, hasLength(2));
    expect(entries.first.header, 'Cycle: B-001 (red)');
    expect(entries.first.behavior, 'B-001');
    expect(entries.last.behavior, 'B-002');
  });

  test('honors the inline output-fence dialect', () {
    // The 068 dialect opens the captured-output fence ON the `- output:`
    // line; later `## ` lines belong to that fence, never to a section.
    final entries = parseCycleLogEntrySections('''
# Cycle Log

## Cycle: B-001 (red)

- behavior: B-001
- output: ```
banner line
## Cycle: PHANTOM (red)
tail line
```
- hash: a56e3f546553afeaa6dbb84b19d9ace568d58cc9b67786d867d849933ebedbf3
''');
    expect(entries, hasLength(1));
    expect(entries.first.bodyLines.join('\n'), contains('## Cycle: PHANTOM'));
    expect(
      entries.first.bodyLines.join('\n'),
      contains('- hash: a56e3f54'),
      reason: 'trailing entry fields survive the in-fence banner',
    );
  });

  test('tolerates a header with no behavior token', () {
    final entries = parseCycleLogEntrySections('''
# Cycle Log

## Cycle:

- kind: green
''');
    expect(entries, hasLength(1));
    expect(entries.first.behavior, isEmpty);
    expect(entries.first.kind, isNull);
  });

  test('an empty or headerless log yields no entries', () {
    expect(parseCycleLogEntrySections(''), isEmpty);
    expect(parseCycleLogEntrySections('# Cycle Log\n\nprose only\n'), isEmpty);
  });
}
