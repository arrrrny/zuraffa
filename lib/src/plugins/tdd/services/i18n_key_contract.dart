/// The i18n key contract (issue #965): the key is the contract, the
/// literal is the anchor.
///
/// The widget lane pins quoted EN literals — `Text('ZikZak')` in the view,
/// `find.text('ZikZak')` in the test — while production renders through
/// slang keys (`t.app.name`, 7+ locales) and the host enforces a 100%
/// localization hard gate. This contract lets Presentation layer-contract
/// rows declare i18n surfaces as `key:` tokens with the EN literal as the
/// human-readable anchor (and the fallback for non-i18n hosts):
///
/// ```markdown
/// ### Layer Contracts
///
/// **Presentation**:
/// - `LoginSection`: `ShadInput` for email, `key: auth.signIn -> 'Sign in'`
/// ```
///
/// Extraction rides the EXISTING [LayerContract] shape, so both producers —
/// `SpecParser.parseLayerContracts` (spec.md) and
/// `TestListReader.readLayerContracts` (tdd/test-list.md) — feed the same
/// table. `LiteralKind.key` (issue #964) is the taxonomy half this contract
/// activates.
library;

import 'dart:convert';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../../tdd/services/ui_ledger_builder.dart';
import 'spec_parser.dart';
import 'test_list_reader.dart';

/// One declared i18n surface: the dotted slang key plus the EN anchor.
///
/// The anchor is the human-readable literal production shows in the base
/// locale AND the literal non-i18n hosts keep rendering (the fallback).
class I18nKeyContract {
  /// The dotted translation key (e.g. `auth.signIn`) — ≥2 segments, each
  /// `[a-z][a-zA-Z0-9_]*`.
  final String key;

  /// The EN anchor literal (e.g. `Sign in`).
  final String anchor;

  const I18nKeyContract({required this.key, required this.anchor});

  /// The accessor expression the generated code emits: `t.auth.signIn`.
  String get accessor => 't.$key';

  /// The ledger surface identity (issue #963): `t.<key>`.
  String get ledgerSurface => 't.$key';

  @override
  String toString() => 'I18nKeyContract($key -> \'$anchor\')';

  // -------------------------------------------------------------------
  // Token grammar: `key: <dotted.key>` optionally `-> '<anchor>'`.
  // -------------------------------------------------------------------

  /// The token prefix. Case-sensitive lowercase, same convention as the
  /// `absent:` scenario marker (issue #964).
  static const String tokenPrefix = 'key:';

  /// A valid dotted key: ≥2 segments, each `[a-z][a-zA-Z0-9_]*`.
  static final RegExp _keyShape = RegExp(
    r'^[a-z][a-zA-Z0-9_]*(?:\.[a-z][a-zA-Z0-9_]*)+$',
  );

  /// The full token shape: prefix + key + optional quoted anchor.
  static final RegExp _tokenShape = RegExp(
    "^$tokenPrefix\\s*([a-zA-Z0-9_.]+)\\s*"
    "(?:->\\s*(['\"])(.*?)\\2\\s*)?\$",
  );

  /// Whether [token] is a `key:` declaration (any grammar quality).
  static bool isKeyToken(String token) =>
      token.trimLeft().startsWith(tokenPrefix);

  /// Parse [token]; null when it is not a `key:` token (plain component
  /// tokens flow through untouched — zero drift for non-i18n hosts).
  static I18nKeyContract? tryParseToken(String token) {
    if (!isKeyToken(token)) return null;
    return parseToken(token);
  }

  /// Parse [token] strictly. A `key:`-prefixed token that fails the
  /// grammar throws [I18nKeyContractParseException] naming the token and
  /// the fix (errors-are-an-API) — never a silent guess.
  static I18nKeyContract parseToken(String token) {
    final raw = token.trim();
    if (!isKeyToken(raw)) {
      throw I18nKeyContractParseException('not a `key:` token: "$token"');
    }
    final m = _tokenShape.firstMatch(raw);
    if (m == null) {
      // Distinguish the two failure shapes for a precise fix line.
      final keyPart = RegExp(
        '^$tokenPrefix\\s*([^\\s-]+)\\s*(.*)\$',
      ).firstMatch(raw);
      final key = keyPart?.group(1) ?? '';
      if (_keyShape.hasMatch(key)) {
        throw I18nKeyContractParseException(
          'malformed i18n key token "$token": the anchor must be a quoted '
          "literal (single or double quotes) after `->`.\n"
          "--> fix: write `key: $key -> 'Your English copy'` "
          '(or drop the anchor to fall back to the key tail).',
        );
      }
      throw I18nKeyContractParseException(
        'malformed i18n key token "$token": the key must be dotted with '
        '≥2 lowerCamel segments (e.g. auth.signIn).\n'
        '--> fix: write `key: feature.surface -> \'Your English copy\'`.',
      );
    }
    final key = m.group(1)!;
    if (!_keyShape.hasMatch(key)) {
      throw I18nKeyContractParseException(
        'malformed i18n key token "$token": the key must be dotted with '
        '≥2 lowerCamel segments, each starting with a lowercase letter '
        '(e.g. auth.signIn).\n'
        "--> fix: write `key: auth.signIn -> 'Your English copy'`.",
      );
    }
    final quoted = m.group(3);
    final anchor = quoted != null && quoted.isNotEmpty
        ? quoted
        : key.split('.').last;
    return I18nKeyContract(key: key, anchor: anchor);
  }
}

