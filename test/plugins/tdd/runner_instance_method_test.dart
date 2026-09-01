// Regression guard for issue #695.
//
// `runner.dart` declared `_firstMatchValue` as `static` while all six call
// sites invoked it unqualified, instance-style. On the toolchain that
// surfaced the bug this stopped the build with:
//   Error: The method '_firstMatchValue' isn't defined for the type
//   'SingleTestRunner'.
// The mandated remediation (issue #695, Option B — preferred) is to make it
// an instance method so the unqualified calls keep working.
//
// This guard pins the declaration shape so a future `static` re-introduction
// fails fast in the default (fast) tier instead of surfacing as a compile
// error downstream in `zfa tdd run`.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Walk up from the current directory until the zuraffa package root
/// (the pubspec.yaml whose `name:` is `zuraffa`) is found.
Directory _packageRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    if (pubspec.existsSync()) {
      final name = pubspec
          .readAsStringSync()
          .split('\n')
          .firstWhere((l) => l.startsWith('name:'), orElse: () => '');
      if (name.trim() == 'name: zuraffa') return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('zuraffa package root not found from ${Directory.current.path}');
    }
    dir = parent;
  }
}

void main() {
  test(
    '#695: _firstMatchValue is an instance method (no `static` keyword)',
    () {
      final root = _packageRoot();
      final source = File(
        '${root.path}${Platform.pathSeparator}'
        'lib${Platform.pathSeparator}src${Platform.pathSeparator}plugins'
        '${Platform.pathSeparator}tdd${Platform.pathSeparator}services'
        '${Platform.pathSeparator}runner.dart',
      ).readAsStringSync();

      final declaration = RegExp(
        r'^\s*(static\s+)?String\?\s+_firstMatchValue\(',
        multiLine: true,
      ).firstMatch(source);

      expect(
        declaration,
        isNotNull,
        reason: '_firstMatchValue declaration not found in runner.dart',
      );
      expect(
        declaration!.group(1),
        isNull,
        reason:
            'runner.dart `_firstMatchValue` must NOT be declared '
            '`static` (issue #695): it is called unqualified from six '
            'instance call sites, and a `static` declaration is the '
            'static/instance mismatch the issue flags.',
      );
    },
  );
}
