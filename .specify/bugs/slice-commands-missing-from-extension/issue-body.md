## Symptom

`zfa manifest` exposes four slice commands — `cut_slice`, `merge_slice`,
`verify_slice`, `export_slice` — but `.specify/extensions/zuraffa/extension.yml`
`provides:` only registers `zfa.slice.cut_slice`. The parity test requires every
manifest command to have a `provides` entry and a matching template-shaped `.md`.

Error seen:
```
manifest commands with no extension provides entry:
  slice/merge_slice -> zfa.slice.merge_slice
  slice/verify_slice -> zfa.slice.verify_slice
  slice/export_slice -> zfa.slice.export_slice
```

## Reproduction

```bash
dart test test/cli/standard/extension_command_parity_test.dart -p vm --plain-name 'every zfa manifest command is registered in the speckit extension'
```

## Suspected Code Paths

- `.specify/extensions/zuraffa/extension.yml:365-369` — only `zfa.slice.cut_slice` registered.
- `lib/src/plugins/slice/slice_command.dart` + slice plugin manifest — merge/verify/export added but extension registration not updated.

## Root Cause Hypothesis

The slice plugin gained `merge`/`verify`/`export` sub-commands (manifest names
`merge_slice`/`verify_slice`/`export_slice`) but the extension `provides:` entries
and `commands/slice/*.md` files were never added. Confidence: **high**.

## Severity

medium — breaks documented CLI surface parity; the 3 command `.md` files are missing; 1 test red.

## Proposed fix

Add 3 `provides:` entries (`zfa.slice.merge_slice`, `zfa.slice.verify_slice`,
`zfa.slice.ex_slice...`) + template-shaped `.md` files under
`.specify/extensions/zuraffa/commands/slice/` (model on `cut_slice.md`).

Assessment: .specify/bugs/slice-commands-missing-from-extension/assessment.md
