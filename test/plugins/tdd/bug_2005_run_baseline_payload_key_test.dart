// The run-baseline payload KEY contract (issue #2005).
//
// `RunBaselineCache.write` emits the JSON key `exitCode` and
// `RunBaselineCache.read` REQUIRES that key — the payload is a wire format
// between the run driver (the writer) and `make` (the reader), not a
// projection of a Dart identifier.
//
// Commit 898bc8b5 renamed the Dart identifier `exitCode` ->
// `CliRunner.lastDispatchedExitCode` and carried the JSON KEY along with it
// in seven test fixtures: the writer and the reader stopped agreeing, every
// cached baseline became unreadable, and the caller silently fell back to
// the absolute-green preflight (issue #922's safe fallback). The failure was
// SAFE, so nothing went red in CI — the affected suites are `slow`/`e2e` and
// the fast lane excludes them.
//
// This suite pins the contract so the next blind rename fails loudly:
//
//   1. the reader accepts a payload keyed `exitCode` and rejects one keyed
//      anything else (the key name IS the contract);
//   2. NO source file writes a run-baseline-shaped payload without the
//      `exitCode` key — the sweep that would have caught the seven fixtures;
//   3. the MIRROR of #2005: no payload writes the other four contract keys
//      without `failedTests`, so renaming THAT key cannot hide either;
//   4. every committed baseline ARTIFACT carries the same five keys.
//
// The sweep reads the whole repository (not only `lib/`, `bin/` and `test/`)
// and it reads the maps through a string- and comment-literal-aware scan, so
// a payload shaped like
//
//     {'command': 'dart test', 'meta': {'source': 'x'}, 'failedTests': []}
//
// — a nested map BEFORE the key, or a `}` inside a string value — is read
// exactly like the flat shape the seven fixtures used. A payload whose
// `exitCode` merely appears somewhere INSIDE the map (a nested map, say) is
// NOT accepted: the reader reads the key at the TOP level, so the guard
// checks the top level too.
//
// Two limits remain, and both are limits of what a payload can LOOK like,
// not of where the sweep looks:
//
//   1. the sweep reads LITERAL keys only: a key spelled through a constant
//      (`{kExitCode: 1}`) is not a key to it, so a payload that hides
//      `failedTests` behind a constant is invisible, and one that hides
//      `exitCode` behind a constant is reported as missing it — the same
//      blind spot, narrowed but not closed;
//   2. a payload that drops `failedTests` AND `exitCode` (both at once) no
//      longer resembles a baseline payload at all, so nothing here claims it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/run_baseline_cache.dart';
import 'package:zuraffa/src/plugins/tdd/services/suite_guard.dart';

import '../../helpers/project_root.dart';

/// The keys a baseline payload carries at its TOP level, in the order the
/// readers read them.
const _payloadKeys = [
  'command',
  'exitCode',
  'failedTests',
  'capturedAt',
  'parseable',
];

