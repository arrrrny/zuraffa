# Quickstart: validating `zfa tdd verify-red`

Runnable end-to-end validation of the implemented command. Prerequisites:
repo checkout on branch `046-tdd-verify-red`, Dart SDK on PATH.

## 1. Unit suite (fast)

```bash
dart test test/plugins/tdd/red_classifier_test.dart \
          test/plugins/tdd/runner_test.dart \
          test/plugins/tdd/verify_red_command_test.dart
```

Expected: all pass; classifier suite covers all six classes (spec SC-001).

## 2. Fixture-based certification (honest red)

The command test suite builds a temp fixture project with a `gen`-style
registry entry whose test fails with an assertion failure. To reproduce
manually:

```bash
# inside a fixture project with specs/<f>/tdd/artifacts.json + a red test
dart run bin/zfa.dart tdd verify-red B-001
echo "exit=$?"   # expect exit=0
grep -c 'kind: red' specs/<f>/tdd/cycle-log.md   # expect +1 entry
tail -1 <(dart run bin/zfa.dart tdd verify-red B-001) # summary line shape
```

Expected: exit 0, summary line
`verify-red: behavior=B-001 classification=assertion certified=true ...`, and
a complete 8-field entry appended to `cycle-log.md`
(see [contracts/verify-red.md](contracts/verify-red.md)).

## 3. Dishonest-red rejection matrix

For each fixture class (`compile-error`, `load-error`, `skipped`,
`unexpected-green`, `runner-error`):

```bash
dart run bin/zfa.dart tdd verify-red <id>; echo "exit=$?"
```

Expected: non-zero exit, the named classification on stderr, and
`cycle-log.md` byte-identical before/after (spec SC-002).

## 4. Read-only guarantee

```bash
find test lib -type f -exec shasum {} + > /tmp/before.sums
dart run bin/zfa.dart tdd verify-red B-001
find test lib -type f -exec shasum {} + > /tmp/after.sums
diff /tmp/before.sums /tmp/after.sums && echo READ-ONLY-OK
```

Expected: no diff (spec FR-008 / SC-003).

## 5. Ambiguity guard

In a fixture with two gen'd behaviors lacking red evidence:

```bash
dart run bin/zfa.dart tdd verify-red
```

Expected: non-zero exit listing both candidate ids (spec US3).
