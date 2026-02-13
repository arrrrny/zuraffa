---
title: "PR #56 - Request for Changes: Generation Context Implementation"
date: "2026-02-09"
status: "changes_requested"
pr: "56"
---

# Request for Changes: PR #56 Generation Context

## Summary

PR #56 implements a partial `GenerationContext` but is **missing critical functionality** required by the acceptance criteria. The implementation only contains basic config + flags, but lacks the file system abstraction, context store for plugin data sharing, and progress reporting hooks.

---

## Current State

### Files Created (Partial)

| File | Location | Status |
|------|----------|--------|
| `generation_context.dart` | `lib/src/core/generation/` | Incomplete |
| `generation_context_test.dart` | `test/core/generation/` | Minimal |

### Files Missing

| File | Required For |
|------|--------------|
| `lib/src/core/context/file_system.dart` | File system abstraction |
| `lib/src/core/context/context_store.dart` | Plugin data sharing |
| `lib/src/core/context/progress_reporter.dart` | CLI/UI progress |

---

## Acceptance Criteria Gap Analysis

### ✅ CRITERION 1: GenerationContext contains GeneratorConfig
**Status: PASSED** ✓

```dart
class GenerationContext {
  final GeneratorConfig config;
  // ✓ Present
}
```

---

### ❌ CRITERION 2: Context provides file system abstraction
**Status: FAILED** ✗

**Required:** An abstraction layer that plugins can use for file operations instead of direct `dart:io` imports.

**Expected Implementation:**

**`lib/src/core/context/file_system.dart`**
```dart
import 'dart:async';

abstract class FileSystem {
  factory FileSystem.default({String? root}) = DefaultFileSystem;

  Future<String> read(String path);
  Future<void> write(String path, String content);
  Future<void> delete(String path);
  Future<bool> exists(String path);
  Future<void> createDir(String path, {bool recursive = false});
  Stream<String> watch(String path);
}

class DefaultFileSystem implements FileSystem {
  final String? root;

  DefaultFileSystem({this.root});

  String _resolve(String path) {
    return root != null ? '$root/$path' : path;
  }

  @override
  Future<String> read(String path) async {
    return File(_resolve(path)).readAsString();
  }

  @override
  Future<void> write(String path, String content) async {
    final file = File(_resolve(path));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  @override
  Future<void> delete(String path) async {
    final file = File(_resolve(path));
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<bool> exists(String path) async {
    return File(_resolve(path)).exists();
  }

  @override
  Future<void> createDir(String path, {bool recursive = false}) async {
    await Directory(_resolve(path)).create(recursive: recursive);
  }

  @override
  Stream<String> watch(String path) {
    final file = File(_resolve(path));
    return file.watch().map((_) => path);
  }
}
```

**Requirements:**
- [ ] Define `FileSystem` abstract class with async I/O methods
- [ ] Implement `DefaultFileSystem` for direct file access
- [ ] Support optional `root` prefix for output directory
- [ ] Add `watch()` method for file system events
- [ ] Add tests for all operations

**Tests to Add (`test/core/context/file_system_test.dart`):**
```dart
void main() {
  group('FileSystem', () {
    test('reads file content', () async {
      // Setup temp file, test read
    });

    test('writes file with directories', () async {
      // Test nested path creation
    });

    test('checks file existence', () async {
      // Test true/false cases
    });

    test('deletes existing file', () async {
      // Verify deletion
    });
  });
}
```

---

### ❌ CRITERION 3: Plugins can share data via context.store
**Status: FAILED** ✗

**Required:** A key-value store for plugins to share data during generation.

**Expected Implementation:**

**`lib/src/core/context/context_store.dart`**
```dart
class ContextStore {
  final Map<String, dynamic> _data = {};
  final Map<String, Set<VoidCallback>> _listeners = {};

  T get<T>(String key, {T Function()? defaultValue}) {
    final value = _data[key];
    if (value != null && value is T) {
      return value;
    }
    return defaultValue?.call() ?? (throw StateError('Key not found: $key'));
  }

  T? getOrNull<T>(String key) {
    final value = _data[key];
    if (value != null && value is T) {
      return value;
    }
    return null;
  }

  void set<T>(String key, T value) {
    final previous = _data[key];
    _data[key] = value;
    _notifyListeners(key, previous, value);
  }

  void remove(String key) {
    final previous = _data[key];
    _data.remove(key);
    _notifyListeners(key, previous, null);
  }

  bool has(String key) => _data.containsKey(key);

  void clear() {
    _data.clear();
    _listeners.clear();
  }

  void addListener(String key, VoidCallback callback) {
    _listeners.putIfAbsent(key, () => Set<VoidCallback>()).add(callback);
  }

  void removeListener(String key, VoidCallback callback) {
    _listeners[key]?.remove(callback);
  }

  void _notifyListeners(String key, dynamic previous, dynamic current) {
    _listeners[key]?.forEach((callback) => callback());
  }

  Map<String, dynamic> toJson() => Map.unmodifiable(_data);
}
```

