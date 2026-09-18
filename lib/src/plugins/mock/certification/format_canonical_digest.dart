/// The format-canonical entity source digest (spec 1693, issue #1693):
/// SHA-256 over `dart format` output.
///
/// The spec-1110 cert gate declared a mock certification stale whenever
/// the entity source's raw drift postdated the receipt — so the tdd
/// loop's phase-2 batch refactor (`dart format lib/`, spec 1652) forced
/// a second full sandbox certification per entity (2–17 min under
/// Flutter; hours at zik_zak's 145-entity scale). Recording a
/// FORMAT-CANONICAL digest fixes that class of drift without weakening
/// the gate: any two sources that `dart format` normalizes to the same
/// bytes hash equal, and a real semantic edit (a different AST) hashes
/// differently.
///
/// The canonical form is computed IN-PROCESS with the `dart_style`
/// engine (already a direct dependency) — no toolchain subprocess is
/// added to the cert or gate path, so the digest works identically
/// under the Flutter sandbox certification. Both sides of the contract
/// (the certifier that records the digest and the gate that compares
/// it) run through THIS helper, so the basis is shared by construction.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_style/dart_style.dart';

/// The formatter every canonical digest runs through — the same engine,
/// page width, and trailing-comma policy `dart format` defaults to.
final DartFormatter _formatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);

/// The probe [canonicalizerId] fingerprints the running formatter with.
/// It has to be valid at every language version the formatter supports
/// and wide enough to exercise the surfaces a patch-level `dart_style`
/// bump has changed before: a class with fields and a constructor, an
/// enum's value list, and a collection literal.
const _canonicalizerProbe = '''
class Probe {
  final String alpha;
  final String beta;
  const Probe({required this.alpha, required this.beta});
  List<String> get items => [alpha, beta];
}

enum ProbeEnum { alpha, beta, gamma }
''';

/// The identity of the canonicalizer the digests are computed with,
/// recorded next to every digest (spec 1693 follow-up, issue #1693).
///
/// The canonical form IS the resolved `dart_style` engine's byte
/// output, and `pubspec.yaml` asks for `^3.1.13`, so each consumer
/// resolves its own patch level — one that changes what the formatter
/// emits. The language version does not track that: 3.1.10 pinned
/// `DartFormatter.latestLanguageVersion` at 3.13.0 and 3.1.11–3.1.13
/// kept changing the output anyway (3.1.13's enum trailing comma,
/// #1888, is explicitly "not language versioned"). A version string
/// alone would therefore leave the receipt digest silently coupled to
/// an engine it cannot name, and one `dart pub upgrade` would flip
/// every receipt in the project `stale` at once.
///
/// So the id carries a fingerprint of the running formatter's output on
/// a fixed probe: two runs produce the same id iff their bytes match.
/// The cert gate trusts a recorded digest only when the receipt's
/// recorded id equals this one — a different engine takes the pre-1693
/// mtime leg instead of a project-wide re-certification.
final String canonicalizerId =
    'dart_style/${DartFormatter.latestLanguageVersion}/'
    '${sha256.convert(utf8.encode(_formatter.format(_canonicalizerProbe)))}';

/// SHA-256 of the format-canonical form of [source]; null when [source]
/// cannot be canonicalized. Callers decide what that means — the cert
/// gate reads it as drift, because it cannot be what was certified, and
/// a legacy receipt falls back to its mtime leg.
///
/// The failure is TOTAL on purpose: `DartFormatter.format` throws more
/// than [FormatterException] on legal input (3.1.13's changelog records
/// a crash on an enum with a primary constructor, #1885), and a
/// freshness verdict must never turn into an exception out of the
/// preflight — the operator would get a formatter stack trace where the
/// gate promises a `certified`/`stale` verdict and its fix command.
String? formatCanonicalDigest(String source) {
  try {
    final formatted = _formatter.format(source);
    return sha256.convert(utf8.encode(formatted)).toString();
  } catch (_) {
    return null;
  }
}

/// [formatCanonicalDigest] over the bytes of [file]; null when [file] is
/// null (the entity was not found) or cannot be read (or its content
/// cannot be canonicalized).
String? formatCanonicalDigestOfFile(File? file) {
  if (file == null) return null;
  String source;
  try {
    source = file.readAsStringSync();
  } catch (_) {
    return null;
  }
  return formatCanonicalDigest(source);
}
