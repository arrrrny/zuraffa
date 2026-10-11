/// Fence-parity and edge-shape coverage for
/// `lib/src/plugins/tdd/services/cycle_log_sections.dart` (issue #1467
/// review).
///
/// A1–A5 pin the behavioural outcomes; these cases pin the fence-parity
/// edges they cannot see — the inline `- output: ``` ` opener, CRLF closers,
/// stray/odd fences, 4+-backtick / ≤3-space-indented / info-string fences,
/// empty input, `~~~` fences, a header at EOF, consecutive headers, and the
/// re-join invariant. Wherever the log's fences are balanced the legacy
/// `split('\n## ')` is the oracle, and the pinned sweep of the committed
/// `specs/068-simulation-di-binding/tdd/cycle-log.md` locks the real-file
/// regression (that log writes its opener inline, which the pre-fix
/// splitter could not see: 6 of its 12 entries were silently dropped).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/services/cycle_log_sections.dart';

const _hash =
    'a1c3e5a1c3e5a1c3e5a1c3e5a1c3e5a1c3e5a1c3e5a1c3e5a1c3e5a1c3e5a1c3e5';

String _entry(String behavior, String kind, {String? output, String? inline}) {
  final buffer = StringBuffer()
    ..write('## Cycle: $behavior ($kind)\n\n')
    ..write('- behavior: $behavior\n')
    ..write('- kind: $kind\n')
    ..write('- criterion: AC-4\n')
    ..write('- exit: 0\n');
  if (output != null) {
    buffer
      ..write('- output:\n')
      ..write('```\n')
      ..write(output)
      ..write('```\n');
  }
  if (inline != null) {
    buffer
      ..write('- output: ```\n')
      ..write(inline)
      ..write('```\n');
  }
  buffer.write('- hash: $_hash\n\n');
  return buffer.toString();
}

String _crlf(String raw) => raw.replaceAll('\n', '\r\n');

/// Asserts the legacy oracle: byte-identical sections plus the re-join
/// invariant (`sections.join('\n## ') == raw`).
void _expectLegacyOracle(String raw) {
  final sections = splitCycleLogSections(raw);
  expect(sections, raw.split('\n## '));
  expect(sections.join('\n## '), raw);
}

int _behaviorSections(String raw) => splitCycleLogSections(
  raw,
).where(RegExp(r'^- behavior: ', multiLine: true).hasMatch).length;

void main() {
  group('splitCycleLogSections — parity and edge shapes', () {
    test('empty input is one empty section', () {
      expect(splitCycleLogSections(''), ['']);
      _expectLegacyOracle('');
    });

    test('a header at EOF still starts a section', () {
      _expectLegacyOracle('# Log\n\n## Cycle: A (red)\n');
      expect(
        splitCycleLogSections('# Log\n\n## Cycle: A (red)\n'),
        hasLength(2),
      );
    });

    test('consecutive headers match the legacy split', () {
      _expectLegacyOracle('x\n## A\n## B\n');
      expect(splitCycleLogSections('x\n## A\n## B\n'), hasLength(3));
    });

    test('CRLF closers close their fence', () {
      final raw = _crlf(
        '# Log\n\n${_entry('A', 'red', output: 'captured\n')}'
        '${_entry('B', 'green', output: 'ok\n')}',
      );
      expect(splitCycleLogSections(raw), hasLength(3));
      _expectLegacyOracle(raw);
    });

    test('the inline `- output: ``` ` opener is recognised', () {
      final raw =
          '# Log\n\n${_entry('A', 'red', inline: 'captured\n')}'
          '${_entry('B', 'green', output: 'ok\n')}';
      final sections = splitCycleLogSections(raw);
      expect(sections, hasLength(3));
      expect(sections[1], contains('- hash: $_hash'));
      _expectLegacyOracle(raw);
    });

    test('an info-string fence suppresses in-fence `## ` lines', () {
      final raw =
          '# Log\n\n## Cycle: A (red)\n\n- behavior: A\n- kind: red\n'
          '- output:\n```dart\n// captured dump:\n## not a section\n```\n'
          '- hash: $_hash\n\n${_entry('B', 'green', output: 'ok\n')}';
      final sections = splitCycleLogSections(raw);
      expect(sections, hasLength(3));
      expect(sections[1], contains('## not a section'));
      expect(sections[2], contains('- behavior: B'));
    });

    test('a 4+ backtick fence holds a 3-backtick line as data', () {
      final raw =
          '# Log\n\n## Cycle: A (red)\n\n- behavior: A\n- kind: red\n'
          '- output:\n````\n```\n## not a section\n````\n- hash: $_hash\n\n'
          '${_entry('B', 'green', output: 'ok\n')}';
      final sections = splitCycleLogSections(raw);
      expect(sections, hasLength(3));
      expect(sections[1], contains('## not a section'));
    });

    test('a <=3-space indented fence is still a fence', () {
      final raw =
          '# Log\n\n## Cycle: A (red)\n\n- behavior: A\n- kind: red\n'
          '- output:\n  ```\n  ## not a section\n  ```\n- hash: $_hash\n\n'
          '${_entry('B', 'green', output: 'ok\n')}';
      final sections = splitCycleLogSections(raw);
      expect(sections, hasLength(3));
      expect(sections[1], contains('## not a section'));
    });

    test('tilde fences are out of contract (documented, legacy-equal)', () {
      _expectLegacyOracle('# Log\n\n## A\n\n~~~\n## B\n~~~\n');
    });

    test('an odd stray fence line never swallows the next entry', () {
      // Captured output with an odd number of fence-looking lines used to
      // flip the fence parity, after which `## Cycle: B` was read as data.
      final raw =
          '# Log\n\n## Cycle: A (red)\n\n- behavior: A\n- kind: red\n'
          '- output:\n```\nCaptured block:\n```\nrest of output\n```\n'
          '- hash: $_hash\n\n${_entry('B', 'green', output: 'ok\n')}';
      final sections = splitCycleLogSections(raw);
      expect(sections, hasLength(3));
      expect(_behaviorSections(raw), 2);
      expect(sections[2], contains('- behavior: B'));
      _expectLegacyOracle(raw);
    });

    test('re-join invariance holds for a mixed document', () {
      final raw =
          '# Log\n\n${_entry('A', 'red', output: '## in-fence\n')}'
          '${_entry('B', 'green', inline: 'ok\n')}'
          '${_entry('C', 'refactor', output: 'none\n')}';
      expect(splitCycleLogSections(raw).join('\n## '), raw);
      expect(_behaviorSections(raw), 3);
    });

    test('the committed 068 log keeps all 12 entries and 5 greens', () {
      final file = File(
        p.join(
          _packageRoot(),
          'specs',
          '068-simulation-di-binding',
          'tdd',
          'cycle-log.md',
        ),
      );
      expect(
        file.existsSync(),
        isTrue,
        reason: 'fixture missing: ${file.path}',
      );
      final raw = file.readAsStringSync();
      final sections = splitCycleLogSections(raw);
      expect(
        sections.where(RegExp(r'^- behavior: ', multiLine: true).hasMatch),
        hasLength(12),
      );
      expect(
        sections.where((s) => s.contains('- kind: green')),
        hasLength(5),
        reason: 'the inline-opener dialect dropped every green entry pre-fix',
      );
      expect(sections.join('\n## '), raw);
    });
  });
}

String _packageRoot() {
  var dir = Directory.current.absolute;
  for (var i = 0; i < 8; i++) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zuraffa')) {
      return dir.path;
    }
    dir = dir.parent;
  }
  throw StateError('could not locate the zuraffa package root');
}
