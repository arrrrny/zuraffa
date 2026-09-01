# Contract: `zfa tdd verify-red`

## CLI

```text
zfa tdd verify-red [behavior-id] [--feature <feature-dir-name>]
```

- `behavior-id` — optional positional; resolution rules in spec FR-002.
- `--feature` — optional; same resolution conventions as `zfa tdd gen`
  (explicit flag, else single-feature inference from `specs/*/tdd/`).

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | honest red certified: classification `assertion`, evidence appended |
| ≠0 | not certified: named classification printed, no log write |

Exit code alone distinguishes certified vs rejected (spec US4).

## Summary line (machine-readable)

Final stdout line, stable key=value format:

```text
verify-red: behavior=<id> classification=<class> certified=<true|false> feature=<feature>
```

Example (certified):

```text
verify-red: behavior=B-003 classification=assertion certified=true feature=046-tdd-verify-red
```

Example (rejected):

```text
verify-red: behavior=B-003 classification=unexpected-green certified=false feature=046-tdd-verify-red
```

## Cycle-log entry format (append-only)

On certification, one entry appended to `specs/<feature>/tdd/cycle-log.md`:

```markdown
## Cycle: <behavior description or id>

- behavior: B-003
- kind: red
- classification: assertionFailure
- criterion: FR-007
- test: test/plugins/tdd/fixtures/b_003_test.dart
- command: `dart test test/plugins/tdd/fixtures/b_003_test.dart --plain-name "..."`
- exit: 1
- at: 2026-08-30T12:00:00.000Z
- output:
```text
Expected: ...
  Actual: ...
```
```

Field order fixed; `output` block verbatim runner output (trimmed of trailing
whitespace only).

## Errors

All rejections print `zfa tdd verify-red: <classification or error> — <detail>`
to stderr before the summary line, name the affected behavior/artifact, and
suggest the remediation (`zfa tdd gen <id>` for missing artifacts, fix the
compile error for `compile-error`, etc.).

## Integrity guarantees

- Writes: exactly one file — the `cycle-log.md` append (and only on
  certification).
- Reads: `artifacts.json`, `tdd-profile.md`, the target test/subject files.
- Never modifies, creates, or deletes anything under `test/` or `lib/`.
