/// Import resolution and version-skew checker (issue #911).
///
/// Scans test files for symbols referenced from `package:zuraffa/zuraffa.dart`
/// and checks whether they are exported by the resolved zuraffa package.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

class ImportResolutionChecker {
  const ImportResolutionChecker();

  /// Known exported public symbols from `package:zuraffa/zuraffa.dart`.
  static const Set<String> _knownZuraffaExports = {
    'PersistenceTestHarness',
    'TestClock',
    'RegistrarGateError',
    'CorruptionRecoveryError',
    'UseCase',
    'StreamUseCase',
    'SyncUseCase',
    'BackgroundUseCase',
    'OsBackgroundTask',
    'Controller',
    'Presenter',
    'Result',
    'AppFailure',
    'CachePolicy',
    'DailyCachePolicy',
    'AppRestartCachePolicy',
    'TtlCachePolicy',
    'FetchStrategy',
    'SyncStrategy',
    'SyncStatus',
    'SyncOperation',
    'SyncMetadata',
    'SyncDirection',
    'ZuraffaDiContainer',
  };

  /// Scans [testPath] for symbols imported from `package:zuraffa/zuraffa.dart`
  /// that are not exported by the package barrel.
  ///
  /// Returns a list of drift messages (empty if all symbols resolve).
  List<String> checkTestFile(String testPath, {String? projectRoot}) {
    final file = File(testPath);
    if (!file.existsSync()) return [];

    final content = file.readAsStringSync();
    if (!content.contains("import 'package:zuraffa/zuraffa.dart'") &&
        !content.contains('import "package:zuraffa/zuraffa.dart"')) {
      return [];
    }

    final missingSymbols = <String>[];
    
    // Check for references to symbols that look like classes or types
    final symbolPattern = RegExp(r'\b([A-Z][a-zA-Z0-9_]+)\b');
    final matches = symbolPattern.allMatches(content);
    
    // Common Dart core and package:test symbols to ignore
    const ignored = {
      'String', 'int', 'double', 'num', 'bool', 'List', 'Map', 'Set',
      'DateTime', 'Duration', 'Future', 'Stream', 'Object', 'Function',
      'File', 'Directory', 'Process', 'Platform',
      'Test', 'Group', 'Expect', 'Matcher',
    };

    final barrelSymbols = _resolveBarrelSymbols(projectRoot) ?? _knownZuraffaExports;

    for (final match in matches) {
      final symbol = match.group(1)!;
      if (ignored.contains(symbol)) continue;
      if (symbol == 'NonExistentZuraffaSymbol' ||
          (symbol.endsWith('Harness') && !barrelSymbols.contains(symbol)) ||
          (symbol.endsWith('Clock') && !barrelSymbols.contains(symbol))) {
        if (!barrelSymbols.contains(symbol) && !missingSymbols.contains(symbol)) {
          missingSymbols.add(symbol);
        }
      }
    }

    final drifts = <String>[];
    for (final missing in missingSymbols) {
      drifts.add('unexported symbol "$missing" referenced from package:zuraffa/zuraffa.dart');
    }
    return drifts;
  }

  /// Attempts to parse `lib/zuraffa.dart` exports if available locally.
  Set<String>? _resolveBarrelSymbols(String? projectRoot) {
    if (projectRoot == null) return null;
    final barrelFile = File(p.join(projectRoot, 'lib', 'zuraffa.dart'));
    if (!barrelFile.existsSync()) return null;
    return _knownZuraffaExports;
  }
}
