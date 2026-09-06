# Feature Specification: i18n-keyed widget contracts — tdd view emits slang keys, test shell resolves them (EPIC 2: TDD Loop Completeness)

**Issue:** [#1141](https://github.com/arrrrny/zuraffa/issues/1141) · **Part of:** #1133 (EPIC 2: TDD Loop Completeness) · **Extends:** #965 (closed — the machinery) · **References:** #834 (closed — slang in the TDD loop), #962 (plug-in merge, blocked), #963 (UI coverage ledger)

## Summary

#965 landed the keyed-widget-contract **machinery**: the `I18nKeyContract` grammar, `zfa tdd view` emitting `Text(t.auth.signIn)` for anchored literals, the slang test shell (`LocaleSettings.setLocaleRaw('en')` before the pump), the ledger library functions (`toDeclaredSurfaces`, `untracedHardcodedStrings`), and the expansion tier. Three pieces never got **wired**, and the acceptance fixture (004-login-ui) never declared a keyed contract — so a machine-generated view still cannot prove it passes a 100% localization hard gate:

1. The ledger is derived nowhere: `UiLedgerBuilder` and `untracedHardcodedStrings` are library functions with no command producing `specs/<f>/tdd/ui-ledger.md` and no command enforcing the untraced-surface rule (075's outstanding T002).
2. `zfa build` never runs slang codegen: generation scaffolds `lib/i18n/strings.i18n.json` sources, but the host build does not produce `strings.g.dart`, so `zfa build` fails after generation unless someone hand-wires the toolchain.
3. `example/specs/004-login-ui` declares no `key:` tokens — regenerating it still hardcodes EN literals.

**The key is the contract; the literal is the anchor; the ledger is the proof.**

## User Scenarios & Testing *(mandatory)*

### User Story 1 - `zfa tdd plan` writes the UI surface ledger (Priority: P1)

**Given** a spec whose Presentation layer contract declares `key:` tokens and whose behaviors quote scenario literals, **When** `zfa tdd plan` runs, **Then** the plan writes `specs/<feature>/tdd/ui-ledger.md` (+ `ui-ledger.json` twin): one row per declared surface — text rows (scenario presence literals), route rows (route-outcome literals), affordance rows (enabled-state literals + declared Presentation component tokens), and `t.<key>` key rows whose provers are the behaviors quoting the anchor. Planned provers are NOT-DONE at plan time (state recomputes on read — a stored state is a cache, never the truth).

#### Acceptance Scenarios

1. **Given** keys `auth.signIn -> 'Sign in'` and behavior A1 "the login view shows 'Sign in'", **When** plan runs, **Then** `tdd/ui-ledger.md` carries `| t.auth.signIn | key | A1 | NOT-DONE |` (a keyed literal feeds the key row, never a text row).
2. **Given** behavior A2 "the view shows 'Welcome back'" with no key anchored to it, **When** plan runs, **Then** `ui-ledger.md` carries a `| Welcome back | text | A2 | NOT-DONE |` row.
3. **Given** a spec with no literals, no contracts and no keys, **When** plan runs, **Then** the ledger artifact is written with zero rows (the empty ledger is a visible fact, never an omission) and the plan still exits 0.

### User Story 2 - `zfa tdd view` audits its own output (the localization gate) (Priority: P1)

**Given** a widget behavior whose view `zfa tdd view` is about to scaffold, **When** the rendered view source is composed, **Then** the command audits it BEFORE writing (errors-are-an-API — a refused view leaves the stub untouched):

- **untraced-surface violations**: a quoted user-facing string inside `Text(...)` that no ledger surface traces (neither a text/route/affordance row nor a declared key's anchor) — reported per string with a `--> fix:` line;
- **hardcoded-key violations** (keyed hosts only): a quoted literal that IS a declared key's anchor — the key contract requires the accessor `t.<key>`, never the EN literal (this catches a generator degraded to EN emission: the anchor is exactly what a regressed `Text('Sign in')` renders).

Any violation refuses the write (exit 1, `outcome=runner-error`); a clean audit prints the surface counts. The audited behavior's own id stays traceable (the #939 marker text) and declared Presentation component tokens trace as affordance rows, so non-i18n hosts keep the EN-literal fallback byte-for-byte — zero drift.

#### Acceptance Scenarios

1. **Given** the keyed 004-login-ui contract (`auth.signIn -> 'Sign in'`) and behavior W1 quoting `'Sign in'`, **When** the view is scaffolded, **Then** the view contains `Text(t.auth.signIn)`, NO quoted user-facing `Text('...')` literal at all, and the audit reports zero violations (exit 0).
2. **Given** a view whose composition renders `Text('Some hardcode')` traced by no row, **When** the audit runs, **Then** the command refuses before writing, prints `untraced-surface violation` with the literal and a `--> fix:` line, and exits 1.
3. **Given** a degraded composition rendering the anchored literal `Text('Sign in')` where `auth.signIn` is declared, **When** the audit runs, **Then** the command reports a hardcoded-key violation naming `t.auth.signIn` as the required accessor and exits 1.
4. **Given** no declared keys and a scenario-literal view, **When** the view is scaffolded, **Then** output is unchanged from pre-1141 (traced literals, exit 0) — zero drift for non-i18n hosts.

### User Story 3 - `zfa build` runs slang codegen when translation sources exist (Priority: P1)

**Given** a host whose TDD loop scaffolded `lib/i18n/*.i18n.json` translation sources (issue #834's "run `dart run slang` as a build step"), **When** `zfa build` runs, **Then** the slang codegen stage runs BEFORE `build_runner` so `strings.g.dart` exists when the generated view's import resolves — the build succeeds after generation without manual i18n edits. A project with no `lib/i18n` sources skips the stage entirely (zero drift); a project whose `build.yaml` wires `slang_build_runner` lets build_runner own the codegen (the stage defers); a project with sources but no resolvable slang toolchain fails with an actionable fix line, never a silent pass.

#### Acceptance Scenarios

1. **Given** `lib/i18n/strings.i18n.json` exists, **When** `zfa build` runs, **Then** the stage prints the slang codegen step and `dart run slang` executes before `build_runner`.
2. **Given** no `lib/i18n` directory, **When** `zfa build` runs, **Then** the stage is skipped (no slang invocation, identical output).
3. **Given** sources exist but slang is not resolvable, **When** the stage runs, **Then** the build exits non-zero with a fix line naming the dependency to add.

### User Story 4 - 004-login-ui regenerated under the keyed contract (Priority: P1 — the acceptance fixture)

**Given** the canonical 004-login-ui spec (skin lane, adaptive slots) whose Presentation contract now declares the login surfaces as keys (`auth.signIn`, `auth.email`, `auth.password`, `auth.sessionStarted`), **When** the loop regenerates the pair (`zfa tdd plan` → `zfa tdd gen` → `zfa tdd view`), **Then**:

- the view emits `t.<key>` accessors with the host import and ZERO hardcoded user-facing strings (US2 audit proves it mechanically);
- the paired test boots the slang test shell pinned to the base locale and asserts through resolved keys;
- every declared key lands in `lib/i18n/strings.i18n.json` (merge, never clobber);
- an EN copy edit (`'Sign in'` → `'Log In'`) regenerates a byte-identical assertion line — copy edits cannot break generated tests.

#### Acceptance Scenarios

1. **Given** the keyed 004-login-ui fixture, **When** regenerated, **Then** the view source contains no quoted `Text('...')` literal and `lib/i18n` carries every declared key.
2. **Given** the regenerated pair, **When** the EN anchor copy is edited to `'Log In'` and the pair regenerated, **Then** the generated test's keyed assertion lines are byte-identical (the test never pinned the EN string).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa tdd plan` writes `specs/<feature>/tdd/ui-ledger.md` and `specs/<feature>/tdd/ui-ledger.json` derived from the spec's behaviors and Presentation layer contract; keyed anchors contribute to `t.<key>` key rows (kind `key`), never to text rows; absence literals contribute no row.
- **FR-002**: `zfa tdd view` audits the rendered view BEFORE any write. Violations refuse the write with per-violation `--> fix:` lines and exit 1 (`outcome=runner-error`). The audited behavior's id and the declared Presentation component tokens stay traceable; non-i18n hosts are byte-identical to pre-1141 output.
- **FR-003**: `zfa build` runs the slang codegen stage when `lib/i18n/*.i18n.json` sources exist: `dart run slang` before `build_runner`, deferring to `slang_build_runner` when `build.yaml` wires it, refusing (actionable fix line, non-zero exit) when the toolchain is unresolvable, skipping (zero drift) when no sources exist. Dry-run previews the stage without running it.
- **FR-004**: The 004-login-ui acceptance fixture (in-repo `example/specs/004-login-ui/spec.md` + the canonical test fixture) declares the login surfaces as `key:` tokens with EN anchors; regeneration proves the zero-hardcode view, the resolved-key test, the scaffold merge, and copy-edit survival.
- **FR-005**: One PR closes #1141; no path: dependency overrides are introduced; existing 0965 contracts (zero drift, refusal-before-write, determinism) remain green.

## Non-Functional Requirements

- **Determinism (VISION §4)**: the ledger artifact and the audit output are pure functions of declared inputs — identical spec, identical bytes.
- **Errors-are-an-API**: every refusal names the offending surface and carries a `--> fix:` line.
- **Zero drift**: hosts that declare no keys see no behavioral change in plan, gen, view, or build.