void main() {
  group('the run-baseline payload key is exitCode', () {
    late Directory sandbox;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('zfa_2005_baseline_');
    });

    tearDown(() async {
      if (sandbox.existsSync()) await sandbox.delete(recursive: true);
    });

    Future<SuiteSnapshot?> readPayload(Map<String, Object?> payload) async {
      final file = File(p.join(sandbox.path, 'run-baseline.json'));
      await file.writeAsString(jsonEncode(payload));
      return const RunBaselineCache().read(file.path);
    }

    test(
      'a payload keyed exitCode is READABLE (the writer/reader agree)',
      () async {
        final snapshot = await readPayload({
          'command': 'dart test',
          'exitCode': 1,
          'failedTests': ['test/other_test.dart: other behavior red'],
          'capturedAt': '2026-09-01T00:00:00.000Z',
          'parseable': true,
        });

        expect(snapshot, isNotNull);
        expect(snapshot!.exitCode, 1);
        expect(snapshot.failedTests, [
          'test/other_test.dart: other behavior red',
        ]);
      },
    );

    test('a payload keyed anything else is UNREADABLE (the key is the '
        'contract, not the identifier)', () async {
      final snapshot = await readPayload({
        'command': 'dart test',
        'notExitCode': 1,
        'capturedAt': '2026-09-01T00:00:00.000Z',
        'parseable': true,
      });

      expect(snapshot, isNull);
    });
  });

  group('no source writes a run-baseline payload without the exitCode key', () {
    test(
      'every run-baseline-shaped payload in the repo carries exitCode',
      () async {
        final root = await findProjectRoot();
        final missingExitCode = <String>[];
        final missingFailedTests = <String>[];

        for (final file in _dartSourcesUnder(root)) {
          final text = file.readAsStringSync();
          if (!_mentionsAPayloadKey(text)) continue;
          final relative = p.relative(file.path, from: root);

          for (final map in _scanMapLiterals(text)) {
            if (map.keys.containsKey('failedTests') &&
                !map.keys.containsKey('exitCode')) {
              missingExitCode.add(
                '$relative:${_lineOf(text, map.offsetOf('failedTests')!)}',
              );
            }
            // The mirror of #2005: a payload that renames `failedTests`
            // hides behind the untouched `exitCode` — the same blind spot
            // from the other side.
            if (!map.keys.containsKey('failedTests') &&
                _payloadKeys
                    .where((key) => key != 'failedTests')
                    .every(map.keys.containsKey)) {
              missingFailedTests.add(
                '$relative:${_lineOf(text, map.offsetOf('exitCode')!)}',
              );
            }
          }
        }

        expect(
          missingExitCode,
          isEmpty,
          reason:
              'These sources write a run-baseline/corpus-baseline payload '
              'without the `exitCode` key the reader requires, so every such '
              'baseline is unreadable and the caller falls back to the '
              'absolute-green preflight (issue #2005). Use `exitCode`.\n'
              '${missingExitCode.join('\n')}',
        );
        expect(
          missingFailedTests,
          isEmpty,
          reason:
              'These sources write a run-baseline/corpus-baseline payload '
              'that carries every other contract key but not `failedTests`, '
              'so the reader rejects it and the caller falls back to the '
              'absolute-green preflight (issue #2005). Use `failedTests`.\n'
              '${missingFailedTests.join('\n')}',
        );
      },
    );
  });

  group('the committed baseline artifacts carry the contract keys', () {
    test('every committed run-baseline.json carries the five keys', () async {
      final root = await findProjectRoot();
      final offenders = <String>[];

      for (final file in _baselineArtifactsUnder(root)) {
        final relative = p.relative(file.path, from: root);
        final Object? decoded;
        try {
          decoded = jsonDecode(file.readAsStringSync());
        } catch (error) {
          offenders.add('$relative: unreadable JSON ($error)');
          continue;
        }
        if (decoded is! Map<String, dynamic>) {
          offenders.add('$relative: not a JSON object');
          continue;
        }
        for (final key in _payloadKeys) {
          if (!decoded.containsKey(key)) {
            offenders.add('$relative: missing `$key`');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These committed baseline artifacts do not carry the five keys '
            'the reader requires, so every one of them is unreadable and '
            'the caller falls back to the absolute-green preflight '
            '(issue #2005).\n${offenders.join('\n')}',
      );
    });
  });
}

/// Whether [text] mentions a quoted payload key at all — the cheap
/// pre-filter that keeps the sweep off the ~3000 files that cannot hold a
/// baseline payload.
bool _mentionsAPayloadKey(String text) =>
    text.contains("'failedTests'") ||
    text.contains('"failedTests"') ||
    text.contains("'exitCode'") ||
    text.contains('"exitCode"');

/// Every Dart source file in the repository, minus the tooling directories
/// (`.git`, `.dart_tool`, IDE folders) and the generated/dependency trees at
/// the root (`build`, `node_modules`, `coverage`).
///
/// The sweep is repo-wide on purpose: a baseline writer added under
/// `packages/`, `apps/`, `examples/` or `benchmark/` must be caught exactly
/// like one added under `lib/` — the previous sweep walked `lib`, `bin`,
/// `tool` and `test` only, and `tool` does not even exist in this repo.
Iterable<File> _dartSourcesUnder(String rootPath) sync* {
  const ignoredAtAnyDepth = {'.git', '.dart_tool', '.idea', '.vscode'};
  const ignoredAtRoot = {'build', 'node_modules', 'coverage'};

  final root = Directory(rootPath);
  final pending = <Directory>[root];
  while (pending.isNotEmpty) {
    final directory = pending.removeLast();
    final List<FileSystemEntity> entries;
    try {
      entries = directory.listSync(followLinks: false);
    } catch (_) {
      continue;
    }
    for (final entry in entries) {
      final name = p.basename(entry.path);
      if (entry is Directory) {
        if (ignoredAtAnyDepth.contains(name)) continue;
        if (p.equals(directory.path, root.path) &&
            ignoredAtRoot.contains(name)) {
          continue;
        }
        pending.add(entry);
      } else if (entry is File && name.endsWith('.dart')) {
        yield entry;
      }
    }
  }
}

/// Every committed baseline artifact in the repository.
Iterable<File> _baselineArtifactsUnder(String rootPath) sync* {
  const ignoredAtAnyDepth = {'.git', '.dart_tool', '.idea', '.vscode'};

  final root = Directory(rootPath);
  final pending = <Directory>[root];
  while (pending.isNotEmpty) {
    final directory = pending.removeLast();
    final List<FileSystemEntity> entries;
    try {
      entries = directory.listSync(followLinks: false);
    } catch (_) {
      continue;
    }
    for (final entry in entries) {
      final name = p.basename(entry.path);
      if (entry is Directory) {
        if (ignoredAtAnyDepth.contains(name)) continue;
        pending.add(entry);
      } else if (entry is File && name == 'run-baseline.json') {
        yield entry;
      }
    }
  }
}

/// A map literal found in a source file, with its TOP-level keys.
class _MapLiteral {
  _MapLiteral(this.braceOffset);

  /// The offset of the map's opening brace.
  final int braceOffset;

  /// The map's top-level (depth-1) keys, mapped to the offset of the key
  /// literal that introduces them.
  final Map<String, int> keys = <String, int>{};

  /// The offset of [key]'s literal, or null when the map has no such key.
  int? offsetOf(String key) => keys[key];
}

/// The map literals in [text], each with its top-level keys.
///
/// The scan is string- and comment-literal aware: a brace, a colon or a
/// semicolon that lives inside a string (or inside a comment) never
/// influences the analysis, and the `${...}` region of an interpolated
/// string is read as the code it is.
List<_MapLiteral> _scanMapLiterals(String text) {
  final masked = _maskLiteralsAndComments(text);
  final maps = <int, _MapLiteral>{};
  final order = <_MapLiteral>[];
  final open = <_Brace>[];

  for (var i = 0; i < masked.text.length; i++) {
    final literal = masked.literals[i];
    if (literal != null) {
      final key = _mapKeyOf(masked.text, literal);
      if (key != null && open.isNotEmpty && open.last.isMapLiteral) {
        final map = maps.putIfAbsent(open.last.offset, () {
          final created = _MapLiteral(open.last.offset);
          order.add(created);
          return created;
        });
        map.keys.putIfAbsent(key, () => literal.tokenStart);
      }
    }
    final c = masked.text[i];
    if (c == '{') {
      open.add(_Brace(i, !_isBlockBrace(masked.text, i)));
    } else if (c == '}') {
      if (open.isNotEmpty) open.removeLast();
    }
  }
  return order;
}

/// Whether the string literal [literal] is used as a MAP KEY, and under
/// which name.
///
/// A map key is a string literal that is followed by `:` and preceded by
/// `{` or `,` — the two positions a map entry can start in. The check reads
/// the masked source, so a `:` or a `,` that lives inside another string
/// never counts.
String? _mapKeyOf(String masked, _Literal literal) {
  var after = literal.end + 1;
  while (after < masked.length && _isSpace(masked[after])) {
    after++;
  }
  if (after >= masked.length || masked[after] != ':') return null;

  var before = literal.tokenStart - 1;
  while (before >= 0 && _isSpace(masked[before])) {
    before--;
  }
  if (before < 0) return null;
  if (masked[before] != '{' && masked[before] != ',') return null;

  return literal.inner;
}

/// Whether the brace at [offset] opens a BLOCK (a function body, a class
/// body, a switch body) rather than a map literal.
///
/// A block's braces are followed by statements, so a string literal inside
/// one that is followed by `:` is a `case` label, not a map key.
bool _isBlockBrace(String masked, int offset) {
  var index = offset - 1;
  while (index >= 0 && _isSpace(masked[index])) {
    index--;
  }
  if (index < 0) return false;
  if (masked[index] == ')') return true;

  var wordEnd = index;
  while (wordEnd >= 0 && _isIdentifierChar(masked[wordEnd])) {
    wordEnd--;
  }
  final word = masked.substring(wordEnd + 1, index + 1);
  return const {
    'else',
    'try',
    'finally',
    'do',
    'class',
    'enum',
    'mixin',
    'extension',
    'on',
    'async',
    'sync',
  }.contains(word);
}

/// The source with every string literal's text and every comment's text
/// blanked out (length preserved), plus the string literals that were found.
class _MaskedSource {
  _MaskedSource(this.text, this.literals);

  /// The source with all literal text blanked.
  final String text;

  /// The string literals, keyed by the offset of their first character.
  final Map<int, _Literal> literals;
}

/// A string literal in a source file.
class _Literal {
  _Literal(this.tokenStart, this.end, this.inner);

  /// The offset of the literal's first character (the `r` of a raw string).
  final int tokenStart;

  /// The offset of the literal's LAST quote character.
  final int end;

  /// The literal's text.
  final String inner;
}

/// An open brace in the masked source.
class _Brace {
  _Brace(this.offset, this.isMapLiteral);

  /// The offset of the brace.
  final int offset;

  /// Whether the brace opens a map literal rather than a block.
  final bool isMapLiteral;
}

/// The lexing context of a string literal.
class _StringContext {
  _StringContext(this.quote, this.raw, this.triple, this.tokenStart);

  /// The quote character (`'` or `"`).
  final String quote;

  /// Whether the literal is a raw string (`r'...'`).
  final bool raw;

  /// Whether the literal is triple-quoted.
  final bool triple;

  /// The offset of the literal's first character.
  final int tokenStart;
}

/// The lexing context of an interpolated string's `${...}` region.
class _CodeContext {
  _CodeContext(this.interpolation);

  /// Whether this region is an interpolation (and so returns to its string).
  final bool interpolation;

  /// The brace depth inside the region.
  int depth = 0;
}

/// Blanks every string literal's text and every comment's text in [text].
///
/// The blanked source keeps the original length and every line break, so an
/// offset in it is an offset in [text]. The literals' own quotes are blanked
/// too; the `${...}` region of an interpolated string is CODE and stays
/// visible, so the braces stay balanced.
_MaskedSource _maskLiteralsAndComments(String text) {
  final blanked = List<bool>.filled(text.length, false);
  final literals = <int, _Literal>{};
  final contexts = <Object>[_CodeContext(false)];
  var i = 0;

  void blank(int index) {
    if (index >= 0 && index < text.length) blanked[index] = true;
  }

  while (i < text.length) {
    final context = contexts.last;

    if (context is _CodeContext) {
      final c = text[i];
      if (c == '/' && i + 1 < text.length && text[i + 1] == '/') {
        while (i < text.length && text[i] != '\n') {
          blank(i);
          i++;
        }
        continue;
      }
      if (c == '/' && i + 1 < text.length && text[i + 1] == '*') {
        blank(i);
        blank(i + 1);
        i += 2;
        while (i < text.length) {
          if (text[i] == '*' && i + 1 < text.length && text[i + 1] == '/') {
            blank(i);
            blank(i + 1);
            i += 2;
            break;
          }
          blank(i);
          i++;
        }
        continue;
      }
      if (c == "'" || c == '"') {
        final raw = _isRawPrefix(text, i);
        final triple =
            i + 2 < text.length && text[i + 1] == c && text[i + 2] == c;
        final quoteLength = triple ? 3 : 1;
        final tokenStart = raw ? i - 1 : i;
        for (var k = 0; k < quoteLength; k++) {
          blank(i + k);
        }
        contexts.add(_StringContext(c, raw, triple, tokenStart));
        i += quoteLength;
        continue;
      }
      if (c == '{') {
        context.depth++;
        i++;
        continue;
      }
      if (c == '}') {
        if (context.interpolation && context.depth == 0) {
          // Closes the interpolation — the string resumes. The brace stays
          // visible in the masked source: it balances the `${` that opened
          // the region.
          contexts.removeLast();
          i++;
          continue;
        }
        context.depth--;
        i++;
        continue;
      }
      i++;
      continue;
    }

    final string = context as _StringContext;
    if (string.triple) {
      if (i + 2 < text.length &&
          text[i] == string.quote &&
          text[i + 1] == string.quote &&
          text[i + 2] == string.quote) {
        blank(i);
        blank(i + 1);
        blank(i + 2);
        literals[string.tokenStart] = _Literal(
          string.tokenStart,
          i + 2,
          text.substring(string.tokenStart + 3, i),
        );
        contexts.removeLast();
        i += 3;
        continue;
      }
      blank(i);
      i++;
      continue;
    }
    if (string.raw) {
      if (text[i] == string.quote) {
        blank(i);
        literals[string.tokenStart] = _Literal(
          string.tokenStart,
          i,
          text.substring(string.tokenStart + 1, i),
        );
        contexts.removeLast();
        i++;
        continue;
      }
      blank(i);
      i++;
      continue;
    }
    if (text[i] == r'\' && i + 1 < text.length) {
      blank(i);
      blank(i + 1);
      i += 2;
      continue;
    }
    if (text[i] == r'$' && i + 1 < text.length && text[i + 1] == '{') {
      // The interpolation's body is code — it stays visible in the mask.
      contexts.add(_CodeContext(true));
      i += 2;
      continue;
    }
    if (text[i] == string.quote) {
      blank(i);
      literals[string.tokenStart] = _Literal(
        string.tokenStart,
        i,
        text.substring(string.tokenStart + 1, i),
      );
      contexts.removeLast();
      i++;
      continue;
    }
    blank(i);
    i++;
  }

  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    buffer.write(blanked[index] ? ' ' : text[index]);
  }
  return _MaskedSource(buffer.toString(), literals);
}

/// Whether the quote at [quoteIndex] opens a RAW string (`r'...'`).
bool _isRawPrefix(String text, int quoteIndex) {
  if (quoteIndex < 1) return false;
  final prefix = text[quoteIndex - 1];
  if (prefix != 'r' && prefix != 'R') return false;
  if (quoteIndex < 2) return true;
  return !_isIdentifierChar(text[quoteIndex - 2]);
}

/// Whether [c] is whitespace.
bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\n' || c == '\r';

/// Whether [c] can be part of a Dart identifier.
bool _isIdentifierChar(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

/// The 1-based line number of [offset] in [text].
int _lineOf(String text, int offset) =>
    '\n'.allMatches(text.substring(0, offset)).length + 1;
