# Bug Assessment — #1951

**Issue:** `zfa mock create <Enum>` (with or without `--certify`) is
unsatisfiable — the #1894 absent-interface refusal fires **before** the
fixture-only classification, so the #1887/#1037/#1747 enum short-circuit is
unreachable on the generation path.
**Severity:** high — every enum entity exits 1 after its fixture is already
written; the documented `--certify` route (and the headless route, since
`certify()` runs for every non-dry-run generation) cannot be used for any
enum.
**Source:** https://github.com/arrrrny/zuraffa/issues/1951
**Related:** #1887 (fixture-only certified-with-nothing), #1894 (absent
declared interface/mock is a refusal), #1037/#1747 (enums / CRUD-less types
skip the CRUD datasource surface)

## Root cause — refusal ordering in `MockCertificationService.certify`

1. `certify()` defaults `requireInterface = true` and resolves
   `requireInterfaceFile`/`requireMockFile` up front.
2. Step 2 resolves the default (non-service) seam for **every** entity —
   including enums — deriving a non-null `interfacePath` of the shape
   `data/datasources/<entity_snake>/<entity_snake>_datasource.dart`.
3. When that file is absent (it always is for an enum — the generator
   deliberately never emits the CRUD surface) and the flag is set, it throws
   the #1894 `StateError`.
4. `fixtureOnly` — which already knows about enums — was only computed at
   the very end, when building the returned `MockCertification`. The
   short-circuit could never prevent the refusal.

`mock_command.dart`'s `_runMockGeneration` calls `certify()` unconditionally
inside `if (!dryRun)` and turns the `StateError` into exit 1 — so even plain
`zfa mock create SubscriptionTier` (no `--certify`) fails the same way
(issue escalation, 2026-10-20).

## Remediation (hard constraints)

Compute the fixture-only classification **before** the absence refusals and
gate BOTH flags on `!fixtureOnly`; pass the precomputed classification into
the returned `MockCertification` instead of recomputing it. Do NOT weaken
the #1894 refusal for real CRUD entities (a real entity with a missing
declared interface must keep refusing).

`mock verify <Enum>` needs the same outcome on its own path: its pre-flight
missing-file refusals fire before `certify()` is reached, so it reports the
fixture-only green directly (refusing honestly when not even the mock data
exists).

## Repro (from issue, confirmed on this tree pre-fix)

```sh
zfa mock create SubscriptionTier
# ℹ️  SubscriptionTier is an enum entity — mock data generated; skipping the
#    CRUD datasource/provider surface (issue #1037).
# zfa mock create: cannot certify SubscriptionTier — the declared interface
#   lib/src/data/datasources/subscription_tier/subscription_tier_datasource.dart
#   does not exist.
echo $?   # 1 — expected 0
```
