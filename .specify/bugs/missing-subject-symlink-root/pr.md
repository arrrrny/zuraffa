# Bug Fix PR: a MISSING subject file is not "outside the project root" on symlinked roots

- **Slug**: missing-subject-symlink-root
- **Opened**: 2026-09-13
- **PR**: 1606
- **URL**: https://github.com/arrrrny/zuraffa/pull/1606
- **Branch**: fix/missing-subject-symlink-root
- **Issue**: 1603

`zfa tdd view` canonicalizes a missing subject through its nearest existing
ancestor before the outside-root guard, so a symlinked project root no longer
misreads the project's own recorded path as outside the root. Pinned by
U-V11 (symlinked-root missing-file refusal) and U-V12 (genuine outside-root
guard) with red→green + mutation evidence in `tdd/`.
