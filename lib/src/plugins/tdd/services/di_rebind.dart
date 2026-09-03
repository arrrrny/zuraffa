/// `DiRebinder` — swaps a generated mock datasource binding for the real
/// adapter behind the SAME generated interface (spec 913, phase 1).
///
/// The generated DI conventions this rebinds (di plugin +
/// skeleton/slice injection builders):
///
/// ```dart
/// // di/datasources/<snake>_mock_datasource_di.dart
/// getIt.registerLazySingleton<UserMockDataSource>(
///   () => UserMockDataSource());
/// // di/repositories/<snake>_repository_di.dart
/// getIt.registerLazySingleton<UserRepository>(
///   () => DataUserRepository(getIt<UserMockDataSource>()));
/// // slice di/injection.dart
/// DataUserRepository(UserMockDataSource())
/// ```
///
/// The rebind replaces the mock datasource class symbol with the real
/// adapter class symbol at those binding sites, drops the mock datasource
/// import, adds the adapter import, and proves the SAME-interface claim
/// by byte-identity: no file under a `domain/` directory changes. Real
/// implementations are NEVER generated — a missing adapter class is a
/// refusal naming the file the developer must write first.
library;

import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

/// Raised when the rebind cannot proceed honestly: no mock binding to
/// swap, adapter class not found (no auto-generation of real impls), or a
/// domain/ file would have to change (contract change is forbidden).
class DiRebindException implements Exception {
  const DiRebindException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One file's binding sites: how many mock-class references were swapped.
class DiBindingSite {
  const DiBindingSite({required this.file, required this.occurrences});
  final String file;
  final int occurrences;

  @override
  String toString() => 'DiBindingSite($file, $occurrences)';
}

/// The result of a successful rebind.
class DiRebindResult {
  const DiRebindResult({
    required this.entity,
    required this.mockClass,
    required this.adapterClass,
    required this.adapterFile,
    required this.sites,
    required this.interfaceFilesUntouched,
    required this.beforeBytes,
  });

  final String entity;

  /// The mock datasource class that was unbound (e.g.
  /// `UserMockDataSource`).
  final String mockClass;

  /// The real adapter class now bound (e.g. `UserRealAdapter`).
  final String adapterClass;

  /// Absolute path of the file declaring the adapter class.
  final String adapterFile;

  /// Per-file swapped binding sites.
  final List<DiBindingSite> sites;

  /// The generated interface layer files verified byte-identical across
  /// the swap (the same-interface proof).
  final List<String> interfaceFilesUntouched;

  /// Pre-swap bytes of every changed file, keyed by absolute path — the
  /// rollback payload the command restores when a gate blocks the swap.
  final Map<String, String> beforeBytes;
}

class DiRebinder {
  DiRebinder({required this.projectRoot});

  /// The target project root.
  final String projectRoot;

  String get _libRoot => p.join(projectRoot, 'lib');

  /// The mock datasource class symbol for [entity] (the di plugin's
  /// naming convention: `<Entity>MockDataSource`).
  String mockClassFor(String entity) => '${entity}MockDataSource';

  /// Whole-word symbol occurrences of [symbol] in [text].
  static int _countSymbol(String text, String symbol) {
    return RegExp('\\b$symbol\\b').allMatches(text).length;
  }

  static String _replaceSymbol(String text, String from, String to) {
    return text.replaceAll(RegExp('\\b$from\\b'), to);
  }

  /// Find the mock binding sites for [entity] under `lib/`: files whose
  /// text references the mock datasource class. Files that DECLARE the
  /// mock class (the mock implementation itself) are excluded — the
  /// mock is unbound, never rewritten or deleted.
  Future<List<DiBindingSite>> scan({required String entity}) async {
    final mockClass = mockClassFor(entity);
    final decl = RegExp('class\\s+$mockClass\\b');
    final sites = <DiBindingSite>[];
    for (final file in await _dartFiles()) {
      final raw = await File(file).readAsString();
      if (decl.hasMatch(raw)) continue;
      final occurrences = _countSymbol(raw, mockClass);
      if (occurrences > 0) {
        sites.add(DiBindingSite(file: file, occurrences: occurrences));
      }
    }
    return sites;
  }

  /// Resolve the file declaring [adapterClass], or throw
  /// [DiRebindException] — the command never generates real impls.
  Future<String> locateAdapter({required String adapterClass}) async {
    final decl = RegExp('class\\s+$adapterClass\\b');
    final candidates = <String>[];
    for (final file in await _dartFiles()) {
      final raw = await File(file).readAsString();
      if (decl.hasMatch(raw)) {
        candidates.add(file);
      }
    }
    if (candidates.isEmpty) {
      throw DiRebindException(
        'no file under lib/ declares "class $adapterClass" — realize never '
        'generates real implementations. Write the adapter (implementing '
        'the same generated datasource interface) first, then re-run.',
      );
    }
    candidates.sort();
    return candidates.first;
  }

