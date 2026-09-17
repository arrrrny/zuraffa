# Plan — 1693-mock-cert-format-canonical-digest

- **Branch**: fix/1693-mock-cert-format-canonical-digest
- **Chosen remediation**: spec §Suggested fix option 1 — the mock cert
  digest becomes format-canonical (record + compare a `dart format`
  digest of the entity source), leaving the phase-2 refactor and the
  gate's semantic-drift semantics untouched.

## Surfaces (all under `lib/src/plugins/mock/certification/`)

1. **NEW `format_canonical_digest.dart`** — one seam, both sides share it:
   `formatCanonicalDigest(String source)` → SHA-256 over
   `DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
   .format(source)`; null when the source does not parse
   (`FormatterException`). Plus the file-bytes variant. In-process
   `dart_style` (already a direct dependency) — no toolchain subprocess
   added to cert or gate (constraint 4), deterministic across the cert
   and gate sides because the SAME driving zfa runs both.

2. **`mock_cert_receipt.dart`** — `MockCertReceipt` gains an optional
   `entityDigest` (JSON `entity_digest`):
   - constructor field + `fromJson` parse;
   - `toJson` emits the key ONLY when non-null — pre-1693 receipts stay
     byte-stable (SC-4);
   - `fromRun` accepts `String? entityDigest` and records it.

3. **`mock_certifier.dart`** — `MockCertifier.certify` reads the entity
   source at the canonical path (`CertRegistry.entityFileRel`) and
   records `formatCanonicalDigestOfFile(...)` on the receipt built by
   `fromRun`. Missing entity file → no digest (legacy mtime semantics;
   honest absence). Both entry points flow through `certify`, so
   `mock create --certify` and `mock certify` are covered by one change.

4. **`cert_registry.dart`** — the spec-1110 freshness leg becomes
   digest-first:
   - receipt records an `entity_digest` → stale iff the CURRENT
     canonical digest differs (unparseable current source counts as
     drift — it cannot be what was certified). Format-only drift →
     same canonical bytes → fresh (SC-1); real edit → stale (SC-2).
   - receipt WITHOUT `entity_digest` (pre-1693) → the existing mtime
     comparison, unchanged (SC-3).
   - library docs updated to the digest-first semantics.

## Why not the other options

- Option 2 (certifier formats the entity file before digesting) mutates
  the consumer's tree from a cert command and still leaves the GATE
  reading raw bytes — every later `dart format` by the user (IDE save,
  phase-2) would re-break. Option 3 (phase-2 skips certified surfaces)
  couples the refactor pass registry to mock-cert bookkeeping and needs
  a format-preserving formatter pass — a second machinery change.
  Option 1 is the only one where BOTH sides share one canonical basis.

## Test plan (TDD, `test/plugins/mock/certification/
spec_1693_format_canonical_digest_test.dart`)

Red first, against the pre-fix tree:

| id | kind | claim |
| -- | ---- | ----- |
| G1 | gate | format-only drift + mtime after receipt → `certified` (the bug: pre-fix reads `stale`) |
| G2 | gate | real semantic edit + mtime after receipt → `stale`, exact fix command |
| G3 | gate | unparseable entity source + recorded digest → `stale` (drift it cannot be exempted) |
| G4 | gate | legacy receipt without digest keeps mtime freshness both directions |
| G5 | gate | digest overrides a lying-fresh mtime: receipt mtime after entity, digest mismatched → `stale` |
| G6 | receipt | `entity_digest` roundtrips; JSON omits it when absent |
| G7 | receipt | `fromRun` records the digest when given, omits when null |
| G8 | certifier | `certify()` (stub sandbox, no subprocess) records the canonical digest of the entity source; written receipt carries `entity_digest` |

Guard pins (pre-existing suites that must stay green, unmodified):
`test/plugins/mock/cert_registry_test.dart` (spec 1110),
`test/plugins/mock/certification/mock_cert_registry_test.dart`,
`test/plugins/mock/certification/mock_cert_receipt_test.dart` (spec 1001),
`test/engine/mock_certifier_test.dart`.

## Verification budget

- `dart analyze` on touched files: clean.
- New suite + guard suites: all pass.
- `dart format .`: zero remaining diffs.
- Semantic-drift case re-run explicitly (spec §4 step 5): still refuses.
