# Bug Issue: zfa mock data source does not persist creates/updates/deletes

- **Slug**: issue-463-mock-datasource-no-persist
- **Fetched**: 2026-08-23T11:49:39.475676+00:00
- **Issue**: 463
- **URL**: https://github.com/arrrrny/zuraffa/issues/463
- **State**: open
- **Severity**: high
- **Author**: arrrrny
- **Labels**: bug

## Body

## Symptom

The zuraffa-generated `TaskMockDataSource` (produced by `zfa make Task --mock`) implements the `TaskDataSource` interface. Its `get` and `getList` methods correctly read from the static `TaskMockData.tasks` fixture list. However, its `create`, `update`, and `delete` methods **do not mutate** that list — they return the item (or void) without adding/updating/removing entries from `TaskMockData.tasks`. This means a task submitted via `CreateTaskUseCase` cannot be retrieved via `GetTaskUseCase` afterward, breaking the core submit→get lifecycle required by the mock-first mandate (constitution VII).

## Reproduction

1. Run `zfa init --dart --deps-only` in a pure-Dart package
2. Create an entity: `zfa entity create -n Task --auto-id --field spec:String --field status:String`
3. Generate CRUD with mock: `zfa make Task --preset=crud --mock --di --use-mock --methods=get,getList,create,update,delete`
4. Run `zfa build`
5. Write a test that:
   - Calls `CreateTaskUseCase.execute(task)` 
   - Then calls `GetTaskUseCase.execute(QueryParams(filter: Eq(TaskFields.id, task.id)))`
6. Observe that `GetTaskUseCase` throws `StateError: Bad state: No element` because the created task was never added to `TaskMockData.tasks`

## Suspected Code Paths

- `/workspace/zuraffa/lib/src/plugins/mock/builders/mock_datasource_builder.dart` — the template that generates `MockDataSource` classes. The `create`/`update`/`delete` method bodies (lines ~303-370) return the item without mutating the backing store.
- `/workspace/zuraffa/lib/src/plugins/mock/builders/mock_data_builder.dart` — generates `MockData.tasks` static fixture list (read-only).
- Generated output: `lib/src/data/datasources/task/task_mock_datasource.dart` in any project using `zfa make --mock`.

## Root Cause Hypothesis

**Confidence: high**. The mock datasource template in `mock_datasource_builder.dart` generates `create`/`update`/`delete` methods that simulate latency and logging but **never mutate** `TaskMockData.tasks`. The template assumes the mock data is a read-only fixture, not a working in-memory store. This contradicts the documentation claim that `zfa mock` produces "a genuine in-memory implementation of the DataSource interface with get/getList/create/update/toggle/delete/watch" — the mutation operations are stubbed.

## Severity

high

## Assessment

Assessment: .specify/bugs/zfa-mock-datasource-not-persisting/assessment.md


## Comments

None.
