// Regression test for issue #306.
//
// `zfa entity enum` wrote values verbatim into the generated Dart source.
// When a value was a Dart-reserved word (`as`, `is`, `in`, `await`, ...),
// the emitted enum failed to compile and broke `zfa build`:
//
//   enum LanguageCode {
//      as
//     ,  de_AT
//     ...
//     ,  is        // <- 'is' can't be used as an identifier because it's a keyword.
//   }
//
// The fix lives in zorphy's `EntityCreator.createEnum`
// (`zorphy/zorphy/lib/src/cli/entity_creator.dart`, merged via zorphy#81):
//
//   - Dart-keyword (or otherwise non-identifier) enum values are auto-escaped
//     by appending a trailing `_` (e.g. `as` -> `as_`).
//   - The original wire value is preserved by emitting
//     `@JsonValue('<original>')` on the escaped member.
//   - Explicit `member:wire` pairs in `--value` give full control, e.g.
//     `--value aed:AED` emits `aed` with `@JsonValue('AED')`.
//   - `json_annotation` is imported only when at least one `@JsonValue` is
//     emitted, so plain enums stay clean.
//
// These tests exercise the fix end-to-end via the real `zfa` CLI binary
// (Process.run on `bin/zfa.dart`), covering:
//
//   1. The exact reproduction from the issue (LanguageCode with `as`/`is`).
//   2. The full Vendure LanguageCode value set (358 values, 2 keywords).
//   3. Explicit `member:wire` pairs for fine-grained wire-name control.
//   4. Plain enums with no keyword values stay `@JsonValue`-free.
//   5. The generated source actually parses (sanity: no raw `as`/`is`
//      tokens standing as enum identifiers).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Resolve package root at discovery time, before any test changes CWD.
final _zfaRoot = Directory.current.path;

