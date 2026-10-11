# Research: 1405 — skin plan author strict W-ids + plan validator

## R1 — Where the malformed table comes from

Reproduction chain (verified against the unfixed tree):

1. The authoring LLM writes the SKIN lane declaration with behavior
   sentences that contain commas, e.g.:
   `behaviors: [Sign In header and subtitle, W1 (renders the login screen pixel-perfect, W2, a full-width guest outline button, an or divider, ...]`
2. `SpecParser.parseLanes` → `_listTokens` splits on commas → tokens are
   sentence fragments.
3. `_expandBehaviorTokens` strips only a *closed* trailing paren
   (`\(([^)]*)\)\s*$`). `W1 (renders the login screen pixel-perfect` has an
   unmatched paren → no strip → the token passes through **verbatim** as an
   "id". Bare prose fragments pass through verbatim too.
4. `PlanCommand._resolveLanes`' hand-row loop emits one `LaneRow` per
   declared-but-underved id: `| Sign In header and subtitle | skin behavior
   declared in `## Lanes` | ...` — exactly the malformed outer-loop table
   from the issue.
5. Downstream, only `W2` parses as a reachable W-behavior → the skin lane's
   denominator collapses to 1 (0/1), 8 behaviors machine-unreachable.

## R2 — The rescue rule (emission half)

- Anchored extraction: `RegExp(r'^W\d+')` on the trimmed token. A token
  that *starts* with the W-id followed by leaked prose / an unmatched paren
  is emitted as the strict id, prose remainder in the behavior column.
  This matches the issue's observed truncation shape and AC-1's "prose in
  the behavior column only".
- Mid-token prose (`the W1 button`) is NOT rescued: guessing ids out of
  mid-sentence prose would fabricate behavior identity. It is refused with
  the fix line (write clean `^W\d+$` ids; annotations carry prose).
- Already-strict tokens (`W2`) pass through byte-identical (AC-4).
- Dedup: two tokens sanitizing to the same id collapse (last prose wins —
  the same "last word is the author's current intent" rule the
  classification map already applies).

## R3 — The refusal surface (validator half)

`_LaneResult.refusals` already drives the plan gate: non-empty → print the
lines ("lane contract FAILED — n lane violation(s)"), exit 2, **no
artifacts written** ("the lane guards refuse BEFORE any artifact"). The
validator feeds the same list, so:

- rejection happens at plan time (never at gen/run time) — AC-2/FR-003;
- a rejected plan writes no `04-SKIN.md` — FR-004, SC-06;
- the refusal text names the offending token and the malformation class
  (spaces / unmatched paren / no `W\d+` pattern).

Diagnosis precedence for a non-strict id cell (first match wins):
1. contains a space → "carries spaces (prose leaked into the id column)"
2. carries an unmatched paren → "carries an unmatched paren (truncated
   mid-sentence)"
3. no `W\d+` pattern anywhere → "carries no W<digits> pattern"
4. otherwise → "is not a strict W-id (^W\d+$)"

## R4 — Why status fixes transitively (and why we don't touch it)

`zfa tdd status` reads the unified journal; the lane totals come from the
run receipts; the receipts total the behaviors the driver resolved from the
lane plan rows (TestListReader). A malformed table resolves ~1 row; a clean
table resolves all 9. Strict emission + validator rejection make the plan's
machine-reachable row count equal the declared W-id count, so the status
line reports the real denominator without touching the status command, the
journal, the run driver, gen, make, or verify — exactly the hard
constraint's boundary. Proof is via the reader resolution count (SC-04)
rather than a status-command end-to-end run (which needs the Flutter-side
driver).

## R5 — Alternatives rejected

- **Validate inside `SpecParser._expandBehaviorTokens`** (reject unclosed
  parens there): that changes the shared derivation input for CORE/BOTH
  lanes too and risks the documented `A3 (acceptance: ...)` and `W1-W4`
  range forms — a derivation-algorithm change the hard constraints forbid.
- **Silently skip non-W tokens**: the silent-drop bug class (issue #1432)
  — forbidden by the constitution's errors-are-an-API gate.
- **Whole-table `^W\d+$` validation of `04-SKIN.md`**: would reject the
  BOTH seam's spec-derived `A/U` rows that legitimately render in the
  skin plan's widget section — a backward-compatibility break (AC-4).
  The validator's scope is the skin plan author's W-behavior rows (the
  W-slot reservation), which is what the issue's malformed table carried.
- **Validate at gen/run time (TestListReader)**: explicitly forbidden by
  AC-2 ("plan time, not gen/run time") and too late — the malformed
  artifact would already exist.
