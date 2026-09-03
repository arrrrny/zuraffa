# Bug Issue: Template self-hosting: generator templates born through zfa's own TDD loop

- **Slug**: template-self-hosting
- **Fetched**: 2026-09-03
- **Issue**: 912
- **URL**: https://github.com/arrrrny/zuraffa/issues/912
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

"Part of #908. Absorbs live defects: #907 (migrate-paths package-URI rewrite + success-on-red), apostrophe breakage, and widget-template shallowness.

## Live defect Register (all reproduced on master)

1. Persistence template: behavior description 'persist the user's theme preference' injected UNESCAPED into a single-quoted Dart string → unterminated literal → compile-error classified honestly but blocks the behavior.
2. Widget template pumps inside MaterialApp; ZikZak is ShadApp/shadcn_ui — SC-001 asserts ShadTheme.
3. Widget template asserts 'findsOneWidget' placeholder — green achievable by returning SizedBox(); scenario not actually asserted.
4. migrate-paths (#907): rewrites test relative imports but not package-URI imports in composed subjects; reports migrated=N success while the suite is unloadable.
5. route create dry-run omits the route-table test from the changes list (real run emits it).

## Required

1. Every template gets an escaping/literal-safety pin test (apostrophes, quotes, backticks, ${}, unicode).
2. Shell-configurable widget template (ShadApp default for zuraffa apps) + scenario-derived finders — placeholder finders mark the test 'scaffolded', excluded from contract-green accounting.
3. Migration commands self-check: compile/run the affected feature before declaring success; doctor gains import-resolution drift check.
4. Meta-rule (VISION self-hosting): template changes ship through zfa's own red-green loop with the defect register as the fixture corpus."

## Comments

None.