**Integration with GenerationContext:**
```dart
class GenerationContext {
  final GeneratorConfig config;
  final String outputDir;
  final bool dryRun;
  final bool force;
  final bool verbose;
  final FileSystem fileSystem;
  final ContextStore store;

  const GenerationContext({
    required this.config,
    required this.outputDir,
    required this.dryRun,
    required this.force,
    required this.verbose,
    required this.fileSystem,
    required this.store,
  });

  factory GenerationContext.create({
    required GeneratorConfig config,
    String outputDir = 'lib/src',
    bool dryRun = false,
    bool force = false,
    bool verbose = false,
    String? root,
  }) {
    return GenerationContext(
      config: config,
      outputDir: outputDir,
      dryRun: dryRun,
      force: force,
      verbose: verbose,
      fileSystem: FileSystem.default(root: root),
      store: ContextStore(),
    );
  }
}
```

**Requirements:**
- [ ] Define `ContextStore` class with generic get/set
- [ ] Add type-safe accessors with optional defaults
- [ ] Implement listener/callback support for reactive updates
- [ ] Add `toJson()` for debugging
- [ ] Integrate with `GenerationContext`

**Tests to Add (`test/core/context/context_store_test.dart`):**
```dart
void main() {
  group('ContextStore', () {
    test('stores and retrieves values', () {
      final store = ContextStore();
      store.set('key', 'value');
      expect(store.get<String>('key'), equals('value'));
    });

    test('returns default value when key missing', () {
      final store = ContextStore();
      expect(store.get<String>('missing', defaultValue: () => 'default'), equals('default'));
    });

    test('throws when key missing without default', () {
      final store = ContextStore();
      expect(() => store.get<String>('missing'), throwsStateError);
    });

    test('notifies listeners on change', () {
      // Test listener callback
    });

    test('supports type checking', () {
      final store = ContextStore();
      store.set('number', 42);
      expect(() => store.get<String>('number'), throwsStateError);
    });
  });
}
```

---

### ❌ CRITERION 4: Progress reporting hooks for CLI/UI
**Status: FAILED** ✗

**Required:** A reporter interface for plugins to report progress during generation.

**Expected Implementation:**

**`lib/src/core/context/progress_reporter.dart`**
```dart
import 'dart:async';

enum ProgressEvent {
  started,
  completed,
  failed,
  warning,
  info,
}

class ProgressReport {
  final String message;
  final int percent;
  final String? currentStep;
  final int totalSteps;
  final ProgressEvent event;

  const ProgressReport({
    required this.message,
    required this.percent,
    this.currentStep,
    required this.totalSteps,
    required this.event,
  });

  const ProgressReport.started(String message, int totalSteps)
      : this(
          message: message,
          percent: 0,
          totalSteps: totalSteps,
          event: ProgressEvent.started,
          currentStep: null,
        );

  ProgressReport nextStep(String step)
      => ProgressReport(
        message: message,
        percent: ((totalSteps > 0) ? (int.parse(currentStep ?? '0') + 1) / totalSteps * 100 : 0).round(),
        currentStep: step,
        totalSteps: totalSteps,
        event: ProgressEvent.info,
      );

  const ProgressReport.completed()
      : this(
          message: '',
          percent: 100,
          totalSteps: 0,
          event: ProgressEvent.completed,
          currentStep: null,
        );

  const ProgressReport.failed(String error)
      : this(
          message: error,
          percent: 0,
          totalSteps: 0,
          event: ProgressEvent.failed,
          currentStep: null,
        );
}

abstract class ProgressReporter {
  void report(ProgressReport report);

  void started(String message, int totalSteps);
  void update(String currentStep);
  void completed();
  void failed(String error);
  void warning(String message);
  void info(String message);
}

class NullProgressReporter implements ProgressReporter {
  @override
  void report(ProgressReport report) {}

  @override
  void started(String message, int totalSteps) {}

  @override
  void update(String currentStep) {}

  @override
  void completed() {}

  @override
  void failed(String error) {}

  @override
  void warning(String message) {}

  @override
  void info(String message) {}
}

class CliProgressReporter implements ProgressReporter {
  final bool verbose;
  int _totalSteps = 0;
  String _currentStep = '';
  int _completedSteps = 0;

  CliProgressReporter({this.verbose = false});

  @override
  void report(ProgressReport report) {
    switch (report.event) {
      case ProgressEvent.started:
        _totalSteps = report.totalSteps;
        _completedSteps = 0;
        print('[_] ${report.message}');
        break;
      case ProgressEvent.info:
        if (verbose) {
          print('    → ${report.currentStep}');
        }
        break;
      case ProgressEvent.completed:
        print('[✓] Completed');
        break;
      case ProgressEvent.failed:
        print('[✗] ${report.message}');
        break;
      case ProgressEvent.warning:
        print('[!] ${report.message}');
        break;
    }
  }

  @override
  void started(String message, int totalSteps) {
    report(ProgressReport.started(message, totalSteps));
  }

  @override
  void update(String currentStep) {
    _currentStep = currentStep;
    _completedSteps++;
    final percent = (_totalSteps > 0) ? (_completedSteps / _totalSteps * 100).round() : 0;
    if (!verbose) {
      stdout.write('\r[${'=' * (percent ~/ 10)}>${' ' * (10 - percent ~/ 10)}] $_completedSteps/$_totalSteps ');
      stdout.flush();
    }
  }

  @override
  void completed() {
    report(ProgressReport.completed());
    print('');
  }

  @override
  void failed(String error) {
    report(ProgressReport.failed(error));
  }

  @override
  void warning(String message) {
    report(ProgressReport.warning(message));
  }

  @override
  void info(String message) {
    if (verbose) {
      report(ProgressReport.info(message));
    }
  }
}
```

