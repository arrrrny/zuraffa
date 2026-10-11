---
feature: u2-flow
loop: inner
profile: .specify/memory/tdd-profile.md
spec_criteria: 2
planned_at: corpus
updated_at: corpus
---

# Test List: u2 flow

Two unit behaviors, the #744 shape: gen of the SECOND behavior must
complete (the regression hung there on pre-#748 generators).

## Inner loop: unit behaviors

| id | behavior | traces | state |
| --- | --- | --- | --- |
| U1 | the flow entrypoint resolves its first dependency | AC-1 | PENDING |
| U2 | the flow entrypoint resolves its second dependency | AC-2 | PENDING |
