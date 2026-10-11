# Spec 1312 — fix: receipt preflight absolutizes nothing — relativize audited paths against projectRoot; mutation audit passable again

GitHub issue: arrrrny/zuraffa#1312 (severity high — the mutation audit gate
is structurally unpassable on any project that ships receipts)

## Problem

On a feature driven green by the sanctioned `zfa tdd run`,
`zfa tdd verify --feature <f>` fails its receipt preflight with
`missing_receipt` for EVERY audited subject — even when
`zfa proof check` passes with 0 findings on the very same files.
Spec 044 FR-012..023 (the mutation gate) is unreachable on any project
that ships receipts.

Repro:

```
zfa tdd run <feature>          # green, receipts written
zfa proof check                # OK — 0 findings, subjects verified
zfa tdd verify --feature <feature>
→ [missing_receipt] .../u1_subject.dart — no receipt covers this subject
   (for all subjects, while grep shows covering receipts)
```

Root cause — a path-shape mismatch between the two stores:

- `specs/<f>/tdd/artifacts.json` records `subject_path` ABSOLUTE
  (`gen_command.dart` builds it as `'$cwd/lib/tdd/<feature>/..._subject.dart'`),
  e.g. `/Users/arrrrny/Developer/todo_planner/lib/tdd/todo_planner/u1_subject.dart`.
- `.zfa/receipts/*.json` records `files[].path` PROJECT-RELATIVE
  (`lib/tdd/todo_planner/u1_subject.dart`).
- `ReceiptPreflight.check` does `covered.contains(_normalize(subject))`
  where `_normalize` only runs `p.normalize` + backslash replacement —
  it never relativizes the audited path against `projectRoot`.
  An absolute path can never intersect a relative one: every audited
  subject is reported `missing_receipt`, every time.

## Deliverables

1. **Path normalization in `ReceiptPreflight`** — `_normalize` (or the
   `check` call site) in
   `lib/src/plugins/tdd/services/receipt_preflight.dart` MUST
   relativize each audited path against `projectRoot` before the
   membership test against receipt file paths. Already-relative paths
   pass through unchanged (idempotent). Backslash separators are still
   canonicalized to `/`.
2. **Out-of-root subjects are skipped, not missing.** An audited path
   that lies OUTSIDE `projectRoot` (relativization yields `..`-prefixed
   segments) is not an auditable subject of this project: it produces
   NO `missing_receipt` finding.
3. **Existing registries fixed at compare time.** No writer, engine,
   or registry change: `artifacts.json` files already on disk with
   absolute `subject_path` entries are handled by the preflight's
   compare-time relativization — no `zfa tdd gen` / `zfa tdd plan`
   re-run required.
4. **Backward compatibility.** Registries that already record
   project-relative `subject_path` (and every existing fixture and
   test that passes relative audited paths) keep working unchanged.
5. **Scope fence.** Only `ReceiptPreflight.check` / `_normalize` change
   in lib/ — the core engine cycle, the artifact registry writer, the
   proof check algorithm, and the verify audit semantics are untouched.

## Success criteria (measurable)

- **SC-1** — After `zfa tdd run` goes green, the receipt preflight in
  `zfa tdd verify --feature <f>` reports ZERO `missing_receipt`
  findings for subjects that `zfa proof check` already verifies.
  Proven by the CLI-tier test: `artifacts.json` with an ABSOLUTE
  `subject_path` + a receipt covering the same file →
  `receipt preflight: ok`, no `missing_receipt` in output.
- **SC-2** — Unit: an audited ABSOLUTE path inside the project root
  whose project-relative form is covered by a receipt → `report.ok`
  true, `gateActive` true, zero findings.
- **SC-3** — Unit: an audited path OUTSIDE the project root → skipped:
  no `missing_receipt` finding, report stays ok (with valid receipts).
- **SC-4** — Unit: a mixed list (absolute-inside-root + relative +
  absolute-outside-root) → only real, uncovered subjects produce
  findings; covered-in-root and out-of-root entries never do.
- **SC-5** — Backward compat: relative `subject_path` in
  `artifacts.json` + covered receipt → preflight passes (existing
  CLI test 'green receipt gate lets the audit proceed' stays green,
  unmodified).
- **SC-6** — The gate still fails closed: a genuinely uncovered
  subject (relative OR absolute-in-root) still yields `missing_receipt`
  with the SAME finding `path` shape as today
  (`lib/tdd/b_001_subject.dart`), and the audit never starts.
- **SC-7** — `dart analyze` clean on every changed file;
  `dart format .` produces zero diffs.

## Constraints

- Fix lives ONLY in `ReceiptPreflight.check` / `_normalize` in
  `lib/src/plugins/tdd/services/receipt_preflight.dart` (+ its test
  file). No dependency, engine, writer, or audit-semantics changes.
- No re-generation of existing registries: the fix must work against
  `artifacts.json` files written by older versions.
- One PR per issue; commits follow Conventional Commits
  (`fix(1312):`).
