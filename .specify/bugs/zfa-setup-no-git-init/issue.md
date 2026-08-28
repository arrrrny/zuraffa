# Bug Issue: zfa setup leaves project without git init and hardcodes dependency overrides

- **Slug**: zfa-setup-no-git-init
- **Fetched**: 2026-08-28
- **Issue**: 528
- **URL**: https://github.com/arrrrny/zuraffa/issues/528
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

`zfa setup <name>` bootstraps a new Zuraffa app but has two bootstrap gaps:

1. **No git initialization** — the created project folder is not a git repo, so the documented next step `cd <app> && git add .` fails with `fatal: not a git repository`.
2. **Hardcoded dependency overrides** — `analyzer=^13.1.0` / `meta=^1.19.0` (Flutter) and `analyzer=14.1.0` (Dart) are pinned as literal constants in `dependency_wirer.dart` instead of being pulled from the actual `zuraffa_flutter` / `zuraffa` package. They silently drift when those packages bump their own overrides.
3. The Flutter/Dart separation exists in code but is coupled to those stale constants.

## Reproduction

1. `zfa setup zuraffa_dashboard` (Flutter, default)
2. Bootstrap completes; "Next steps" says `cd zuraffa_dashboard && git add .`
3. `git add .` → `fatal: not a git repository`

## Root cause (code references)

- `lib/src/commands/setup_command.dart:_createApp` (line ~313) runs `flutter create` / `dart create` via `Process.run` but never runs `git init`.
- `lib/src/core/dependencies/dependency_wirer.dart:96-105` hardcodes `flutterAnalyzerOverrideVersion = '^13.1.0'`, `flutterMetaOverrideVersion = '^1.19.0'`, `analyzerOverrideVersion = '14.1.0'`; `standardSet` (line ~114) also hardcodes `zuraffa: ^6.0.0` / `zorphy_annotation: ^2.0.0`.

## Proposed fix

- Add an explicit git-init step in `SetupCommand.run()` (skip if `.git` exists; `--no-git` opt-out; no-op on `--dry-run`).
- Resolve overrides/versions from the locally installed `zuraffa_flutter` / `zuraffa` `pubspec.yaml` `dependency_overrides`, keeping constants only as an offline fallback.

## Assessment

Full triage: `.specify/bugs/zfa-setup-bootstrap-gaps/assessment.md` (verdict: valid, severity: medium).

## Comments

None.