**Integration with GenerationContext:**
```dart
class GenerationContext {
  // ... existing fields ...

  final ProgressReporter progress;

  const GenerationContext({
    // ... existing fields ...
    required this.fileSystem,
    required this.store,
    required this.progress,
  });

  factory GenerationContext.create({
    // ... existing params ...
    bool verbose = false,
    ProgressReporter? progressReporter,
  }) {
    return GenerationContext(
      // ... existing assignments ...
      fileSystem: FileSystem.default(),
      store: ContextStore(),
      progress: progressReporter ?? (verbose ? CliProgressReporter(verbose: true) : NullProgressReporter()),
    );
  }
}
```

**Requirements:**
- [ ] Define `ProgressReport` class with events (started, info, completed, failed, warning)
- [ ] Define `ProgressReporter` abstract class with convenience methods
- [ ] Implement `NullProgressReporter` for silent operation
- [ ] Implement `CliProgressReporter` with verbose/quiet modes
- [ ] Integrate with `GenerationContext`

**Tests to Add (`test/core/context/progress_reporter_test.dart`):**
```dart
void main() {
  group('ProgressReporter', () {
    test('NullProgressReporter ignores all reports', () {
      final reporter = NullProgressReporter();
      expect(() => reporter.started('test', 5), returnsNormally);
      expect(() => reporter.update('step'), returnsNormally);
      expect(() => reporter.completed(), returnsNormally);
      expect(() => reporter.failed('error'), returnsNormally);
    });

    test('CliProgressReporter formats started message', () {
      // Capture print output, verify format
    });

    test('ProgressReport calculates percentages correctly', () {
      // Test percent calculation in nextStep()
    });
  });
}
```

---

## Required Changes Summary

### New Files to Create

1. **`lib/src/core/context/file_system.dart`**
   - `FileSystem` abstract class
   - `DefaultFileSystem` implementation
   - Tests in `test/core/context/file_system_test.dart`

2. **`lib/src/core/context/context_store.dart`**
   - `ContextStore` class with type-safe get/set
   - Listener support
   - Tests in `test/core/context/context_store_test.dart`

3. **`lib/src/core/context/progress_reporter.dart`**
   - `ProgressReport` class
   - `ProgressReporter` abstract class
   - `NullProgressReporter` implementation
   - `CliProgressReporter` implementation
   - Tests in `test/core/context/progress_reporter_test.dart`

### Files to Modify

1. **`lib/src/core/generation/generation_context.dart`**
   - Add `fileSystem` field
   - Add `store` field
   - Add `progress` field
   - Update factory to initialize all new fields
   - Update existing test to verify new fields

2. **`test/core/generation/generation_context_test.dart`**
   - Update to test new fields
   - Test fileSystem operations through context
   - Test store operations through context
   - Test progress reporter through context

### Directory Structure to Create

```
lib/src/core/context/
├── file_system.dart
├── context_store.dart
└── progress_reporter.dart

test/core/context/
├── file_system_test.dart
├── context_store_test.dart
└── progress_reporter_test.dart
```

---

## Testing Requirements

All new files must have corresponding tests with:
- [ ] Happy path scenarios
- [ ] Error cases
- [ ] Edge cases (empty values, nulls)
- [ ] Type safety verification

Run tests with:
```bash
flutter test test/core/context/
```

Expected: All tests pass with no analyzer issues.

---

## Files to Commit

```
A lib/src/core/context/file_system.dart
A lib/src/core/context/context_store.dart
A lib/src/core/context/progress_reporter.dart
M lib/src/core/generation/generation_context.dart
M test/core/generation/generation_context_test.dart
A test/core/context/file_system_test.dart
A test/core/context/context_store_test.dart
A test/core/context/progress_reporter_test.dart
```

---

## Verification Checklist

After implementing changes:

- [ ] `flutter analyze lib/src/core/context/` - No issues
- [ ] `flutter analyze lib/src/core/generation/generation_context.dart` - No issues
- [ ] `flutter test test/core/context/` - All tests pass
- [ ] `flutter test test/core/generation/generation_context_test.dart` - Passes
- [ ] All acceptance criteria marked ✅ in issue #30

---

## Estimated Hours

| Task | Hours |
|------|-------|
| FileSystem abstraction | 1.5 |
| ContextStore implementation | 1.5 |
| ProgressReporter implementation | 2 |
| Integration tests | 1 |
| **Total** | **6** |

---

## Notes

- This is a foundation layer - all plugins will depend on these abstractions
- Keep implementations simple and focused
- The CLI reporter should work in both verbose and quiet modes
- All async operations should be properly documented
