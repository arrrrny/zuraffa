# Test List — 1535 tdd-profile `single:` template parsing

- **Feature**: `.specify/bugs/1535-tdd-profile-yaml-escape-placeholder`
- **Derived**: 2026-09-15 (tdd.plan fallback — zfa engine unavailable, LLM-guided derivation)
- **Source**: ./spec.md (AC-1 … AC-4), ./assessment.md
- **Mode**: outer-loop acceptance behaviors + inner-loop unit behaviors, red-green-refactor

## Behaviors

| id | kind | criterion | behavior | test |
|----|------|-----------|----------|------|
| B-001 | unit | AC-1 | `loadSingleTemplate` unescapes YAML double-quoted scalar escapes from the Keys block `single:` value (`\"` → `"`) before substitution | `test/plugins/tdd/bug_1535_profile_template_parsing_test.dart` → "unescapes YAML double-quoted escapes in the Keys block single: value" |
| B-002 | unit | AC-1 | frontmatter `single:` (top-level) double-quoted value is unescaped the same way | same file → "unescapes YAML double-quoted escapes in frontmatter single: value" |
| B-003 | unit | AC-1 | `file:` / `suite:` Keys-block double-quoted values are unescaped (same YAML scalar contract) | same file → "unescapes YAML double-quoted escapes in file:/suite: keys" |
| B-004 | unit | AC-2 | unknown placeholder spelling `<test name>` is rejected at load time with a StateError naming the accepted placeholders (`{file}`, `{name}`) and the remedy | same file → "rejects unknown placeholder <test name> at load time naming accepted placeholders" |
| B-005 | unit | AC-2 | legacy `<file>`/`<name>`/`<path>` spellings remain accepted (normalized) inside a double-quoted value — no false rejection | same file → "still accepts legacy <file>/<name> spellings in a double-quoted value" |
| B-006 | acceptance | AC-3 | honest red through the double-quoted escaped `single:` template runs exactly the target test (testCount == 1) and classifies `RedClassification.assertion` (issue case 2 end-to-end) | same file → "certifies an honest red through the YAML-escaped double-quoted single: template" (slow tier: spawns real `dart test`) |
| B-007 | unit | AC-4 | single-quoted Keys form is returned verbatim (no backslash processing — issue case 3 stays working) | same file → "returns the single-quoted form verbatim (no over-escaping)" |
| B-008 | unit | AC-4 | human-facing `- Single test:` bullet with `<path>`/`<name>` still normalizes (pre-existing contract) | same file → "keeps normalizing the legacy Single test bullet" |

## Notes

- B-006 is the failing-test scenario from the issue, driven through
  `SingleTestRunner.loadSingleTemplate` → `runSingle` → `classify` against the
  `TddFixture` honest-red project. Tagged `slow` (real subprocess); the loader
  unit behaviors run in the fast tier.
- Out of scope (hard constraint): classifier rules, certification logic, process
  spawning. The fix is parser-only (`runner.dart` template loading).
