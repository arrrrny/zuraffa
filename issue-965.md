# issue-965 (spec record copy)

Source: https://github.com/arrrrny/zuraffa/issues/965

## Summary

The widget lane pins **quoted EN literals** — generated views hardcode `Text('ZikZak')`, generated tests assert `find.text('ZikZak')`. The production ZikZak login renders through slang keys (`t.app.name`, `t.auth.signIn`, 7+ locales), and the host project enforces a **100% localization hard gate** (every user-facing string must be a translation key; `/localize` skill runs slang codegen before any view is considered complete).

Consequence: a machine-generated view can **never** satisfy #962's zero-edit merge exit criterion — it lands with hardcoded English and fails the host's own localization gate. Phase 4 is blocked by design, not by effort.

## Evidence (re-runnable)

- Generated: `~/zik_zak_test/lib/tdd/004-login-ui/a1_subject.dart` → `Text('ZikZak')`, `Text('AI Shopping Assistant')`, …
- Production: `~/Developer/zik_zak/lib/src/presentation/pages/login/layouts/mobile/mobile_layout.dart` → `t.app.name`, `t.app.tagline`, `t.auth.signIn`, `t.auth.continueWithApple`, …
- Generated test: `~/zik_zak_test/test/tdd/004-login-ui/a1_test.dart` → `find.text('ZikZak')` (a copy edit to the EN string breaks the test even though intent didn't change).

## Proposal: the key is the contract, the literal is the anchor

1. **Spec contract**: Presentation table rows declare `key: auth.signIn` with the EN literal as the human-readable anchor (and as the fallback for non-i18n hosts).
2. **Generation**: `zfa tdd view` emits `t.auth.signIn`; missing keys are scaffolded into `lib/i18n` (composes with #834's slang-in-the-loop work) and the host's `/localize` gate passes mechanically.
3. **Test shell**: generated widget tests boot a slang test shell pinned to the base locale and assert via the **resolved key**, not the EN string — copy edits no longer break green; missing keys fail RED honestly.
4. **Ledger** (#963): trace `t.<key>` per row; any hardcoded user-facing string in a generated view is an untraced-surface violation.
5. **Optional tier**: pump base locale + one expansion locale (de, ~30% longer strings) to catch overflow assumptions before goldens do.

## Acceptance criteria

- 004-login-ui regenerated against this contract produces views with zero hardcoded user-facing strings and tests that survive an EN copy edit.
- A feature merged under #962 passes the host's localization gate with no hand edits.
- Finder-kind taxonomy issue composes: key literals are one literal kind.

Blocks: #962 (plug-in contract), #963 (ledger). References: #834 (closed: slang in TDD loop), #951 (declared intent over prose).
