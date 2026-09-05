import 'package:path/path.dart' as path;

import '../core/context/file_system.dart';
import '../core/generator_options.dart';
import '../models/generated_file.dart';
import '../utils/file_utils.dart';

/// Bug #989 — removes stale use case test imports after the issue #921
/// rejection.
///
/// When the entity pipeline refuses to (re)generate use cases whose action
/// methods are absent from the entity's repository/service interface (#921),
/// pre-existing test files that import those never-generated use case files
/// remain in the suite and break `dart test` at load time ("Error when
/// reading 'lib/src/domain/usecases/task/cancel_task_usecase.dart': No such
/// file or directory"). The suite never re-runs to a clean baseline because
/// every run dies at load before a single test executes.
///
/// A test file that imports a use case file which does not exist anywhere in
/// the package is stale by construction: it can never compile, and the tests
/// it carries reference surface the generator has explicitly refused to
/// create. This cleaner sweeps the project's `test/` directory and, for every
/// affected test file:
///
///   - removes the stale import directives, and
///   - removes the `test`/`testWidgets` statements that reference the
///     non-existent use case classes,
///
/// deleting the whole file when every use case import it has is stale (the
/// per-method test files emitted by the test plugin are wholly stale by
/// construction) or when the surgery leaves no executable test behind. Test
/// files importing only existing use cases are never touched, so the kept
/// surface is exactly the actually-existing surface.
///
/// The sweep only runs when the caller reports that #921 rejected at least
/// one use case in this generation plan (see [EntityUseCaseGenerator]); it
/// never changes the rejection semantics itself — it only cleans up the
/// test-side debris the rejection leaves behind. When the package root
/// cannot be resolved (no `pubspec.yaml` above [outputDir]) the cleaner
/// fails open and does nothing.
class StaleUsecaseTestCleaner {
  final String outputDir;
  final GeneratorOptions options;
  final FileSystem fileSystem;

  const StaleUsecaseTestCleaner({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    this.fileSystem = const DefaultFileSystem(),
  });

  /// Sweeps the project's `test/` directory for stale use case test imports.
  ///
  /// Returns a [GeneratedFile] record for every test file that was deleted
  /// or surgically cleaned, so callers can surface the cleanup in their
  /// generation receipts.
  Future<List<GeneratedFile>> clean() async {
    final results = <GeneratedFile>[];
    final packageRoot = await _findPackageRoot();
    if (packageRoot == null) return results;

    final packageName = await _resolvePackageName(packageRoot);
    if (packageName == null) return results;

    final libDir = path.join(packageRoot, 'lib');
    final testDir = path.join(packageRoot, 'test');
    if (!await fileSystem.isDirectory(libDir)) return results;
    if (!await fileSystem.isDirectory(testDir)) return results;

    // Every use case file basename that exists in the package. A test
    // import referencing a basename absent from this set is stale by
    // construction — the use case file does not exist anywhere under lib/.
    final existingUsecaseFiles = <String>{};
    for (final entityPath in await fileSystem.list(libDir, recursive: true)) {
      if (entityPath.endsWith('_usecase.dart')) {
        existingUsecaseFiles.add(path.basename(entityPath));
      }
    }

    for (final testPath in await fileSystem.list(testDir, recursive: true)) {
      if (!testPath.endsWith('.dart')) continue;
      // `list(recursive: true)` also yields directories; a directory whose
      // name ends in `.dart` is not a realistic layout, but guard anyway.
      if (await fileSystem.isDirectory(testPath)) continue;
      final source = await fileSystem.read(testPath);
      final imports = _usecaseImports(source, packageName);
      if (imports.isEmpty) continue;

      final stale = imports
          .where((i) => !existingUsecaseFiles.contains(path.basename(i.uri)))
          .toList(growable: false);
      if (stale.isEmpty) continue;

      final keptCount = imports.length - stale.length;
      final staleClasses = stale
          .map((i) => _classNameFromBasename(path.basename(i.uri)))
          .toSet();
      final spans = _callStatementSpans(source, const {'test', 'testWidgets'});
      final staleTestCount = spans
          .where(
            (s) => staleClasses.any(
              (c) => _referencesClass(source.substring(s.start, s.end), c),
            ),
          )
          .length;
      final remaining = spans.length - staleTestCount;

      if (keptCount == 0 || (staleTestCount > 0 && remaining == 0)) {
        // Wholly stale: every use case import is dead (per-method test
        // files), or the surgery leaves no executable test behind.
        results.add(
          await FileUtils.deleteFile(
            testPath,
            'test',
            dryRun: options.dryRun,
            verbose: options.verbose,
            fileSystem: fileSystem,
          ),
        );
        if (!options.dryRun) {
          print(
            '  Deleted stale test file ${_relative(testPath, packageRoot)}: '
            'references non-existent usecase(s) '
            '${stale.map((i) => path.basename(i.uri)).join(', ')} '
            '(issue #921, bug #989).',
          );
        }
        continue;
      }

      final cleaned = _removeStaleSurface(source, stale, spans);
      results.add(
        await FileUtils.writeFile(
          testPath,
          cleaned,
          'test',
          force: true,
          dryRun: options.dryRun,
          verbose: options.verbose,
          fileSystem: fileSystem,
        ),
      );
      if (!options.dryRun) {
        print(
          '  Removed stale usecase test imports from '
          '${_relative(testPath, packageRoot)} (issue #921, bug #989): '
          '${stale.length} import(s) — '
          '${stale.map((i) => path.basename(i.uri)).join(', ')}.',
        );
      }
    }
    return results;
  }

