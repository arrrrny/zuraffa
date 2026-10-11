# Spec 1105 — one canonical `--json` envelope: `zuraffa.verdict.v1`

Source: GitHub issue #1105 ([CONTRACT]).

## Mission

The A+ sweep landed `--json` envelopes on most generator commands, but
the envelope shapes drifted — `schema:1` integers, `"verdict.v1"`
strings, `cache.verify.v1` / `route.v1` / `repository-contract.v1`
ad-hoc. Agents must hand-roll a parser per command. Fix this: one
versioned envelope schema, one parser, every `--json` command emits it.

## Orders

1. Define the canonical envelope in `lib/src/core/verdict_envelope.dart`
   with the frame
   `{schema: "zuraffa.verdict.v1", command, verdict, exit_class,
   subject, artifacts, receipts, findings, drifts, details, timestamp}`.
   `details` is the only plugin-specific surface.
2. Migrate every `--json` emitter: `tdd` (schema string only), `mock`
   create, `route` create + verify, `cache` verify, `state` create,
   `usecase` create. New emitters enforced by a codebase-scan test.
3. Ship the Dart parser `VerdictEnvelope.fromJson(json)` with a
   schema-version check that throws on unknown schema.
4. MCP server adopts it at the tool-call boundary
   (`structuredContent`).

## Constraints

- `VerdictEnvelope` is the only envelope type in `lib/src/core/`.
- `tdd`'s existing `VerdictEnvelope` keeps its class name; only the
  `schema` field string changes (the `details` field already exists).
- Backwards compatibility: old parsers break loudly (schema mismatch
  throws), never silently.
- All migration tests use the new schema name.

## Acceptance

- One canonical envelope: `zuraffa.verdict.v1`; the literal greps only
  in core + emitters.
- Every `--json` command emits `VerdictEnvelope` (scan test).
- `VerdictEnvelope.fromJson` parses every emitter's output
  (round-trip).
- MCP tools returning a verdict return it as `structuredContent`.
