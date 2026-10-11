# Tasks: cycle-log-phantom-sections

Bug fix tracked as https://github.com/arrrrny/zuraffa/issues/1467.
Test list: ./tdd/test-list.md (5 acceptance behaviors A1–A5).

## Mandatory test tasks (MUST run before implementation)

- [ ] T001 Write failing acceptance test for A1 [behavior: A1] — in-fence `## ` lines do NOT start new sections
- [ ] T002 Write failing acceptance test for A2 [behavior: A2] — fence state stays synchronized (info-string fences)
- [ ] T003 Write failing acceptance test for A3 [behavior: A3] — clean logs parse identical to legacy split
- [ ] T004 Write failing acceptance test for A4 [behavior: A4] — all 9 reader sites route through the shared splitter
- [ ] T005 Write failing acceptance test for A5 [behavior: A5] — parseEntries yields exactly one entry with id/kind/hash

## Implementation tasks

- [ ] T006 Add shared fence-aware `splitCycleLogSections` helper (new lib/src/plugins/tdd/services/cycle_log_sections.dart)
- [ ] T007 Adopt the helper at all 9 naive `split('\n## ')` reader sites (cycle_evidence ×2, verify_red, make ×2, compose ×2, era_tagged_log, theater_data, replay_history)
