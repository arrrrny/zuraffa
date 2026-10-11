# PROGRESS — zikzak sandbox bring-up (stop-on-roadblock record)

## Resume marker

- **Stopped at**: step "port the generated app to ~/Developer/zik_zak_test" —
  `zfa make Product --preset=crud --methods=get,getList,create,update,delete
  --with=vpc --skin --state --di --test` succeeded but `zfa build` reports the
  generated code does not compile cleanly (2 generator defects, issue #1176).
- **Completed before the stop**:
  1. `flutter create zik_zak_test` (macos,ios) + pubspec deps
     (zuraffa_flutter path; dependency_overrides: zuraffa path, analyzer
     ^14.3.0 — flutter_test's graph pins analyzer <14) + zorphy_annotation +
     build_runner.
  2. `zfa entity create -n Product --field id:String --field name:String
     --field price:double` — OK.
  3. `zfa make Product --with=vpc --skin --methods=get,getList` — OK (7 files,
     auditor wrap + kit emitted).
  4. Full CRUD preset run — wrote 40+ files but left non-compiling output.
- **Resume only when** issue #1176 is MERGED, via a new goal referencing this
  file. Next step then: re-run the full CRUD preset (or `zfa build --force`),
  then `zfa build` → green, then wire `ZuraffaSkinApp` in `lib/main.dart`
  (see ~/Developer/zuraffa_demo/lib/main.dart for the working composition).

## Findings (full repro/actual/root cause in issue #1176)

1. di group indexes each emit a top-level `resetDependencies(GetIt)`; the
   top `di/index.dart` re-exports all three → ambiguous_export.
2. test plugin re-emits the placeholder `ProductMockDataSource implements
   ProductDataSource {}` (no import) even when the full CRUD+mock stack is
   requested in the same run.
