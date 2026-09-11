**Template Version**: `zuraffa-1.0`

# Spec: 1400-restore-verify-deps-example

GitHub issue: arrrrny/zuraffa#1400 (verify-misfire / spec-drift + missing
dependency; VERIFY misfire from EPIC #1133, exit criterion 3)

## Summary

The EPIC #1133 verify run could not reproduce the committed
`example/specs/004-login-ui/tdd/verification.md` mutation evidence at
HEAD: the master merge (f5fb5355) had dropped `mutation_test`,
`coverage`, and `test` from `example/pubspec.yaml` dev_dependencies while
the committed evidence continued to depend on them — the audit died with
`Could not find package 'mutation_test'` (`gate: not_assessed`,
`mutation_was_run: false`).

Since the issue was filed, the dependency half was repaired on master in
two hops: #1369 restored the TDD baseline into the shipped example tree,
and #1370 superseded the plain `test` pin (NO published `test` version
resolves in this Flutter consumer graph — the graphql →
web_socket_channel ^3.0.1 conflict class documented in #1189) while the
gen side emits `package:flutter_test` imports on Flutter hosts (#1351).
This spec CERTIFIES the repaired state with a real reproduction: the
committed evidence's mutation audit is re-run on its exact scope against
the restored tree, and the dependency contract is re-pinned so a future
merge cannot silently drop it again.

## Locked decisions

1. The audit-critical pair stays: `mutation_test: ^1.8.0` and
   `coverage: ^1.15.1` remain declared in `example/pubspec.yaml`
   dev_dependencies at the writer-canonical constraints (restored by
   #1369, guarded by the #1369/#1370 structural pin, re-certified here by
   a real mutation run).
2. Plain `test` is NOT restored. #1370 superseded the #1369 pin; this
   spec re-proves the supersession empirically on Flutter 3.47.3 /
   Dart 3.13.3: adding `test: ^1.0.0` to `example/pubspec.yaml` makes
   version solving FAIL (`flutter_test from sdk is incompatible with
   test >=0.12.0-beta.3` — full solver transcript in
   [plan.md](./plan.md)). Restoring it would break resolution, the
   flutter-smoke-gate, and with them the very audit this issue asks to
   make reproducible. The issue's own suggested fix scopes the `test`
   clause as "if the audit needs them" — the audit demonstrably does not
   (the evidence scope's gen'd tests import flutter_test per #1351).
3. The committed evidence is reproduced on its EXACT scope. The evidence
   commit (fb44db98) registers 6 subjects / 6 tests for feature
   004-login-ui; that audit surface is byte-identical at HEAD, proven by
   recomputing the evidence's recorded sha256 bindings — all 6
   `subject_hash` values match, and the only lib/ delta since the
   evidence is `u1_subject.dart` (added AFTER the evidence by #1377 and
   outside the evidence's scope; #1377 also appended the `U1` record to
   the registry, which is why `spec_hash` alone differs — see the binding
   table in [tdd/verification.md](./tdd/verification.md)). The
   reproduction run must therefore match the committed numbers
   bit-exactly: killed=48, survived=8, mutation_score=0.8571,
   mutation_was_run=true.
4. The full-lane `zfa tdd verify` gate at HEAD stops at
   `preflight_red` via `test/tdd/004-login-ui/u1_test.dart`
   (`UnimplementedError: subject_u1 not implemented`) — the deliberate
   honest-red stub #1377 shipped when it migrated FR-001 to the
   `traces:` grammar. That is an unrelated pre-existing red owned by the
   U1 implementation lane: implementing `subject_u1` is a source-code
   change, forbidden here by the issue's hard constraint (fix ONLY
   `example/pubspec.yaml`). Recorded as the residual blocker; NOT taken
   in this spec.
5. CI guard (issue AC-3, optional): already satisfied by existing
   surfaces — the #1369/#1370 structural pin
   (`test/package_sdk/bug_1369_example_tdd_baseline_test.dart`) runs in
   CI's `dart test test` lane and fails if a future merge drops the
   audit-critical pair or reintroduces plain `test`;
   `tools/flutter_smoke_gate.sh` (job `flutter_consumer_smoke`)
   re-proves example resolution on every run. No new CI surface.

## Functional requirements

- **FR-1**: `example/pubspec.yaml` dev_dependencies declare
  `mutation_test: ^1.8.0` and `coverage: ^1.15.1` (the writers-canonical
  TDD pair `PubspecDevDependenciesPatcher.flutterDevDependencies`
  prescribes).
- **FR-2**: `example/pubspec.yaml` declares NO plain `test` (the
  unresolvable pin stays out of Flutter consumers, #1370).
- **FR-3**: the committed `verification.md` mutation evidence
  (killed=48, survived=8, score 0.8571) is reproducible at HEAD by
  running the scoped mutation audit on the committed evidence scope
  against the restored dependency tree (`mutation_was_run: true`, exit
  0, real per-mutant report).
- **FR-4**: the shipped baseline documents its #1400 certification in
  the dev_dependencies comment block (data-only change, house style of
  the #1369/#1370 comment chain).

## Acceptance scenarios

1. Loading the shipped pubspec shows the writer-canonical TDD pair at
   the canonical constraints and no plain `test` (B1, B2 — guarded by
   the existing structural pin).
2. `flutter pub get` in `example/` resolves clean (SC-001 — re-proven
   locally; CI re-proves per run).
3. The scoped mutation audit reproduces the committed evidence on the
   restored tree (B3 — real run recorded in
   [tdd/verification.md](./tdd/verification.md)).

## Success criteria

- **SC-001**: `flutter pub get` in `example/` resolves with the
  restored baseline and zero dependency_overrides (CI's
  flutter-smoke-gate re-proves on every run).
- **SC-002**: the committed evidence's mutation audit reproduces at
  HEAD: `mutation_was_run: true`, killed=48, survived=8,
  mutation_score=0.8571, `restoration_verified: true`-class state after
  the run (subjects byte-identical to the committed tree).
- **SC-003**: the structural pin + package_sdk suite stay green;
  analyze + format clean on the changed surface.

## Assumptions

- The U1 honest-red stub (#1377) keeps the FULL verify gate red until
  the U1 lane implements `subject_u1`; this spec's reproduction is
  scoped to the committed evidence's registered surface, which is the
  evidence the issue asks to make reproducible.
- Flutter 3.47.3 / Dart 3.13.3 is the resolution-of-record toolchain
  (matches CI's subosito/flutter-action stable channel).