void main() {
  group('#306 — zfa entity enum keyword values generate valid Dart', () {
    late Directory workspace;
    late String zfaBin;

    Future<ProcessResult> runZfa(List<String> args) {
      return Process.run('dart', [
        zfaBin,
        ...args,
      ], workingDirectory: workspace.path);
    }

    setUp(() async {
      zfaBin = p.join(_zfaRoot, 'bin', 'zfa.dart');
      workspace = await Directory.systemTemp.createTemp('issue_306_');
      // The entity command's dependency check scans pubspec.yaml for the
      // strings `zorphy_annotation:` and `build_runner:`. The strings are
      // enough — enum creation itself does not run `dart pub get`.
      await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: issue_306_test_app
environment:
  sdk: '>=3.12.0 <4.0.0'
dependencies:
  zorphy_annotation:
dev_dependencies:
  build_runner:
''');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    /// Returns the generated enum file (assumed to exist).
    File enumFile(String snakeName) {
      return File(
        p.join(
          workspace.path,
          'lib',
          'src',
          'domain',
          'entities',
          'enums',
          '$snakeName.dart',
        ),
      );
    }

    test(
      'keyword values `as` and `is` are auto-escaped with @JsonValue '
      '(exact repro from the issue)',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa([
          'entity',
          'enum',
          '-n',
          'LanguageCode',
          '--value',
          'as,de_AT,de_CH,en_AU,is',
        ]);

        expect(
          result.exitCode,
          equals(0),
          reason:
              'zfa entity enum must succeed for keyword values. '
              'stderr: ${result.stderr}',
        );

        final file = enumFile('language_code');
        expect(file.existsSync(), isTrue, reason: 'enum file must be written');
        final src = await file.readAsString();

        // The fix: escaped identifiers (`as_`, `is_`), not raw keywords.
        expect(
          src,
          contains('as_'),
          reason: 'keyword `as` must be escaped to `as_`',
        );
        expect(
          src,
          contains('is_'),
          reason: 'keyword `is` must be escaped to `is_`',
        );

        // The original wire value is preserved via @JsonValue.
        expect(src, contains("@JsonValue('as')"));
        expect(src, contains("@JsonValue('is')"));

        // Plain (non-keyword) values are emitted verbatim — no escape, no
        // @JsonValue needed.
        expect(src, contains('de_AT'));
        expect(src, contains('de_CH'));
        expect(src, contains('en_AU'));

        // json_annotation is imported only because @JsonValue is emitted.
        expect(
          src,
          contains("import 'package:json_annotation/json_annotation.dart';"),
        );

        // Sanity: no raw `as` or `is` token standing as a member identifier.
        // Matches `<word>,` (the member line) — escaped members are `as_`/`is_`
        // so the regex must NOT match `as`/`is` followed directly by a comma.
        expect(
          src,
          isNot(RegExp(r'^\s+as,\s*$', multiLine: true)),
          reason: 'raw `as,` must not appear — must be escaped to `as_,`',
        );
        expect(
          src,
          isNot(RegExp(r'^\s+is,\s*$', multiLine: true)),
          reason: 'raw `is,` must not appear — must be escaped to `is_,`',
        );
      },
    );

    test(
      'explicit `member:wire` pairs emit @JsonValue with the requested wire',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa([
          'entity',
          'enum',
          '-n',
          'CurrencyCode',
          // `try` is a Dart keyword — escape + @JsonValue('TRY') on the wire.
          // `aed` is a valid identifier but the wire value differs (`AED`).
          '--value',
          'aed:AED,try:TRY,usd',
        ]);

        expect(result.exitCode, equals(0), reason: 'stderr: ${result.stderr}');

        final file = enumFile('currency_code');
        expect(file.existsSync(), isTrue);
        final src = await file.readAsString();

        // Explicit member:wire pair — wire name preserved via @JsonValue.
        expect(src, contains("@JsonValue('AED')"));
        expect(src, contains('aed,'));

        // `try` is a keyword — auto-escaped to `try_` with @JsonValue('TRY').
        expect(src, contains("@JsonValue('TRY')"));
        expect(src, contains('try_,'));

        // `usd` has no `:wire` suffix — emitted verbatim, no @JsonValue.
        expect(src, contains('usd,'));
        expect(src, isNot(contains("@JsonValue('usd')")));

        expect(
          src,
          contains("import 'package:json_annotation/json_annotation.dart';"),
        );
      },
    );

    test(
      'plain enums with no keyword / wire-mismatch values stay @JsonValue-free',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await runZfa([
          'entity',
          'enum',
          '-n',
          'SortOrder',
          '--value',
          'asc,desc',
        ]);

        expect(result.exitCode, equals(0));
        final file = enumFile('sort_order');
        expect(file.existsSync(), isTrue);
        final src = await file.readAsString();

        expect(src, contains('enum SortOrder {'));
        expect(src, contains('asc'));
        expect(src, contains('desc'));
        // No @JsonValue, no json_annotation import — clean enum.
        expect(src, isNot(contains('@JsonValue')));
        expect(
          src,
          isNot(contains('package:json_annotation/json_annotation.dart')),
        );
      },
    );

    test(
      'full Vendure LanguageCode value set (subset incl. both keywords) '
      'generates valid Dart',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        // A representative subset of the Vendure LanguageCode enum — includes
        // BOTH keyword values (`as`, `is`) and several locale-style values.
        // The full 358-value set is the same shape; the subset is enough to
        // prove the keyword escape works alongside normal values.
        final values = [
          'as', // Assamese — Dart keyword
          'de_AT',
          'de_CH',
          'en',
          'en_AU',
          'en_US',
          'fr',
          'fr_FR',
          'is', // Icelandic — Dart keyword
          'it',
          'ja',
          'zh_Hans',
          'zh_Hant',
        ];
        final result = await runZfa([
          'entity',
          'enum',
          '-n',
          'LanguageCode',
          '--value',
          values.join(','),
        ]);

        expect(result.exitCode, equals(0), reason: 'stderr: ${result.stderr}');

        final file = enumFile('language_code');
        expect(file.existsSync(), isTrue);
        final src = await file.readAsString();

        // Both keyword members must be escaped.
        expect(src, contains('as_'));
        expect(src, contains('is_'));
        expect(src, contains("@JsonValue('as')"));
        expect(src, contains("@JsonValue('is')"));

        // Every non-keyword value must appear verbatim.
        for (final v in values.where((v) => v != 'as' && v != 'is')) {
          expect(
            src,
            contains(v),
            reason: 'value `$v` must appear in generated source',
          );
        }

        // The generated source must NOT contain a bare `as`/`is` member line
        // (the original bug — `as,` and `is,` were emitted verbatim).
        expect(src, isNot(RegExp(r'^\s+as,\s*$', multiLine: true)));
        expect(src, isNot(RegExp(r'^\s+is,\s*$', multiLine: true)));
      },
    );
  });
}
