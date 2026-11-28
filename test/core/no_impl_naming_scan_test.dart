// The no-`Impl` naming sweep (issue #2196).
//
// Policy: nowhere in the codebase — hand-written or generated — may a class
// name or file name contain `Impl` (suffix or infix). The `*Impl` suffix
// describes WHAT a class is mechanically (an implementation) instead of its
// ROLE in the architecture, reads horribly (`ProductRepositoryImpl`), and
// `zfa` must never emit such a name. The role-descriptive convention the
// generators already follow is `ProductRepository` (interface) /
// `DataProductRepository` (implementation).
//
// The scan is textual on purpose: it is a drift tripwire, not a compiler. It
// mirrors `no_jit_zfa_spawn_scan_test.dart`.
//
// Two detectors:
//   A. a class declaration whose name ends in `Impl` — `class\s+\w*Impl\b`.
//      The `\b` keeps `class ImplementationGenerator` (a legitimate English
//      word) out. The scan is textual, so a fixture STRING that writes such a
//      class (`'class Impl {}'`) is caught too — the rule bans it just the same.
//   B. a `.dart` file whose basename carries `impl` as a snake_case token
//      (`(^|_)impl(_|\.)`): `local_generator_impl.dart` matches;
//      `implementation_generator.dart` does NOT — `impl` there is the first
//      four letters of a word, not the anti-pattern.
//
// Exclusions: `.zorphy.dart` and `.g.dart` are generated — regenerated, never
// hand-edited — so the sweep holds the GENERATOR source to the rule, not its
// output. This file is the one place the token is allowed: it names the rule
// it enforces and carries the banned shapes as test inputs, so it is skipped.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/zuraffa.dart';

const String repoRoot = '.';

/// This file — skipped by both sweeps (see the library comment).
const String kSelfFile = 'test/core/no_impl_naming_scan_test.dart';

/// Directories the sweep holds to the rule (issue #2196 acceptance:
/// lib/, bin/, test/, example/, examples/).
const List<String> kScannedDirs = ['lib', 'bin', 'test', 'example', 'examples'];

/// Generated files are regenerated, never hand-edited — excluded.
bool _isGenerated(String path) =>
    path.endsWith('.zorphy.dart') || path.endsWith('.g.dart');

/// A class declaration whose name ends in `Impl` (`class Impl`,
/// `class UserRepositoryImpl`). The `\b` after `Impl` keeps a legitimate
/// `Implementation…` name out.
final RegExp _implClassDecl = RegExp(r'class\s+\w*Impl\b');

/// A basename carrying `impl` as a snake_case token (`_impl.`, `_impl_`,
/// `impl.`). `implementation` is spared: after `impl` comes `e`, not `_`/`.`.
final RegExp _implFileToken = RegExp(r'(^|_)impl(_|\.)');

List<File> _dartFilesUnder(String dir) {
  final entity = Directory(p.join(repoRoot, dir));
  if (!entity.existsSync()) return const [];
  return entity
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !_isGenerated(f.path))
      .toList();
}

/// Repo-root-relative POSIX form, so set membership is stable across
/// `dart test` invocation styles.
String _normalized(String path) {
  var rel = path.replaceAll('\\', '/');
  while (rel.startsWith('./')) {
    rel = rel.substring(2);
  }
  return rel;
}

void main() {
  group('no-`Impl` naming sweep', () {
    test('the detectors fire on the banned shapes and spare the legitimate '
        'ones (positive + negative controls)', () {
      // Without these a detector that silently stopped matching after a
      // refactor would leave every sweep below green with no signal at all.
      expect(_implClassDecl.hasMatch('class Impl {}'), isTrue);
      expect(
        _implClassDecl.hasMatch('class UserRepositoryImpl implements X {'),
        isTrue,
      );
      expect(
        _implClassDecl.hasMatch('class ImplementationGenerator {}'),
        isFalse,
        reason: '`Implementation` is a word, not the `Impl` anti-pattern',
      );
      expect(_implFileToken.hasMatch('local_generator_impl.dart'), isTrue);
      expect(_implFileToken.hasMatch('impl.dart'), isTrue);
      expect(
        _implFileToken.hasMatch('implementation_generator.dart'),
        isFalse,
        reason: 'the implementation generator is a legitimate role name',
      );
    });

    test('no scanned dir declares a class whose name ends in `Impl`', () {
      final offenders = <String>[];
      var scanned = 0;
      for (final dir in kScannedDirs) {
        for (final file in _dartFilesUnder(dir)) {
          if (_normalized(file.path) == kSelfFile) continue;
          scanned++;
          if (_implClassDecl.hasMatch(file.readAsStringSync())) {
            offenders.add(_normalized(file.path));
          }
        }
      }
      // A sweep over an empty set passes vacuously: fail loudly instead of
      // going green without reading a single file.
      expect(scanned, greaterThan(0), reason: 'the sweep read no file at all');
      expect(
        offenders,
        isEmpty,
        reason:
            'a class name must describe its ROLE, not that it is an '
            'implementation: use `Data<Name>Repository` (or a fake), never '
            '`<Name>Impl` or a bare `class Impl`. Offenders: $offenders',
      );
    });

    test('no scanned dir carries a `.dart` file whose name is an `impl` '
        'token', () {
      final offenders = <String>[];
      var scanned = 0;
      for (final dir in kScannedDirs) {
        for (final file in _dartFilesUnder(dir)) {
          if (_normalized(file.path) == kSelfFile) continue;
          scanned++;
          if (_implFileToken.hasMatch(p.basename(file.path))) {
            offenders.add(_normalized(file.path));
          }
        }
      }
      expect(scanned, greaterThan(0), reason: 'the sweep read no file at all');
      expect(
        offenders,
        isEmpty,
        reason:
            'a file name must describe its role, not that it holds an '
            'implementation: `local_generation_methods.dart`, never '
            '`local_generator_impl.dart`. Offenders: $offenders',
      );
    });

    // The source sweeps above only see checked-in text. They cannot catch a
    // generator that BUILDS an `Impl` name at runtime and emits it as a class
    // (issue #2196 / review of #2197). This test exercises the generator's
    // string output directly and asserts the emitted code carries no `Impl`
    // class name — the gap the source scan structurally cannot close.
    test('the graphql repository generator emits no `Impl` class name', () {
      final gen = RepositoryGenerator(typeMapper: TypeMapper());
      final code = gen.generate(
        name: 'Product',
        methods: [
          RepoMethod(
            name: 'getProduct',
            returnType: const GraphQLScalarType(name: 'ID'),
            args: const [],
          ),
        ],
      );
      // The interface keeps its role name; the implementation is
      // `DataProductRepository`, never `ProductRepositoryImpl`.
      expect(code, contains('abstract class ProductRepository'));
      expect(code, contains('class DataProductRepository'));
      expect(
        _implClassDecl.hasMatch(code),
        isFalse,
        reason:
            'the generator emitted an `Impl` class name — issue #2196 bans '
            'it in generated names too. Output:\n$code',
      );
    });
  });
}
