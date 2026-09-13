# Tasks — Spec 1388 gen invalidation on traces change

- [ ] T001. [behavior: U4] Fingerprint service: `GenReuseFingerprint.compute`
      pure sha256 (traces cell + spec.md), `forFeature` reader, and the
      optional `gen_fingerprint` field persisted through every
      `ArtifactRecord` copy site (copyWithOwnership, reanchor,
      canonicalize, migrate-paths rewriters). Traces FR-1.
- [ ] T002. [behavior: U1] Traces migration with a SIGNATURE row
      invalidates reuse: gen regenerates the pair, the test carries the
      declared outcome assertion, no guard-only marker/warning.
      Traces FR-2 / AS-1 / SC-001.
- [ ] T003. [behavior: U2] Traces migration with a NO-SIGNATURE row
      (the issue's shape) invalidates reuse even when the rendered
      bytes are identical; a following gen reuses again (fingerprint
      refreshed). Traces FR-2 / AS-2.
- [ ] T004. [behavior: U3] Drift + progressed subject refuses reuse:
      exit 1, verdict refused, `--> fix: zfa tdd reset <feature>`.
      Traces FR-3 / AS-3.
- [ ] T005. [behavior: U5] Drift fires once per change: after a
      drift-driven regeneration the next gen is `reused`.
      Traces FR-2 / AS-4.
- [ ] T006. [behavior: U6] Unchanged routing and legacy records keep
      byte-identical reuse (no fingerprint / equal fingerprint).
      Traces FR-4 / FR-5 / AS-5.
- [ ] T007. Wire the gate into gen `_generate` (created records arm the
      fingerprint; reused path gates on drift; forced re-render skips
      only the byte-equality short-circuit; refusal follows the house
      verdict pattern). Traces FR-2/FR-3 (implementation of T002–T004).
- [ ] T008. Non-behavioural: `dart analyze` clean on touched files,
      `dart format` on touched files, touched-area suites green
      (gen_command, artifact_registry, migrate_paths, bug_1320,
      bug_1377, issue_1309, issue_1518). Traces SC-002.
