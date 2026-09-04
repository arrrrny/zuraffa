# TDD Verification — feature `073-slice-isolation`

Generated fresh by `zfa tdd verify --feature 073-slice-isolation`.

## Gate

- gate: `not_assessed`
- not_assessed_reason: mutation config error: MutationConfigError: mutation_test exited with code -15 and produced no report. Stderr: 

## Mutation buckets (FR-014)

- killed: 0
- survived: 0
- timed_out: 0

## Behavior scope (FR-018)

- `A2` — traces: `AC-2`
- `A4` — traces: `AC-4`
- `A5` — traces: `AC-5`
- `A6` — traces: `AC-6`
- `A7` — traces: `AC-7`
- `A8` — traces: `AC-8`
- `A9` — traces: `AC-9`
- `A10` — traces: `AC-10`
- `A11` — traces: `AC-11`
- `A12` — traces: `AC-12`
- `A13` — traces: `AC-13`
- `A14` — traces: `AC-14`
- `A1` — traces: `AC-1`
- `A3` — traces: `AC-3`
- `U1` — traces: `FR-001`
- `U2` — traces: `FR-002`
- `U3` — traces: `FR-003`
- `U4` — traces: `FR-004`
- `U5` — traces: `FR-005`
- `U6` — traces: `FR-006`
- `U7` — traces: `FR-007`
- `U8` — traces: `FR-008`

## Restoration (FR-021)

- restoration_verified: true
- restoration_scope_count: 22
- restoration_scope (subjects only, never tests):
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a10_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a11_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a12_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a13_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a14_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a1_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a2_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a3_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a4_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a5_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a6_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a7_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a8_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a9_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u1_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u2_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u3_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u4_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u5_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u6_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u7_subject.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u8_subject.dart`

## Repro diagnostics (FR-020, non-sensitive)

- runner_command: `dart run mutation_test`
- preflight_scope_ran (bug #924, per-behavior):
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a10_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a11_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a12_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a13_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a14_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a1_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a2_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a3_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a4_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a5_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a6_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a7_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a8_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/a9_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/u1_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/u2_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/u3_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/u4_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/u5_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/u6_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/u7_test.dart`
  - `/workspace/zuraffa/.worktrees/073-slice-isolation/test/tdd/073-slice-isolation/u8_test.dart`

## Mutation run

- mutation_was_run: false

## Evidence binding (bug #837)

- spec_hash: e5048d78781b91b126947f0dfc956efe1a3a368eff234b36ede81cc2dbb383b6
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a10_subject.dart` 190bec2912dba39e1bc1a60fc06ef990b13fa1be4b3816f3cb17061e0a5353c5
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a11_subject.dart` bcbe3e66b698da9e7d08166bb431812d8711330aa597b5bde134f7b68722249a
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a12_subject.dart` 2d3c4af36ba44a350e98b2985bec6dabb9fcf5a73692a3c72c3fba70fb7b318b
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a13_subject.dart` eb7fa4ea5a4d2e1ecbe0eefd39c6a7d39316389f12966b1a427281ad771f0724
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a14_subject.dart` 5ebc67af8db87d4858dc20ad369c7933ad0348a107d69117a272d4a93c87f042
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a1_subject.dart` c814c0d2e001800fcf84e59bb18463a52fa2156dc76fc4e27627886bb47ca2d1
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a2_subject.dart` 5cf926f486f4a80de2fb51b1f6bdaa1ac1858e748c58ae7086acbbbbfb0aa180
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a3_subject.dart` 47d4db4893026ecb15fffb1a1c972c98aa2dff3e6f8c2048184fd6e8158b1fee
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a4_subject.dart` 0624197eaa3cc094193f5930474092eccc6bfc4e4e82c2dec443f0dad2347db4
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a5_subject.dart` 385fe8a084a63681611a1bc748e0b7e3d379997d8b948412e3f4f7dc7d7a6361
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a6_subject.dart` e99402164138df117702ea5333c4fc374b3907e5b59a914c8dd56ec5514882b0
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a7_subject.dart` 0f2489157141e300a31d4c451165336d6d8949245358bdb5db14055cee34f7b7
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a8_subject.dart` 4eff596a4a4a21e167a92b572fda50e9a773d02bb8cd10a8f2ff2ab220421e75
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/a9_subject.dart` f9d1189e260c167128cf39177de1b1370776994ac1eea6a5251cf0386f326149
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u1_subject.dart` c0ff833767c1fa437231dfffb931b6069163b2ac3a61e527fa82f76fa3384277
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u2_subject.dart` c952a31f2e9bd8c56e207cb4da7cff3c5d816351b863842f2881cd41ed8098b8
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u3_subject.dart` c8bba57445e456453870550bfd35ae579c0df795e1490a3dbe55fb9e641f6734
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u4_subject.dart` fe17fa8056ae5e017368233c388bafd0c7e54168dd987e4698ee2ebfd3db80d6
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u5_subject.dart` c4b91a39a552c06f843469969ca533b0a2d1674c7198479ce7e672a7f48ab198
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u6_subject.dart` 4ca0291dc49147f5e26cb29e3572b38f40f524ee589a9ab625041c4e865b5e7d
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u7_subject.dart` 17d47e4e5de931625d8705bff4d7227029b0ff139172ac9a7e87c858dc68fcb6
- subject_hash: `/workspace/zuraffa/.worktrees/073-slice-isolation/lib/tdd/073-slice-isolation/u8_subject.dart` ca391e41bab87faf284630a7fb39b16117d7394fd7370574c7af74d55b18fff7
