# Contract: `zuraffa_ocr` delivery

**Feature**: specs/1602-zuraffa-ocr-plugin | **Type**: delivery contract

## Invocation (fixed, normative)

```bash
zfa package create-plugin zuraffa_ocr \
  --repo arrrrrny/zuraffa_ocr \
  --description "Typed OCR support for the Zuraffa ecosystem: a pure-Dart port, recognition lifecycle, and typed failures behind an injected platform channel with federated adapters."
```

Default platform set (android, ios, macos). `--no-gate` is used by the
automated tiers (they run the gates themselves with full assertions);
the interactive delivery may run the built-in gate.

## Acceptance board (all cells exit 0)

| Gate | zuraffa_ocr | _platform | _android | _ios | _macos |
| -- | -- | -- | -- | -- | -- |
| `dart pub get` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `dart analyze --no-fatal-warnings` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `dart test` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `dart pub publish --dry-run` | ✓ | ✓ | ✓ | ✓ | ✓ |

## Stamps (asserted on every package)

- description: the OCR description verbatim
- `repository: https://github.com/arrrrny/zuraffa_ocr`,
  `issue_tracker: …/issues`
- topics include `ocr`; `version: 0.1.0`; `zuraffa: ^6.2.2` hosted
- LICENSE (MIT) + non-empty CHANGELOG.md; no `publish_to`

## Public surface (name shapes)

- app-facing: `OcrPort`, `OcrService`, `OcrException`, `OcrValue`
  (`OcrI32`/`OcrI64`/`OcrF32`/`OcrF64`), `registerOcrDependencies`
- adapters: `AndroidOcr…` / `IosOcr…` / `MacosOcr…`
  (channel, exception, port, `registerAndroidOcrDependencies`, …)

## Delivery

`~/Developer/zuraffa_ocr` → `git init -b master` → initial commit →
`gh repo create arrrrrny/zuraffa_ocr --public --source . --push` →
`gh repo view` + HTTP 200.
