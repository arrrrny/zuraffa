# Bug Issue: zfa entity sealed: generates subtypes as separate libraries implementing sealed class → invalid_use_of_type_outside_library

- **Slug**: issue-416-zfa-entity-sealed-generates-subtypes-as-separate-libraries-i
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 416
- **URL**: https://github.com/arrrrny/zuraffa/issues/416
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

**Bug**: `zfa entity create --sealed --generate-subs` emits each subtype as a standalone library `implements sealed EngineEvent` outside its library → 9× `invalid_use_of_type_outside_library`.

**Reproduction**:
1. `zfa entity create -n EngineEvent --sealed --fields "id:String,missionId:String" --subtypes "MissionStarted,MissionCompleted,TurnStarted,TurnCompleted,ThinkingDelta,ToolCallStarted,ToolCallCompleted,ProviderError,SteeringInjected" --generate-subs`
2. Each subtype file has `class MissionStarted implements EngineEvent { ... }` but `EngineEvent` is in a different library (sealed) → illegal in Dart.

**Expected**: Subtypes of a sealed class must be in the same library. Either:
- Generate all subtypes in the same file as the sealed class, OR
- Use `part of` directives, OR
- Don't `implements` the sealed class for external subtypes.

**Files**: `lib/src/commands/entity_command.dart` or Zorphy sealed class generation.


## Comments

None.
