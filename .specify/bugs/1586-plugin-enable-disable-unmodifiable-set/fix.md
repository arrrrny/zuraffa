# Fix: `zfa plugin enable`/`disable` — copy the disabled set at the ownership boundary (#1586)

- **Slug**: 1586-plugin-enable-disable-unmodifiable-set
- **Files changed**:
  - `lib/src/cli/plugin_loader.dart` — `PluginConfig` now OWNS a mutable
    copy of the disabled set taken at its constructor
    (`Set.of(disabled ?? const <String>{})`), and `save()` returns
    `Future<void>` that completes only after the bytes are durably
    written.
  - `lib/src/commands/plugin_command.dart` — the `enable`/`disable` arm
    awaits `config.save()` (one-line await discipline fix; the mutation
    lines themselves are untouched).
  - `test/commands/bug_1586_plugin_enable_disable_unmodifiable_set_test.dart`
    — new: the five red→green pins (A-1586-1 … A-1586-5, see `test.md`).
- **Unchanged (byte-identical to master)**: `lib/src/config/zfa_config.dart`
  (the `Set.unmodifiable` snapshot contract, `fromJson`/`toJson`, the
  save pipeline via `FileUtils.writeFile`), `plugin_registry.dart` /
  `PluginLoader.buildRegistry()` / `listPlugins()` (read-only consumers),
  the config file format.

## Change 1 — ownership: `PluginConfig` owns a mutable copy (the issue's minimal fix)

```dart
// BEFORE (plugin_loader.dart:44)
PluginConfig({Set<String>? disabled}) : disabled = disabled ?? {};

// AFTER
PluginConfig({Set<String>? disabled})
  : disabled = Set.of(disabled ?? const <String>{});
```

`Set.of` copies into a fresh growable `LinkedHashSet` at the single
point where the set changes ownership (config snapshot → `PluginConfig`).
This kills BOTH failure directions of the aliasing:

- the reported crash: mutating the copy can no longer hit the
  `ZfaConfig` snapshot's `_UnmodifiableSetMixin` view;
- the inverse leak: a caller passing their own set can no longer be
  mutated through the config (pinned by A-1586-4).

`PluginConfig.load()` needs no edit — it feeds the constructor, the
boundary does the copy.

## Change 2 — durability: the save is awaited (Class B, same bug's Expected clause)

```dart
// BEFORE (plugin_loader.dart)
void save({String? projectRoot}) {
  ...
  ZfaConfig.save(updated, projectRoot: root);   // Future dropped
}

// AFTER
Future<void> save({String? projectRoot}) async {
  ...
  await ZfaConfig.save(updated, projectRoot: root);
}
```

```dart
// plugin_command.dart:55-58
await config.save();   // was: config.save();
```

Why this is in-scope and why it is NOT a "save logic" change: the save
PIPELINE (load existing → `copyWith(disabledPlugins:)` → `ZfaConfig.save`
→ `FileUtils.writeFile`) and the file format are byte-identical. What
changed is the await discipline of its caller. Without it the fix for
the reported crash produces a WORSE bug: the mutation succeeds, the
command prints `Enabled plugin: state`, exits 0 — and `_runDispatched`'s
`_exit(exitCode)` (`cli_runner.dart:397-398`) kills the in-flight write
before the bytes land, silently losing every enable/disable (verified
empirically against the compiled binary: `.zfa.json` unchanged after a
"successful" disable). `await`ing matches the established pattern one
door down (`config_command.dart:90`) and satisfies the issue's Expected
clause "saves `.zfa.json`". The `void → Future<void>` signature change
is source-compatible for any un-awaited call site (the only production
caller is `plugin_command.dart`; audited).

## Why not fix it in `plugin_command.dart` instead

Replacing the in-place mutation with a copy-at-mutator
(`config.disabled = {...}..remove(id)` — impossible today, the field is
`final`) or rebuilding the config inside the command would push the
ownership knowledge to every future mutator. The constructor boundary is
the single choke point through which ALL disabled sets enter
`PluginConfig` (via `load()`, via direct construction in tests, via
`PluginManager`), so the copy there is total by construction — and it
is the exact fix shape the issue prescribes.

## Constraint audit

- **"Fix ONLY the set mutability in `PluginConfig`"** — Change 1 is
  exactly that; Change 2 is the await discipline of `PluginConfig.save`'s
  caller, required by the issue's own Expected clause and verified as a
  silent state loss without it (documented in `assessment.md` §Class B).
- **Config format** — unchanged, `toJson` untouched.
- **Save logic** — pipeline and format unchanged; only awaited.
- **Registry builder** — untouched (`buildRegistry`/`listPlugins` only read).
- **`dart analyze`** — no issues on both changed lib files and the new
  test file.
