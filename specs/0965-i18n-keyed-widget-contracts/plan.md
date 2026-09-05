# Plan: 0965-i18n-keyed-widget-contracts (issue #965)

## Context

The widget lane (`zfa tdd view` + the paired generated widget test) pins quoted EN
literals: `Text('ZikZak')` in the view, `find.text('ZikZak')` in the test. Production
ZikZak renders through slang keys (`t.app.name`, `t.auth.signIn`, 7+ locales) and the
host enforces a 100% localization hard gate. Machine-generated views can therefore
never satisfy #962's zero-edit merge exit criterion.

Remediation: **the key is the contract, the literal is the anchor** — declared in the
spec's Presentation layer contract, honored by generation, resolved by the test shell,
traced by the ledger (#963), and optionally exercised under an expansion locale.

## Design

### Contract shape (declared, never guessed — #951)

Presentation layer-contract rows carry key tokens among their declared methods:

```markdown
## Layer contracts

### Presentation

- `LoginSection`: `ShadInput` for email, `ShadButton` for submit, `key: auth.signIn -> 'Sign in'`, `key: app.name -> 'ZikZak'`
```

The token grammar (`I18nKeyContract.parseToken`): `key:` + dotted key
(≥2 segments, each `[a-z][a-zA-Z0-9_]*`) + optional `-> 'anchor'` (single- or
double-quoted; missing anchor falls back to the key tail). A `key:`-prefixed token
that fails the grammar throws a typed refusal naming the token and the `--> fix:`
(errors-are-an-API). Extraction rides the EXISTING `LayerContract` model, so both
producers — `SpecParser.parseLayerContracts` (spec.md) and
`TestListReader.readLayerContracts` (tdd/test-list.md) — feed the same table.

### Generation (`view_command.dart`)

`_renderView` maps scenario assertions through the key table before rendering:

- presence literal == declared anchor → `Text(t.<key>)` (accessor, never quoted);
- enabled-state literal == declared anchor → `ElevatedButton(... child: Text(t.<key>))`;
- non-keyed literals render exactly as before (EN fallback for non-i18n hosts).

When at least one keyed surface is emitted the subject gains the host accessor
import (`package:<pubspec-name>/i18n/strings.g.dart`, relative fallback when the
pubspec is unreadable). After scaffolding, missing declared keys are merged into
`lib/i18n/strings.i18n.json` (+ expansion files) — existing values never clobbered,
sorted keys, 2-space indent, trailing newline.

### Test shell (`behavior_test_writer.dart` + `gen_command.dart`)

`BehaviorTestWriter` gains `i18nKeys` (anchor→key), `i18nImport`, and
`i18nExpansion` (locales). Keyed assertions emit `find.text(t.<key>)`; the test
boots the slang test shell (`LocaleSettings.setLocaleRaw('en')` pinned to the base
locale) only when keyed surfaces exist. Expansion locales add a second
`testWidgets` re-pumping under the expansion locale asserting the same keyed
surfaces (de strings run ~30% longer — overflow assumptions surface before
goldens). Non-keyed output stays byte-identical to the pre-#965 template.

### Ledger (`ui_ledger_builder.dart` + #963)

`UiSurfaceKind` gains `key`; `I18nKeyTable.toDeclaredSurfaces()` projects each
declared key as `t.<key>`; `UiLedgerBuilder.untracedHardcodedStrings` reports every
quoted string inside `Text(...)` in a generated view that no ledger row (text row
equal to the literal, or key row whose anchor equals it) traces — the mechanical
form of "a hardcoded user-facing string in a generated view is an untraced-surface
violation".

## Runtime artifacts (host project, not this repo)

`lib/i18n/strings.i18n.json` — base locale source (slang); `strings_<loc>.i18n.json`
— expansion locales; `lib/i18n/strings.g.dart` — the host's slang codegen output the
generated code imports. This repo only ever WRITES the `.i18n.json` sources and READS
the pubspec for the accessor URI.

## Risks

- Determinism (VISION §4): JSON merge must be order-stable (sorted) and idempotent
  (re-run produces identical bytes) — covered by tests.
- Non-i18n hosts: no declared keys → every touched template branch is inert;
  byte-identity with the pre-#965 shapes is a tested acceptance criterion.
