# Bug Issue: fix(1267) — zfa tdd run: make step fails when entity create targets wrong working directory

- **Slug**: tdd-run-make-wrong-working-dir
- **Issue**: 1267
- **URL**: https://github.com/arrrrny/zuraffa/issues/1267
- **State**: open (at fix time)
- **Severity**: medium
- **Filed by**: ahmettok during apps/login_demo spec 001-login-ui build

> Provenance note: this record and `assessment.md` were NOT found committed
> in the repo at fix time (searched `.specify/bugs/` across all 241 slugs and
> the full git history — no `1267` match). They were recovered from GitHub
> issue #1267 (fetched via the API on the fix branch) plus the remediation
> brief carried with the bug assignment, and committed here so the record
> trail travels with the fix.

## Body (from GitHub issue #1267)

### Repro

```bash
cd /tmp
zfa setup my_app --platforms=ios,android --org=com.example
cd my_app
zfa entity create -n AuthRequest --field method:String
```

### Expected

Entity created under `my_app/lib/src/domain/entities/auth_request/`.

### Actual

Entity created in zuraffa repo root `lib/src/domain/entities/auth_request/`
instead of the target app. Same issue applies to `zfa entity create`,
`zfa make`, and `zfa build` when run from a parent directory without using
the `-C <project>` flag.

### Root cause

`zfa` resolves the project root from the current working directory rather
than the closest `pubspec.yaml`. When invoked from a parent directory, files
end up in the wrong project.

### Suggested fix

Auto-detect the project root by searching upward for `pubspec.yaml` if no
`-C` is given. Or always require the `-C` flag and emit a clear error if
missing.

### Workaround used

`zfa -C apps/my_app entity create ...`
