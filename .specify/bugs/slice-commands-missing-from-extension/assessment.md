# Bug Assessment: slice merge/verify/export not registered in the speckit zuraffa extension

- **Slug**: slice-commands-missing-from-extension
- **Created**: 2026-08-30
- **Source**: pasted text (failing test output from `dart test`)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

```text
Expected: empty
  Actual: [
            'slice/merge_slice -> zfa.slice.merge_slice',
            'slice/verify_slice -> zfa.slice.verify_slice',
            'slice/export_slice -> zfa.slice.export_slice'
          ]
manifest commands with no extension provides entry:
  slice/merge_slice -> zfa.slice.merge_slice
  slice/verify_slice -> zfa.slice.verify_slice
  slice/export_slice -> zfa.slice.export_slice
```

## Symptom

`zfa manifest` exposes four `slice` commands — `cut_slice`, `merge_slice`,
`verify_slice`, `export_slice` — but `.specify/extensions/zuraffa/extension.yml`
`provides:` only registers `zfa.slice.cut_slice`. The parity test
(`extension_command_parity_test.dart`) requires every manifest command to have a
`provides` entry **and** a corresponding command `.md` following the template
shape. Expected: all four slice commands are registered with template-shaped docs.

## Reproduction

```bash
dart test test/cli/standard/extension_command_parity_test.dart -p vm --plain-name 'every zfa manifest command is registered in the speckit extension'
```

## Suspected Code Paths

- `.specify/extensions/zuraffa/extension.yml:365-369` — only `zfa.slice.cut_slice` is registered under `provides: commands:`; the `merge_slice`, `verify_slice`, `export_slice` entries are absent.
- `lib/src/plugins/slice/slice_command.dart` + the slice plugin manifest — the plugin exposes `cut`, `merge`, `list`, `inspect`, `verify`, `run`, `export`, `import` sub-commands, surfaced in `zfa manifest` as `slice/*_slice`. The extension registration was not updated when merge/verify/export were added to the manifest.
- `lib/src/commands/generate_commands_command.dart` — the `zfa.generate-commands` regeneration step; confirm whether it should auto-emit the missing `provides` entries and `.md` files (it currently does not cover slice).

## Root Cause Hypothesis

The slice plugin gained `merge`/`verify`/`export` sub-commands (manifest names
`merge_slice`, `verify_slice`, `export_slice`), but the speckit extension's
`extension.yml` `provides:` list and the matching `commands/slice/*.md` files were
never added. The parity test flags the gap. Confidence: **high**.

## Proposed Remediation

**Preferred**: Add three `provides:` entries to
`.specify/extensions/zuraffa/extension.yml` (after the `zfa.slice.cut_slice`
entry) and create the three template-shaped `.md` files:

```yaml
- name: speckit.zuraffa.slice.merge_slice
  file: commands/slice/merge_slice.md
  description: Merge agent changes from a slice back into the project
  aliases: [zfa.slice.merge_slice]
  category: slice
- name: speckit.zuraffa.slice.verify_slice
  file: commands/slice/verify_slice.md
  description: Check a slice's imports resolve (optionally dart analyze)
  aliases: [zfa.slice.verify_slice]
  category: slice
- name: speckit.zuraffa.slice.export_slice
  file: commands/slice/export_slice.md
  description: Export a slice (tar.gz or github) and import it back
  aliases: [zfa.slice.export_slice]
  category: slice
```

Each `.md` must start with frontmatter (`name:`/`description:`/`category:`) and
contain the sections `## Usage`, `## When to Use`, `## Required Parameters`,
`## Flags`, `## Output` (model on `commands/slice/cut_slice.md`).

**Alternatives**:
- Extend `zfa.generate-commands` to regenerate the slice `provides` entries + `.md` files from the manifest so this parity cannot regress.

**Files likely to change**:
- `.specify/extensions/zuraffa/extension.yml`
- `.specify/extensions/zuraffa/commands/slice/merge_slice.md` (new)
- `.specify/extensions/zuraffa/commands/slice/verify_slice.md` (new)
- `.specify/extensions/zuraffa/commands/slice/export_slice.md` (new)

**Tests to add or update**:
- `test/cli/standard/extension_command_parity_test.dart` is the guard; consider also asserting the `.md` alias→file mapping for slice.

## Risks & Considerations

- The `expectedAlias` mapping in `extension_command_parity_test.dart` uses the
  default `zfa.$plugin.$name` form for slice, so `merge_slice`→`zfa.slice.merge_slice`
  already matches — only the `provides` entries and `.md` files are missing.
- `category: slice` must be declared in `extension.yml` `categories:` (it already is).

## Open Questions

- None blocking.

## Failing tests covered by this assessment

1. `test/cli/standard/extension_command_parity_test.dart: every zfa manifest command is registered in the speckit extension`
