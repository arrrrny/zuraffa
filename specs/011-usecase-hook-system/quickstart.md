# Quickstart & Validation Guide: UseCase Hook System

This guide outlines the prerequisites and runnable validation scenarios to verify the UseCase Hook System.

## Prerequisites

1. Zuraffa development environment set up (Dart ^3.11.0, Flutter >=3.41.0).
2. For TelemetryHook validation: an OTLP collector endpoint (or use a mock).
3. For EngagementHook validation: the ZikZak project with its existing `EngagementEventRepository` and raptorr backend running.
4. Git branch switched to `011-usecase-hook-system`.

## Scenario 1: Basic Hook Registration & Dispatch

### Steps
1. Create a test hook that records every dispatch in a list.
2. Register it via `HookRegistry.instance.register(TestHook())`.
3. Execute a simple UseCase (e.g., a `GetProductUseCase` mock).
4. Verify the hook fired twice: once for `pre` and once for `success`.

### Expected Outcome
- The hook's `execute()` was called with `HookPhase.pre` before `execute()` ran.
- The hook's `execute()` was called with `HookPhase.success` after `execute()` completed.
- `context.useCaseName` matches the UseCase runtime type.
- `context.params` matches the input passed to the UseCase.
- `context.result` is populated in the `success` phase.
- `context.duration` is non-null in the `success` phase.

## Scenario 2: Hook Failure Isolation

### Steps
1. Create a hook that throws an exception in `execute()`.
2. Create a second hook that records dispatches normally.
3. Register both.
4. Execute a UseCase.

### Expected Outcome
- The UseCase completes successfully — the throwing hook did NOT affect the result.
- The second hook still fired normally — the first hook's error did not prevent it.
- A warning was logged by `HookRegistry` about the throwing hook's error.

## Scenario 3: TelemetryHook Auto-Tracing

### Steps
1. Configure OTel reporting: `await Zuraffa.enableOtelReporting(...)`.
2. Register `TelemetryHook()`.
3. Execute a UseCase.
4. Check the OTLP collector for a span named `usecase.{UseCaseName}`.

### Expected Outcome
- A span exists with status OK (on success) or ERROR (on failure).
- The span has `usecase.duration_ms` attribute with the execution time.
- The span has `usecase.name` attribute matching the UseCase type.

## Scenario 4: TelemetryHook Filtering

### Steps
1. Register `TelemetryHook(onlyUseCases: {'GetDealListUseCase'})`.
2. Execute `GetDealListUseCase`.
3. Execute `CreateBarcodeScanUseCase`.
4. Check spans.

### Expected Outcome
- A span exists for `GetDealListUseCase`.
- NO span exists for `CreateBarcodeScanUseCase` (filtered out by whitelist).

## Scenario 5: Global Kill Switch

### Steps
1. Register a hook.
2. Set `Zuraffa.hooksEnabled = false`.
3. Execute a UseCase.
4. Set `Zuraffa.hooksEnabled = true`.
5. Execute another UseCase.

### Expected Outcome
- When disabled, the hook does NOT fire.
- When re-enabled, the hook fires normally.

## Scenario 6: ZikZak EngagementHook (End-to-End Validation)

### Steps
1. In ZikZak's `main()`, register:
   ```dart
   Zuraffa.registerHook(EngagementHook(getIt<EngagementEventRepository>()));
   ```
2. Remove all `trackXxx()` calls from controllers and all `CreateTelemetryEventUseCase` invocations.
3. Trigger a barcode scan from the ZikZak app.
4. Check the local Hive box (`engagement_events`) for a new event.

### Expected Outcome
- An `EngagementEvent` with `eventType=BARCODE_SCAN` and `payload` matching the scanned barcode is stored in Hive.
- The event has `isSynced=false` initially.
- Zero `trackBarcodeScanned()` calls exist in any controller.
- Zero `CreateTelemetryEventUseCase` imports exist in any controller.

## Run Validation Tests

```bash
# Unit tests for hook registry
flutter test test/core/hook_registry_test.dart

# Unit tests for telemetry hook
flutter test test/core/telemetry_hook_test.dart

# Integration test: UseCase dispatches to hooks
flutter test test/domain/usecase_hook_test.dart

# Integration test: StreamUseCase dispatches to hooks
flutter test test/domain/stream_usecase_hook_test.dart
```
