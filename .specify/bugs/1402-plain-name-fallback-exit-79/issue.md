## Symptom

During a full hand-driven cycle (feature `xray-cli`, 29 behaviors) at a `Un:hand` step, the test name was hand-edited while the behavior description string was not embedded verbatim. `zfa tdd make Un` then failed with:

```
zfa tdd make: behavior U2
   command: flutter test {file} --plain-name "{description}"
   runner exit: 79   (flutter: "No tests ran")
```

No diagnostic points at the actual cause: `--plain-name` performs a substring match against the outer `test(...)` name, and the hand-written name didn't contain the behavior description string that zfa passes through. The cycle driver reports a generic failure; the agent must reverse-engineer that the test name must embed the description verbatim.

## Expected

Either:

1. `make` falls back to running the whole target file when `--plain-name` matches zero tests, and warns (best), or
2. the runner detects exit 79 / "No tests ran" and emits a targeted remedy: "test name must contain the behavior description verbatim — rename the test(...) to embed it" (minimum), or
3. gen emits the behavior description as a comment marker in the test file that the runner matches on instead of the free-text test name (robust).

## Repro

1. Author a behavior, run `zfa tdd gen`, hand-edit the generated test and rename the outer `test('...')` so it does NOT contain the behavior description string verbatim.
2. Run `zfa tdd make <behavior-id>`.
3. Observe exit 79 "No tests ran" with no name-mismatch remedy.

## Workaround used

Embed the exact behavior description (character-for-character) as the outer test name — then `--plain-name` resolves and make proceeds. Documented in `docs/zfa-tdd-guide.md` §8.

## Context

- Binary: post-`583d711d` build, branch `fix/1351-gen-flutter-test-import`
- Related: #859 (earlier --plain-name regex escaping), #760 (`-n` regex parens — different root cause), #1259/#1388 (guard-only family), #1373 (scaffolded widget stop)
- Full-cycle evidence: `xray-cli` spec — 22 CORE + 7 SKIN behaviors, live-verified macOS app
