# Test List: 001-todo-app

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | create entity Todo with id, title, description, isCompleted, priority, tags, createdAt, completedAt. | AC-1 | PENDING |
| A2 | create entity TodoStats with total, active, completed. | AC-2 | PENDING |
| A3 | the status line formatter returns a non-empty string. | AC-3 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The default priority returns 1 when a todo is created without an explicit priority. | FR-001 | PENDING |
| U2 | The maximum title length returns 120 when a title is validated. | FR-002 | PENDING |
| U3 | The priority label formatter returns a non-empty string for every priority level. | FR-003 | PENDING |
| U4 | The overdue tag collector returns a list of tag names. | FR-004 | PENDING |
| U5 | The completion ratio compute returns 0 when the todo list is empty. | FR-005 | PENDING |
| U6 | The persistence flag returns true when the journal is clean. | FR-006 | PENDING |

