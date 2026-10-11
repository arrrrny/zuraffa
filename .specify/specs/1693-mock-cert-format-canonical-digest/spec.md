# 1693-mock-cert-format-canonical-digest

- **Spec ID**: 1693-mock-cert-format-canonical-digest
- **Created**: 2026-09-18
- **Source**: GitHub issue #1693 (mock cert goes stale on format-only drift — phase-2 refactor formats the entity source after certification, forcing a 2nd sandbox cert per entity)
- **Type**: certification-gate fix (P1 — every entity pays at least TWO full sandbox certifications, 2–17 min each under Flutter; at zik_zak scale (145 entities) this is hours of pure re-certification)
- **Branch**: fix/1693-mock-cert-format-canonical-digest
- **Related**: spec 1110 (the certification registry gate this fix corrects), spec 1001 (the `mock-cert.<Entity>.json` receipt), spec 1652 (the phase-2b batch refactor whose `dart format lib/` pass triggers the drift)

## Problem

The spec-1110 mock cert gate digests (freshness-checks) the raw bytes /
mtime of the entity source (`lib/src/domain/entities/<e>/<e>.dart`). The
tdd loop's phase-2 batch refactor (`format + analyze + re-proof`, spec
1652) runs `dart format` over the tree AFTER the certification that
happened mid-lane — so the first lane completion after any
`mock create --certify` reformats the entity source and the next
`zfa tdd run` refuses:

```
zfa tdd run: CORE entity "UserSession" has a mock on disk that is NOT certified
--> fix: zfa mock certify UserSession (or zfa mock create UserSession --certify), then re-run.
```

The refusal receipt (`specs/<f>/tdd/engine.gate.<Entity>.refused.json`)
records the stale reason. The only change is `dart format`
normalization (mtime moves, bytes are format-canonical); the zorphy
parts it `part`s are untouched.

### Root cause

1. `mock-cert.<Entity>.json` freshness is read against the entity
   source's raw drift: the spec-1110 registry
   (`cert_registry.dart`) declares the receipt stale when the entity
   file's mtime postdates the receipt's.
2. The phase-2b batch refactor (spec 1652) formats `lib/` as part of
   "clean (phase 2)" — including entity sources certified earlier in the
   SAME feature's lifecycle.
3. The gate therefore reads format-only drift as staleness. On the
   cert-recording side the receipt pins only the contract test's digest
   (`contract_digest`) — it records nothing about the entity source it
   certifies, so the gate has no format-canonical basis to compare.

## Suggested fix (chosen: option 1 — format-canonical digest)

Digest the entity source in FORMAT-CANONICAL form: the certifier records
an `entity_digest` (SHA-256 over `dart format` output, computed
in-process via the already-pinned `dart_style` engine) at certification
time, and the gate compares the recorded digest against the canonical
form of the CURRENT entity source bytes. Format-only drift canonicalizes
to the same bytes → fresh. A real semantic edit changes the canonical
bytes → stale. Receipts predating the field keep the mtime comparison.

## Hard constraints

- Fix ONLY the digest/format interaction; do NOT weaken the spec-1110
  staleness gate for real semantic drift; one PR per spec.
- The fix must:
  1. make format-only drift not register as staleness;
  2. still detect real entity source changes;
  3. not require a second certification per entity;
  4. work under Flutter sandbox certification (the digest is computed
     from the entity source bytes by the driving zfa process — no
     toolchain subprocess is added to the cert path).

## Success criteria

- SC-1: certify an entity, rewrite its source with `dart format`-only
  drift (mtime after the receipt) → the gate reads `certified`; no
  second certification is requested.
- SC-2: a real entity source edit after certification (different AST)
  still refuses as `stale` with the exact cert command.
- SC-3: pre-1693 receipts (no `entity_digest`) keep the mtime freshness
  semantics byte-for-byte — no behavior change for old receipts.
- SC-4: the certifier records the format-canonical entity digest in
  `mock-cert.<Entity>.json` for both entry points
  (`zfa mock create <E> --certify` and `zfa mock certify <E>`), and the
  JSON omits the field for receipts without one (legacy byte stability).
- SC-5: the existing spec-1110/1001 suites stay green unmodified
  (except where they pin the new field's absence); `dart analyze` clean
  on the touched files; `dart format` no diffs.