/// A malformed `key:` token refused by the contract grammar. The message
/// names the offending row/token and carries the `--> fix:` line.
class I18nKeyContractParseException implements Exception {
  final String message;
  const I18nKeyContractParseException(this.message);

  @override
  String toString() => message;
}

/// The feature's declared i18n surfaces, in declaration order.
class I18nKeyTable {
  /// Use when the feature declares no keys — every i18n branch is inert.
  static const I18nKeyTable empty = I18nKeyTable._(contracts: []);

  final List<I18nKeyContract> contracts;

  const I18nKeyTable._({required this.contracts});

  factory I18nKeyTable.of(List<I18nKeyContract> contracts) =>
      I18nKeyTable._(contracts: List.unmodifiable(contracts));

  bool get isEmpty => contracts.isEmpty;

  bool get isNotEmpty => contracts.isNotEmpty;

  /// Extract from Presentation layer-contract rows (issue #965): `key:`
  /// tokens among a row's declared methods. Domain/Data rows never
  /// contribute. A malformed token throws with the row's interface named;
  /// a key re-declared with a DIFFERENT anchor is a contract conflict.
  factory I18nKeyTable.fromLayerContracts(List<LayerContract> layerContracts) {
    final byKey = <String, I18nKeyContract>{};
    for (final row in layerContracts) {
      if (!row.layer.toLowerCase().contains('presentation')) continue;
      for (final method in row.methods) {
        final I18nKeyContract? contract;
        try {
          contract = I18nKeyContract.tryParseToken(method);
        } on I18nKeyContractParseException catch (error) {
          throw I18nKeyContractParseException(
            '${row.interfaceName}: ${error.message}',
          );
        }
        if (contract == null) continue;
        final existing = byKey[contract.key];
        if (existing != null) {
          if (existing.anchor != contract.anchor) {
            throw I18nKeyContractParseException(
              'i18n key "${contract.key}" is declared twice with conflicting '
              "anchors ('${existing.anchor}' on `${row.interfaceName}`, "
              "'${contract.anchor}' on `${row.interfaceName}`).\n"
              '--> fix: keep one declaration per key in the Presentation '
              'contract.',
            );
          }
          continue;
        }
        byKey[contract.key] = contract;
      }
    }
    return I18nKeyTable._(contracts: byKey.values.toList());
  }

  /// The key declared with [anchor] (exact match), null otherwise.
  String? keyOf(String anchor) {
    for (final contract in contracts) {
      if (contract.anchor == anchor) return contract.key;
    }
    return null;
  }

  /// The contract declared for [key], null otherwise.
  I18nKeyContract? anchorOf(String key) {
    for (final contract in contracts) {
      if (contract.key == key) return contract;
    }
    return null;
  }

  /// Loads the feature's declared key table from its `tdd/test-list.md`
  /// (the single format contract every consumer shares). An unreadable
  /// list yields [I18nKeyTable.empty] — the same fail-open discipline as
  /// the component tokens; a malformed `key:` token THROWS so the caller
  /// refuses before any artifact is written (errors-are-an-API).
  static Future<I18nKeyTable> loadForFeature(String featureDir) async {
    try {
      final contracts = await TestListReader(featureDir).readLayerContracts();
      return I18nKeyTable.fromLayerContracts(contracts);
    } on TestListReadException {
      return I18nKeyTable.empty;
    }
  }

  /// The anchor→key map the test writer consumes.
  Map<String, String> get anchorToKey => {
    for (final contract in contracts) contract.anchor: contract.key,
  };

  /// The keys this table declares.
  List<String> get keys => contracts.map((c) => c.key).toList();

  /// The ledger projection (issue #963): one `t.<key>` row per declared
  /// key, kind `key`. Pass the behavior ids whose generated test asserts
  /// the key as [proversByKey].
  List<DeclaredSurface> toDeclaredSurfaces({
    Map<String, List<String>> proversByKey = const {},
  }) => [
    for (final contract in contracts)
      DeclaredSurface(
        surface: contract.ledgerSurface,
        kind: UiSurfaceKind.key,
        declaredProvers: proversByKey[contract.key] ?? const [],
      ),
  ];
}

/// The `lib/i18n` translation scaffold (issue #965 FR-003): missing
/// declared keys land in the slang source files so the host's `/localize`
/// gate passes mechanically. Existing values are NEVER clobbered.
abstract final class I18nScaffold {
  /// The base locale (the slang convention: `strings.i18n.json`).
  static const String baseLocale = 'en';

