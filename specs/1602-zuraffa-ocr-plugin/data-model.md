# Data Model: `zuraffa_ocr` delivery

**Feature**: specs/1602-zuraffa-ocr-plugin | **Date**: 2026-09-13

## OcrFamily (the delivered instance)

| Field | Value |
| -- | -- |
| baseName | `zuraffa_ocr` |
| classNoun | `Ocr` (`zuraffa_` prefix stripped) |
| packages | `zuraffa_ocr`, `zuraffa_ocr_platform`, `zuraffa_ocr_android`, `zuraffa_ocr_ios`, `zuraffa_ocr_macos` |
| repository | `https://github.com/arrrrny/zuraffa_ocr` (+ `/issues`) |
| version | 0.1.0 (all five) |
| framework | `zuraffa: ^6.2.2` hosted in every package |
| in-family constraints | `^0.1.0` |

## OcrStamps (asserted per package)

- description: "Typed OCR support for the Zuraffa ecosystem: a pure-Dart
  port, recognition lifecycle, and typed failures behind an injected
  platform channel with federated adapters." (verbatim in all five)
- topics include `ocr` (adapters additionally carry their platform topic)
- LICENSE (MIT) + non-empty CHANGELOG.md present
- no `publish_to` key
- public names: `OcrPort`, `OcrService`, `OcrException`, `OcrValue`,
  `AndroidOcr…` / `IosOcr…` / `MacosOcr…` in the adapters

## Dependency invariants (identical to the generator contract)

```text
zuraffa_ocr          ──> zuraffa ^6.2.2            (hosted only)
zuraffa_ocr_platform ──> zuraffa_ocr ^0.1.0
zuraffa_ocr_<plat>   ──> zuraffa_ocr ^0.1.0 + zuraffa_ocr_platform ^0.1.0
no package depends on an adapter
```

Dev-only sibling path resolution under `dependency_overrides` (stripped
by pub on publish).

## FamilyGate (the health board)

| Package | pub get | analyze | test | publish --dry-run |
| -- | -- | -- | -- | -- |
| zuraffa_ocr | 0 | 0 | 0 | 0 |
| zuraffa_ocr_platform | 0 | 0 | 0 | 0 |
| zuraffa_ocr_android | 0 | 0 | 0 | 0 |
| zuraffa_ocr_ios | 0 | 0 | 0 | 0 |
| zuraffa_ocr_macos | 0 | 0 | 0 | 0 |

## Delivery artifact

`~/Developer/zuraffa_ocr` — git repo on `master`, initial commit carrying
the family, pushed to `arrrrny/zuraffa_ocr` (public), self-contained
(no local paths in committed manifests).