  /// Walks up from [outputDir] looking for the enclosing package root
  /// (the nearest directory containing a `pubspec.yaml`).
  Future<String?> _findPackageRoot() async {
    var dir = path.normalize(path.absolute(outputDir));
    for (var i = 0; i < 8; i++) {
      if (await fileSystem.exists(path.join(dir, 'pubspec.yaml'))) {
        return dir;
      }
      final parent = path.dirname(dir);
      if (parent == dir) return null;
      dir = parent;
    }
    return null;
  }

  Future<String?> _resolvePackageName(String packageRoot) async {
    try {
      final pubspec = await fileSystem.read(
        path.join(packageRoot, 'pubspec.yaml'),
      );
      for (final line in pubspec.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.startsWith('name:')) {
          final name = trimmed.substring('name:'.length).trim();
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {
      // Fail open: an unreadable pubspec means no verified package
      // context — do not touch any test files.
    }
    return null;
  }

  /// Returns every import directive of [source] that references a use case
  /// file of the project's own package (`package:<name>/..._usecase.dart`
  /// or a relative path ending in `_usecase.dart`). Imports of other
  /// packages cannot be verified against this package's lib/ and are
  /// never treated as stale.
  List<_UsecaseImport> _usecaseImports(String source, String packageName) {
    final result = <_UsecaseImport>[];
    for (final match in _importPattern.allMatches(source)) {
      final uri = match.group(1)!;
      if (!uri.endsWith('_usecase.dart')) continue;
      final isOwnPackage =
          uri.startsWith('package:$packageName/') ||
          !uri.startsWith('package:');
      if (!isOwnPackage) continue;
      result.add(
        _UsecaseImport(uri: uri, lineSpan: _lineSpan(source, match.start)),
      );
    }
    return result;
  }

  static final RegExp _importPattern = RegExp(r'''import\s+['"]([^'"]+)['"]''');

  /// Returns [source] with every stale import directive and every
  /// `test`/`testWidgets` statement referencing a stale use case class
  /// removed, collapsing the blank lines the removals leave behind.
  String _removeStaleSurface(
    String source,
    List<_UsecaseImport> stale,
    List<_Span> testSpans,
  ) {
    final staleClasses = stale
        .map((i) => _classNameFromBasename(path.basename(i.uri)))
        .toSet();
    final cuts = <_Span>[
      for (final i in stale) i.lineSpan,
      for (final span in testSpans)
        if (staleClasses.any(
          (c) => _referencesClass(source.substring(span.start, span.end), c),
        ))
          span,
    ]..sort((a, b) => a.start.compareTo(b.start));

    final buffer = StringBuffer();
    var cursor = 0;
    for (final cut in cuts) {
      if (cut.start < cursor) continue; // overlapping cut — already removed
      buffer.write(source.substring(cursor, cut.start));
      cursor = cut.end;
    }
    buffer.write(source.substring(cursor));
    return _collapseBlankLines(buffer.toString());
  }

  String _collapseBlankLines(String source) {
    return source.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  String _relative(String filePath, String packageRoot) {
    final rel = path.relative(filePath, from: packageRoot);
    return rel.startsWith('/') ? filePath : rel;
  }

  /// Derives the use case class name from its file basename, mirroring the
  /// generator's naming: `cancel_task_usecase.dart` -> `CancelTaskUseCase`,
  /// `get_task_list_usecase.dart` -> `GetTaskListUseCase`.
  String _classNameFromBasename(String basename) {
    final stem = basename.replaceAll(RegExp(r'_usecase\.dart$'), '');
    final pascal = stem
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join();
    return '${pascal}UseCase';
  }

  bool _referencesClass(String statement, String className) {
    return RegExp('\\b$className\\b').hasMatch(statement);
  }

  /// Source span of the full line containing [offset], including the
  /// trailing newline.
  _Span _lineSpan(String source, int offset) {
    final start = _lineStart(source, offset);
    final nl = source.indexOf('\n', offset);
    final end = nl == -1 ? source.length : nl + 1;
    return _Span(start: start, end: end);
  }

  int _lineStart(String source, int offset) {
    var start = offset;
    while (start > 0 && source[start - 1] != '\n') {
      start--;
    }
    return start;
  }

  /// Extracts the source spans of every complete `test(`/`testWidgets(`
  /// call statement (from the start of its line through the trailing `;`
  /// and newline) at any nesting depth, skipping string literals and
  /// comments so parens inside them never unbalance the scan.
  List<_Span> _callStatementSpans(String source, Set<String> names) {
    final spans = <_Span>[];
    for (final name in names) {
      final pattern = RegExp('$name\\s*\\(');
      for (final match in pattern.allMatches(source)) {
        final identifierStart = match.start;
        if (!_isIdentifierBoundary(source, identifierStart)) continue;
        final openParen = source.indexOf('(', identifierStart + name.length);
        if (openParen == -1) continue;
        final closeParen = _matchingParen(source, openParen);
        if (closeParen == null) continue;
        var end = closeParen + 1;
        while (end < source.length &&
            (source[end] == ' ' ||
                source[end] == '\n' ||
                source[end] == '\r')) {
          end++;
        }
        if (end < source.length && source[end] == ';') end++;
        final start = _lineStart(source, identifierStart);
        spans.add(_trimSpanEnd(source, _Span(start: start, end: end)));
      }
    }
    spans.sort((a, b) => a.start.compareTo(b.start));
    return spans;
  }

  bool _isIdentifierBoundary(String source, int identifierStart) {
    if (identifierStart == 0) return true;
    final prev = source[identifierStart - 1];
    // A preceding `.` or identifier char means this is a member access
    // (e.g. `foo.test(`) — not a top-level test statement.
    if (prev == '.' || RegExp(r'[a-zA-Z0-9_$]').hasMatch(prev)) return false;
    return true;
  }

  /// Consumes the newline following a cut span's end so statement removals
  /// do not leave dangling blank lines behind.
  _Span _trimSpanEnd(String source, _Span span) {
    var end = span.end;
    if (end < source.length && source[end] == '\r') end++;
    if (end < source.length && source[end] == '\n') end++;
    return _Span(start: span.start, end: end);
  }

  /// Returns the offset of the `)` matching the `(` at [openParen], or null
  /// when unbalanced. String literals and comments are skipped so their
  /// contents never affect the depth.
  int? _matchingParen(String source, int openParen) {
    var depth = 0;
    var i = openParen;
    while (i < source.length) {
      final ch = source[i];
      if (ch == "'" || ch == '"') {
        i = _skipString(source, i);
        continue;
      }
      if (ch == '/' && i + 1 < source.length) {
        if (source[i + 1] == '/') {
          final nl = source.indexOf('\n', i);
          i = nl == -1 ? source.length : nl + 1;
          continue;
        }
        if (source[i + 1] == '*') {
          final close = source.indexOf('*/', i + 2);
          i = close == -1 ? source.length : close + 2;
          continue;
        }
      }
      if (ch == '(') depth++;
      if (ch == ')') {
        depth--;
        if (depth == 0) return i;
      }
      i++;
    }
    return null;
  }

  /// Returns the offset just past the string literal starting at [start]
  /// (a `'` or `"` character). Handles raw strings, escapes, `${...}`
  /// interpolation (where nested strings may appear) and triple quotes.
  int _skipString(String source, int start) {
    final quote = source[start];
    var isRaw = false;
    var j = start - 1;
    while (j >= 0 && source[j] == 'r') {
      isRaw = true;
      j--;
    }
    final triple = source.startsWith('$quote$quote$quote', start);
    var i = triple ? start + 3 : start + 1;
    while (i < source.length) {
      final ch = source[i];
      if (!triple && ch == quote) return i + 1;
      if (triple && source.startsWith('$quote$quote$quote', i)) return i + 3;
      if (ch == r'$' &&
          !isRaw &&
          i + 1 < source.length &&
          source[i + 1] == '{') {
        i = _skipInterpolation(source, i + 2);
        continue;
      }
      if (ch == r'\' && !isRaw && i + 1 < source.length) {
        i += 2;
        continue;
      }
      i++;
    }
    return source.length;
  }

  int _skipInterpolation(String source, int start) {
    var depth = 1;
    var i = start;
    while (i < source.length && depth > 0) {
      final ch = source[i];
      if (ch == "'" || ch == '"') {
        i = _skipString(source, i);
        continue;
      }
      if (ch == '{') depth++;
      if (ch == '}') depth--;
      i++;
    }
    return i;
  }
}

class _UsecaseImport {
  final String uri;
  final _Span lineSpan;

  const _UsecaseImport({required this.uri, required this.lineSpan});
}

class _Span {
  final int start;
  final int end;

  const _Span({required this.start, required this.end});
}
