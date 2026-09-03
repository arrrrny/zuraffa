# Bug Issue: Treaty + error API unification: manifest --verify, exit protocol, --json/--stream everywhere

- **Slug**: treaty-error-api
- **Fetched**: 2026-09-03
- **Issue**: 917
- **URL**: https://github.com/arrrrny/zuraffa/issues/917
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

"Part of #908. Absorbs: #776 (manifest --verify), #778 (exit codes + --format json), #838 (--json/--stream), #839 (exit protocol 0/1/2/3/4), and the live drift evidence from #904 (manifest-declared flags CLI rejects: 'feature scaffold --use-mock', 'mock json --outputDir') + #876 (needs-reproducer note: silent parent-option inertness).

## Required

1. 'zfa manifest --verify' conformance gate in CI: manifest inputSchemas ↔ CLI flags ↔ help text; drift = exit 3. The #904 sites are the seed fixture list.
2. Exit protocol ratified (0/1/2/3/4) with a golden table asserted in CI; legacy 64/255/-9 paths mapped or removed.
3. --json on every tdd/corpus command; 'tdd run --stream' NDJSON per-step verdicts (schema_versioned).
4. Every non-zero exit ends with a machine-actionable 'fix:' line.

This is VISION §3+§4 made mechanical."

## Comments

None.