  /// The i18n directory relative to the project root.
  static const String i18nDir = 'lib/i18n';

  /// The generated accessor the generated code imports.
  static const String accessorFile = 'strings.g.dart';

  /// The i18n directory INSIDE the package (package URIs are lib-rooted:
  /// `package:<name>/i18n/strings.g.dart`).
  static const String _packageI18nDir = 'i18n';

  /// The base-locale source path for [projectRoot].
  static String baseFilePath(String projectRoot) =>
      p.join(projectRoot, 'lib', 'i18n', 'strings.i18n.json');

  /// The expansion-locale source path for [locale].
  static String expansionFilePath(String projectRoot, String locale) =>
      p.join(projectRoot, 'lib', 'i18n', 'strings_$locale.i18n.json');

  /// The dotted keys folded into a nested JSON map (slang's shape).
  static Map<String, Object> nestedMap(List<I18nKeyContract> contracts) {
    final root = <String, Object>{};
    for (final contract in contracts) {
      var node = root;
      final segments = contract.key.split('.');
      for (var i = 0; i < segments.length - 1; i++) {
        final next = node[segments[i]];
        if (next is Map<String, Object>) {
          node = next;
          continue;
        }
        final fresh = <String, Object>{};
        node[segments[i]] = fresh;
        node = fresh;
      }
      node[segments.last] = contract.anchor;
    }
    return root;
  }

  /// Deterministic JSON: deep-sorted keys, 2-space indent, trailing
  /// newline (VISION §4 — same inputs, same bytes).
  static String renderJson(Map<String, Object> map) {
    Object sortNode(Object node) {
      if (node is Map<String, Object>) {
        final sorted = SplayTreeMap<String, Object>();
        node.forEach((k, v) => sorted[k] = sortNode(v));
        return sorted;
      }
      return node;
    }

    final encoder = JsonEncoder.withIndent('  ', (value) {
      if (value is Map) {
        final sorted = SplayTreeMap<String, Object>();
        value.forEach((k, v) => sorted[k.toString()] = sortNode(v));
        return sorted;
      }
      return value;
    });
    return '${encoder.convert(map)}\n';
  }

  /// Merge [contracts] into the slang source at [filePath]: keys already
  /// present (at any nesting depth) keep their stored value; missing keys
  /// are added with their anchor. Returns true when the file changed.
  /// Creates the file (and its parents) when absent.
  static bool ensure(String filePath, List<I18nKeyContract> contracts) {
    final file = File(filePath);
    final existing = <String, Object>{};
    if (file.existsSync()) {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map) {
        decoded.forEach((k, v) => existing[k.toString()] = v);
      }
    }
    var changed = false;
    for (final contract in contracts) {
      if (_containsKey(existing, contract.key)) continue;
      _placeKey(existing, contract.key, contract.anchor);
      changed = true;
    }
    if (!changed && file.existsSync()) return false;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(renderJson(existing));
    return true;
  }

  /// Whether the dotted [key] already exists in the nested [node].
  static bool _containsKey(Map<String, Object> node, String key) {
    var cursor = node;
    final segments = key.split('.');
    for (var i = 0; i < segments.length; i++) {
      final next = cursor[segments[i]];
      if (i == segments.length - 1) return next != null;
      if (next is Map) {
        cursor = next.cast<String, Object>();
        continue;
      }
      return false;
    }
    return false;
  }

  static void _placeKey(Map<String, Object> node, String key, String anchor) {
    final segments = key.split('.');
    var cursor = node;
    for (var i = 0; i < segments.length - 1; i++) {
      final next = cursor[segments[i]];
      // jsonDecode yields Map<String, dynamic> — never assume the type
      // arguments; cast-view and write through so sibling subtrees
      // (pre-existing translations) survive the merge untouched.
      if (next is Map) {
        cursor = next.cast<String, Object>();
        continue;
      }
      final fresh = <String, Object>{};
      cursor[segments[i]] = fresh;
      cursor = fresh;
    }
    cursor[segments.last] = anchor;
  }

  /// The host accessor import URI for generated code: the package URI
  /// derived from the project's pubspec name when readable, else a
  /// relative fallback from [fromDir] to `lib/i18n/strings.g.dart`.
  /// [relativeFallback] receives the from-dir so subject (lib/**) and
  /// test (test/**) files both resolve.
  static String accessorImport({
    required String projectRoot,
    required String fromDir,
  }) {
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      try {
        final doc = loadYaml(pubspec.readAsStringSync());
        if (doc is YamlMap && doc['name'] is String) {
          final name = doc['name'] as String;
          if (name.isNotEmpty) {
            return 'package:$name/$_packageI18nDir/$accessorFile';
          }
        }
      } on YamlException {
        // fall through to the relative fallback
      }
    }
    return p
        .relative(
          p.join(projectRoot, 'lib', 'i18n', accessorFile),
          from: fromDir,
        )
        .replaceAll('\\', '/');
  }
}