  /// Swap every mock binding site to the real adapter: symbol replacement
  /// in the binding files, import fixup, and a byte-identity proof that no
  /// `domain/` (interface) file changed.
  Future<DiRebindResult> rebind({
    required String entity,
    required String adapterClass,
  }) async {
    final sites = await scan(entity: entity);
    if (sites.isEmpty) {
      throw DiRebindException(
        'no mock binding found for $entity (no reference to '
        '${mockClassFor(entity)} under lib/) — nothing to realize. Only a '
        'mock-era project can be realized.',
      );
    }
    final adapterFile = await locateAdapter(adapterClass: adapterClass);

    // The same-interface proof, part 1: hash every domain/ file before.
    final domainBefore = await _domainHashes();

    final mockClass = mockClassFor(entity);
    final mockImportSuffix = '${_snake(entity)}_mock_datasource.dart';
    final beforeBytes = <String, String>{};
    final changedSites = <DiBindingSite>[];

    for (final site in sites) {
      final file = File(site.file);
      final raw = await file.readAsString();
      beforeBytes[site.file] = raw;

      var next = _replaceSymbol(raw, mockClass, adapterClass);

      // Import fixup: drop the mock datasource import (the symbol is
      // gone from this file), add the adapter import when missing.
      next = _dropImport(next, mockImportSuffix, mockClass);
      next = _ensureImport(next, site.file, adapterFile, adapterClass);

      await file.writeAsString(next);
      changedSites.add(DiBindingSite(file: site.file, occurrences: site.occurrences));
    }

    // The same-interface proof, part 2: re-hash every domain/ file and
    // compare — any drift means the swap went through the contract,
    // which this command never does.
    final domainAfter = await _domainHashes();
    final untouched = <String>[];
    for (final entry in domainAfter.entries) {
      final before = domainBefore[entry.key];
      if (before == null || before != entry.value) {
        await _rollback(beforeBytes);
        throw DiRebindException(
          'refusing to rebind: the domain/interface file '
          '${p.relative(entry.key, from: projectRoot)} changed during the '
          'swap — the realize contract only swaps behind the interface, '
          'never through it. All binding files were rolled back.',
        );
      }
      untouched.add(entry.key);
    }

    return DiRebindResult(
      entity: entity,
      mockClass: mockClass,
      adapterClass: adapterClass,
      adapterFile: adapterFile,
      sites: changedSites,
      interfaceFilesUntouched: untouched..sort(),
      beforeBytes: beforeBytes,
    );
  }

  /// Rollback: restore every pre-swap file content (used when a gate
  /// blocks the swap after the rebind already landed).
  Future<void> rollback(DiRebindResult result) async {
    await _rollback(result.beforeBytes);
  }

  Future<void> _rollback(Map<String, String> beforeBytes) async {
    for (final entry in beforeBytes.entries) {
      await File(entry.key).writeAsString(entry.value);
    }
  }

  /// Every `.dart` file under `lib/`, sorted (deterministic scans).
  Future<List<String>> _dartFiles() async {
    final lib = Directory(_libRoot);
    if (!await lib.exists()) return const [];
    final files = <String>[];
    await for (final entity in lib.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity.path);
      }
    }
    files.sort();
    return files;
  }

  /// sha256 of every .dart file under any `domain/` directory of lib/.
  Future<Map<String, String>> _domainHashes() async {
    final hashes = <String, String>{};
    for (final file in await _dartFiles()) {
      final parts = p.split(p.relative(file, from: _libRoot));
      if (parts.contains('domain')) {
        hashes[file] = crypto.sha256
            .convert(await File(file).readAsBytes())
            .toString();
      }
    }
    return hashes;
  }

  /// Remove an import line whose URL ends with [suffix] when [symbol] no
  /// longer appears in the file body.
  static String _dropImport(String text, String suffix, String symbol) {
    if (suffix.isEmpty || _countSymbol(text, symbol) > 0) return text;
    return text.split('\n').where((line) {
      final trimmed = line.trim();
      final isImport = trimmed.startsWith("import '") ||
          trimmed.startsWith('import "');
      return !(isImport && trimmed.contains(suffix));
    }).join('\n');
  }

  /// Ensure the file at [file] imports the adapter file's path (relative
  /// to the file's own directory), adding the import after the last
  /// import line.
  static String _ensureImport(
    String text,
    String file,
    String adapterFile,
    String adapterClass,
  ) {
    if (_countSymbol(text, adapterClass) == 0) return text;
    final rel = p.relative(adapterFile, from: p.dirname(file));
    final uri = p.posix
        .normalize(p.posix.joinAll(p.split(rel)))
        .replaceAll('\\', '/');
    final target = "import '$uri';";
    if (text.contains(target)) return text;
    final lines = text.split('\n');
    var lastImport = -1;
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t.startsWith('import ') || t.startsWith('export ')) {
        lastImport = i;
      }
    }
    if (lastImport < 0) return '$target\n$text';
    lines.insert(lastImport + 1, target);
    return lines.join('\n');
  }

  static String _snake(String s) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '-' || c == ' ' || c == '_') {
        out.write('_');
      } else if (c.toUpperCase() == c && c.toLowerCase() != c && i > 0) {
        out.write('_');
        out.write(c.toLowerCase());
      } else {
        out.write(c.toLowerCase());
      }
    }
    return out.toString();
  }
}
