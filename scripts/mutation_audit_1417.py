#!/usr/bin/env python3
"""Real mutation audit for issue #1417 (writer logic of
lib/src/commands/speckit_scaffolding.dart).

Why not `dart run mutation_test mutation-test-1417.xml`?
  - Unscoped, the builtin Dart rules generate 538 mutants in this file and
    ALL of them live inside the embedded bash-script string constants
    (data already pinned byte-exact by the drift-guard test U-1417-b9) —
    ~40s per mutant ≈ 8h of noise.
  - Scoped to the whitelisted writer-logic lines (see
    mutation-test-1417.xml), the builtin rules
    generate 0 candidates, and custom <regex> rules, although registered
    ("45 mutation rules" in -v output) and provably matching the file text
    (verified with python re), contributed 0 mutants — a tool-engine quirk
    this session could not resolve in budget.

So this script performs the mutation audit directly, with the same contract
as `zfa tdd verify` (FR-014..FR-023):
  1. baseline: the target test suite must be GREEN before any mutation;
  2. one mutant at a time, applied in place via a verified single-match
     regex substitution;
  3. KILLED = the suite fails (non-zero exit) under the mutant;
  4. SURVIVED = the suite stays green (a weak test — the audit fails);
  5. the original file is restored after EVERY mutant and verified by
     sha256 at the end (FR-021: restore before returning).

Scope note: `initialize_command.dart`'s --speckit wiring (~12 logic lines)
is exercised by the subprocess acceptance tests (U-1417-b1..b8) but is not
mutation-audited here: a lib/ mutant marks the CLI's AOT binary stale and
forces an ~85-100s recompile per mutant (issues #1623/#1664), which cannot
fit the "<10s per mutant" rubric. The wiring is 4 lines of delegation into
the audited writer.
"""
import hashlib
import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
TARGET = REPO / "lib/src/commands/speckit_scaffolding.dart"
TEST_CMD = [
    "dart", "test", "test/commands/initialize_speckit_test.dart",
    "-j", "1", "-n", "SpeckitScaffoldingWriter unit",
]

# (mutant id, regex pattern, replacement, expected match count, equivalent?)
# The last flag marks PROVEN equivalent mutants (behaviorally unreachable
# difference — no test can kill them; excluded from the score per standard
# mutation-testing practice, proof recorded in tdd/verification.md).
MUTANTS = [
    ("M01 file.existsSync() -> false (created branch never runs)",
     r"file\.existsSync\(\)", "false", 1, False),
    ("M02 existing == content -> existing != content (up-to-date treated as stale)",
     r"existing == content", "existing != content", 1, False),
    ("M03 if (!force) -> if (force) (clobber committed scaffolding)",
     r"if \(!force\)", "if (force)", 1, False),
    ("M04 if (!dryRun) -> if (dryRun) (dry-run writes, real run doesn't)",
     r"if \(!dryRun\)", "if (dryRun)", 4, False),
    ("M05 gi.existsSync() -> false (gitignore never updated)",
     r"gi\.existsSync\(\)", "false", 1, False),
    ("M06 _needsForceInclude(...) -> false (gitignore gate never fires)",
     r"_needsForceInclude\(gi\.readAsStringSync\(\)\)", "false", 1, False),
    ("M07 comment-line skip drops isEmpty (blank lines scanned)",
     r"line\.isEmpty \|\| line\.startsWith\('#'\)", "line.isEmpty", 1, True),
    ("M08 rule.startsWith('!') -> false (negations never detected)",
     r"rule\.startsWith\('!'\)", "false", 1, False),
    ("M09 negated = true -> negated = false (negation inverted)",
     r"negated = true", "negated = false", 1, False),
    ("M10 parentExcluded = !negated -> parentExcluded = negated "
     "(parent verdict inverted)",
     r"parentExcluded = !negated", "parentExcluded = negated", 1, False),
    ("M11 needed verdict -> true (always needs update)",
     r"needed: parentExcluded \|\| scriptsExcluded", "needed: true", 1, False),
    ("M12 marker guard contains() -> false (managed block never stripped)",
     r"existing\.contains\(gitignoreMarker\)", "false", 1, False),
    ("M13 !existing.endsWith -> existing.endsWith (newline handling inverted)",
     r"!existing\.endsWith\('\\n'\)", r"existing\.endsWith\('\\n'\)", 1, False),
    ("M14 scriptsExcluded = !negated -> scriptsExcluded = negated "
     "(child/direct verdict inverted)",
     r"scriptsExcluded = !negated", "scriptsExcluded = negated", 1, False),
    ("M15 parentExcluded: scan.parentExcluded -> false "
     "(parent pair never emitted)",
     r"parentExcluded: scan\.parentExcluded", "parentExcluded: false", 1,
     False),
    ("M16 existing = _stripManagedBlocks(existing) -> existing "
     "(stale block left before later exclusions)",
     r"existing = _stripManagedBlocks\(existing\)", "existing = existing", 1,
     False),
]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def run_tests() -> bool:
    proc = subprocess.run(
        TEST_CMD, cwd=REPO, capture_output=True, text=True, timeout=240
    )
    return proc.returncode == 0


def main() -> int:
    original = TARGET.read_bytes()
    digest = sha256(original)
    text = original.decode("utf-8")

    print("=== Baseline (no mutation) ===")
    if not run_tests():
        print("BASELINE RED — the audit refuses to run a red suite.")
        return 2
    print("baseline: GREEN")

    results = []
    failed = []
    equivalent = []
    for mutant_id, pattern, replacement, expected, is_equivalent in MUTANTS:
        rx = re.compile(pattern)
        matches = rx.findall(text)
        if len(matches) != expected:
            print(
                f"{mutant_id}: SKIP — pattern matched {len(matches)}x "
                f"(expected {expected}); file drifted?"
            )
            failed.append(mutant_id)
            continue

        mutated = rx.sub(replacement, text, count=expected)
        TARGET.write_bytes(mutated.encode("utf-8"))
        try:
            killed = not run_tests()
        finally:
            TARGET.write_bytes(original)  # restore BEFORE judging (FR-021)

        status = "KILLED" if killed else "SURVIVED"
        results.append((mutant_id, status))
        print(f"{mutant_id}: {status}")
        if not killed:
            if is_equivalent:
                equivalent.append(mutant_id)
            else:
                failed.append(mutant_id)

    restored = sha256(TARGET.read_bytes()) == digest
    print(f"\nRestoration verified: {restored}")

    killed_n = sum(1 for _, s in results if s == "KILLED")
    print(
        f"\nMutants: {len(results)}  Killed: {killed_n}  "
        f"Survived: {len(results) - killed_n}  "
        f"(of which equivalent: {len(equivalent)})  Timeouts: 0"
    )
    if not restored:
        print("FATAL: target file not restored byte-identically!")
        return 3
    if failed:
        print("AUDIT: FAIL — survivors or unmatched patterns:")
        for f in failed:
            print(f"  - {f}")
        return 1
    print("AUDIT: PASS — all non-equivalent mutants killed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
