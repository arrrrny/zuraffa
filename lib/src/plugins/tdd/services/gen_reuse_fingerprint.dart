/// Gen's reuse fingerprint (issue #1388): the routing-state digest that
/// gates `zfa tdd gen`'s reuse decision.
///
/// The registry reuse decision (`ArtifactRegistry.preflight`) reuses a
/// prior record purely on behavior-id + paths + file existence; the
/// #1320 staleness re-render only fires when the CURRENT render differs
/// byte-wise — i.e. only when a declared SIGNATURE now resolves. A
/// declared-routing change that does not alter the rendered bytes (the
/// traces cell gaining a no-signature contract row — the exact
/// 004-login-ui `adaptive_layouts` shape of issue #1388) left the pair
/// `verdict=reused` and guard-only, defeating the recovery loop the
/// vacuous-guard stop itself prescribes (add traces → re-plan → re-gen,
/// issues #1259/#1308).
///
/// The fingerprint makes the routing state COMPARABLE: sha256 over the
/// resolved lane-plan traces cell (the row `TestListReader` resolves —
/// `04-ENGINE.md`/`04-SKIN.md` when the list is a lane meta-index, else
/// `tdd/test-list.md`) plus the spec's declared-ROUTING surface — the
/// Layer Contracts section (`SpecParser.layerContractsSection`), not the
/// whole `spec.md`. Gen persists it on every created/regenerated record
/// (`ArtifactRecord.genFingerprint`) and gates the reuse path: a stored
/// fingerprint that differs from the current one invalidates the reuse
/// (forced regeneration, or a refusal naming `zfa tdd reset` when the
/// pair cannot be auto-regenerated).
///
/// The spec component is the routing surface and nothing else (issue
/// #1388 review): hashing the whole file made every documentation-only
/// edit — a typo fix, a comment, reworded acceptance prose — diverge the
/// digest for every record in the feature, so gen called a prose edit
/// "a declared-routing change" and, on a pair it cannot regenerate, hard
/// failed with a remedy (`zfa tdd reset`) that deletes the
/// implementation. The declarations a `traces:` cell resolves against
/// live in the Layer Contracts section; a `traces:` edit reaches gen
/// only through the re-planned cell, which is the traces component.
///
/// Pure: `compute` hashes strings; `forFeature` adds the one spec.md
/// read the caller would otherwise duplicate. Absent spec.md is the
/// empty component — deterministic, never an exception (fail-open, the
/// [DeclaredRouting] convention for unreadable routing sources).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import 'spec_parser.dart';

/// Version tag of the fingerprint composition. Bumping it invalidates
/// every stored fingerprint at once (one benign re-generation per pair
/// after an upgrade of the composition itself). `v2` narrows the spec
/// component from the whole `spec.md` to its declared-routing surface.
const String genReuseFingerprintVersion = 'v2';

/// The gen reuse fingerprint digest (issue #1388).
class GenReuseFingerprint {
  const GenReuseFingerprint._();

  /// sha256 hex over a version-delimited concatenation of the resolved
  /// lane-plan traces cell and the spec's declared-routing surface
  /// [routingSurface]. The NUL delimiters keep the component boundaries
  /// unambiguous (no concatenation ambiguity between a traces cell and a
  /// routing surface whose bytes happen to join into the other's shape).
  static String compute({
    required String tracesCell,
    required String routingSurface,
  }) {
    final input = utf8.encode(
      '$genReuseFingerprintVersion\x00traces\x00$tracesCell'
      '\x00routing\x00$routingSurface',
    );
    return crypto.sha256.convert(input).toString();
  }

  /// The current fingerprint for the behavior row [tracesCell] resolved
  /// from [featureDir]: reads the feature's `spec.md` (missing or
  /// unreadable → the empty component), narrows it to the Layer
  /// Contracts section, and delegates to [compute].
  static String forFeature({
    required String featureDir,
    required String tracesCell,
  }) {
    var specMd = '';
    try {
      final file = File(p.join(featureDir, 'spec.md'));
      if (file.existsSync()) specMd = file.readAsStringSync();
    } on FileSystemException {
      specMd = ''; // unreadable spec: deterministic empty component
    }
    final routingSurface = specMd.isEmpty
        ? ''
        : const SpecParser().layerContractsSection(specMd);
    return compute(tracesCell: tracesCell, routingSurface: routingSurface);
  }
}
