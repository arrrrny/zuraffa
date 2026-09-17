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

/// SHA-256 of the format-canonical form of [source]; null when [source]
/// does not parse. A source that cannot parse cannot be canonicalized —
/// callers decide what that means (the cert gate reads it as drift,
/// because it cannot be what was certified).
String? formatCanonicalDigest(String source) {
  try {
    final formatted = _formatter.format(source);
    return sha256.convert(utf8.encode(formatted)).toString();
  } on FormatterException {
    return null;
  }
}

/// [formatCanonicalDigest] over the bytes of [file]; null when the file
/// cannot be read (or its content does not parse).
String? formatCanonicalDigestOfFile(File file) {
  String source;
  try {
    source = file.readAsStringSync();
  } catch (_) {
    return null;
  }
  return formatCanonicalDigest(source);
}
