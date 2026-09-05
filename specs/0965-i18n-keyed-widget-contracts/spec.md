# Feature Specification: i18n-keyed widget contracts — pin slang keys not EN literals, resolve via the translation test shell (ZIKZAK-REBUILD)

**Issue:** [#965](https://github.com/arrrrny/zuraffa/issues/965) · **Blocks:** #962 (plug-in contract zero-edit merge), #963 (UI coverage ledger) · **References:** #834 (slang in the TDD loop, closed), #951 (declared intent over prose), #964 (finder-kind taxonomy — `LiteralKind.key` is reserved for this contract)

## Summary

The widget lane pins **quoted EN literals**: `zfa tdd view` emits `Text('ZikZak')` and the generated test asserts `find.text('ZikZak')`. The production ZikZak login renders through slang keys (`t.app.name`, `t.auth.signIn`, 7+ locales) and the host enforces a **100% localization hard gate** (`/localize` runs slang codegen before any view is complete). A machine-generated view can never satisfy #962's zero-edit merge exit criterion — it lands with hardcoded English and fails the host's gate. Phase 4 is blocked by design, not by effort.

**The key is the contract; the literal is the anchor.**

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The spec declares i18n-keyed surfaces (Priority: P1)

**Given** a zuraffa-1.0 spec whose Presentation layer-contract row declares a key token with the EN literal as the anchor:

```markdown
### Layer Contracts

**Presentation**:
- `LoginSection`: `ShadInput` for email, `ShadButton` for submit, `key: auth.signIn -> 'Sign in'`, `key: app.name -> 'ZikZak'`
```

**When** the contract is parsed (the same `LayerContract` shape both `SpecParser.parseLayerContracts` and `TestListReader.readLayerContracts` produce), **Then** every `key:` token resolves to a declared i18n surface: a dotted key (`auth.signIn`) plus its EN anchor (`Sign in`), and a malformed `key:` token refuses with the row named and a `--> fix:` hint (errors-are-an-API).

#### Acceptance Scenarios

1. **Given** the row above, **When** parsed, **Then** the key table contains `auth.signIn` anchored to `'Sign in'` and `app.name` anchored to `'ZikZak'`.
2. **Given** a token `key: authsignIn` (no dot), **When** parsed, **Then** a typed refusal names the token and the fix.
3. **Given** a token `key: auth.signIn -> "Sign in"` (double-quoted anchor) or `key: auth.signIn` (anchor omitted — falls back to the key tail), **When** parsed, **Then** the declaration resolves.

### User Story 2 - Generation emits `t.<key>` and scaffolds missing translation keys (Priority: P1)

**Given** a widget-kind behavior whose scenario quotes a literal that equals a declared anchor (`shows 'Sign in'`), **When** `zfa tdd view` scaffolds the view, **Then** the view renders `Text(t.auth.signIn)` — never `Text('Sign in')` — imports the host's generated slang accessor, and every declared key missing from `lib/i18n/strings.i18n.json` is scaffolded (merged, existing translations never clobbered) so the host's `/localize` gate passes mechanically. Non-i18n hosts keep the EN-literal fallback: literals without a declared key render exactly as before.

#### Acceptance Scenarios

1. **Given** the declared key `auth.signIn -> 'Sign in'` and behavior `the login page shows 'Sign in'`, **When** the view is generated, **Then** the subject contains `Text(t.auth.signIn)` and does not contain `Text('Sign in')`.
2. **Given** `lib/i18n/strings.i18n.json` missing `auth.signIn`, **When** the view is generated, **Then** the file gains `{"auth": {"signIn": "Sign in"}}` (2-space, sorted, trailing newline) without touching pre-existing keys.
3. **Given** a scenario literal with NO declared key (`shows 'Welcome back'`), **When** the view is generated, **Then** the view keeps `Text('Welcome back')` (the anchor/fallback for non-i18n hosts) and no i18n import is added when no keyed surface is emitted.

### User Story 3 - The translation test shell asserts resolved keys (Priority: P1)

**Given** a widget behavior with keyed presence surfaces, **When** `zfa tdd gen` writes the paired widget test, **Then** the test boots the slang test shell — the generated accessor import plus `LocaleSettings.setLocaleRaw('<base>')` pinned to the base locale — and asserts presence through the **resolved key** (`expect(find.text(t.auth.signIn), findsOneWidget)`), never the EN string. A copy edit to the EN copy cannot break green; a missing key fails RED honestly.

#### Acceptance Scenarios

1. **Given** keyed surfaces, **When** the test is generated, **Then** the assertion is `find.text(t.auth.signIn)` and the EN anchor appears nowhere in the test's finders.
2. **Given** the anchor copy is edited (`'Sign in'` → `'Sign In'`) and the pair regenerated, **When** the generated test is diffed, **Then** the assertion line is byte-identical (copy-edit survival by construction).
3. **Given** no declared keys for the behavior's literals, **When** the test is generated, **Then** the output is byte-identical to the pre-#965 template (no i18n import, no locale pin, EN literals) — zero behavioral drift for non-i18n hosts.

### User Story 4 - The ledger traces `t.<key>` per row; hardcoded strings are violations (Priority: P2)

**Given** declared keyed surfaces, **When** the UI surface ledger (#963) is derived, **Then** each key is a row (`t.<key>`, kind `key`) with provers and state. A generated view's **hardcoded user-facing string** — a quoted string literal inside `Text(...)` — that traces to no ledger surface (neither a text row nor a keyed surface's anchor) is an **untraced-surface violation**, reported per string.

#### Acceptance Scenarios

1. **Given** keys `auth.signIn` (green prover A1) and `auth.signOut` (no prover), **When** the ledger is derived, **Then** rows `t.auth.signIn` DONE and `t.auth.signOut` NOT-DONE appear.
2. **Given** a view source containing `Text('Some hardcode')` where the ledger knows only `t.app.name` anchored `'ZikZak'`, **When** the detector runs, **Then** `Some hardcode` is reported as an untraced-surface violation and the keyed accessor `Text(t.app.name)` is never flagged.

### User Story 5 - Optional tier: expansion locale pumps catch overflow before goldens (Priority: P3)

**Given** `--i18n-expansion de` (or `.zfa.json` `tdd.i18nExpansion`), **When** the test is generated, **Then** the file gains an expansion-tier `testWidgets` that re-pumps the view under `LocaleSettings.setLocaleRaw('de')` and re-asserts every keyed surface (de strings run ~30% longer — overflow assumptions surface before goldens), and missing `strings_de.i18n.json` keys are scaffolded like the base locale. Without the flag the tier is absent.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Presentation layer-contract rows declare i18n surfaces as tokens shaped `key: <dotted.key>` optionally followed by `-> '<anchor>'` (single- or double-quoted). Dotted keys require ≥2 segments, each `[a-z][a-zA-Z0-9_]*`. A missing anchor falls back to the key's last segment.
- **FR-002**: `zfa tdd view` renders `t.<key>` for every presence/enabled-state scenario literal equal to a declared anchor; adds the generated-accessor import exactly when a keyed surface is emitted; leaves non-keyed literals untouched.
- **FR-003**: Missing declared keys are scaffolded into `lib/i18n/strings.i18n.json` (and `strings_<locale>.i18n.json` per expansion locale) by merge — existing values are never rewritten; output is sorted, 2-space-indented JSON with a trailing newline.
- **FR-004**: Generated widget tests boot the slang test shell (accessor import + base-locale pin) and assert keyed surfaces via `find.text(t.<key>)`; EN anchors never appear in generated finders for keyed surfaces.
- **FR-005**: The ledger derives one `key`-kind row per declared key (`t.<key>`); the untraced-surface detector reports every quoted `Text(...)` literal in a generated view that no ledger row (text or keyed anchor) traces.
- **FR-006**: `--i18n-expansion <locales>` (comma list; `.zfa.json` `tdd.i18nExpansion`) adds the expansion tier to generated tests and scaffolds the expansion files; absent → byte-identical to the pre-#965 shapes for non-keyed content.

### Key Entities *(include if feature involves data)*

- `I18nKeyContract`: one declared surface — `key` (dotted), `anchor` (EN literal).
- `I18nKeyTable`: the feature's declared surfaces; anchor→key resolution; declared-surface projection for the ledger.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 004-login-ui-style widget contracts regenerated against this spec produce views with zero hardcoded user-facing strings (every scenario literal either keyed or declared) and tests that survive an EN copy edit byte-for-byte.
- **SC-002**: A feature merged under #962 passes the host's localization gate with no hand edits — all declared keys present in `lib/i18n` after generation.
- **SC-003**: Finder-kind taxonomy composes: key literals are one literal kind (`LiteralKind.key`), asserted through the resolved accessor, never flattened to display text.

## Assumptions

- The host uses slang with the default global `t` accessor generated at `lib/i18n/strings.g.dart` (the #834 slang-in-the-loop convention); `LocaleSettings.setLocaleRaw` pins the test shell locale.
- Generated artifacts remain deterministic (VISION §4): same registry record + test list + stub → same bytes, including scaffolded JSON.
