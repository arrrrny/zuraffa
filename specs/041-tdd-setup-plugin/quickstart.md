# Quickstart — TDD-ready `zfa setup` + `zfa tdd` plugin

## Part 1 — Day-zero TDD baseline from `zfa setup`

```bash
zfa setup myapp
cd myapp
flutter test                                # exit 0, ≥1 test
flutter test test/bootstrap_smoke_test.dart  # only that file
cat .specify/memory/tdd-profile.md           # five-key map

zfa setup myapp2 --tdd-example
cd myapp2
flutter test test/tdd_example_test.dart      # assertion failure (red demo)
```

## Part 2 — Driving a feature through the TDD cycle

```bash
cd existing-flutter-project
zfa tdd init                                # ensure TDD baseline
zfa tdd plan 041-tdd-setup-plugin           # emits specs/<feature>/tdd/test-list.md
zfa tdd run 041-tdd-setup-plugin            # drives the full cycle
zfa tdd verify                              # writes tdd/verification.md
```

## Misfire-stop policy

If any step cannot complete as specified (e.g. `zfa tdd make B-005` cannot generate the implementation), the loop driver stops at `B-005` with state `RED`, exits non-zero, and reports the failure. The plugin does not patch the test to make it pass.
