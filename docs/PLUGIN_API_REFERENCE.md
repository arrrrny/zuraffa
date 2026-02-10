# Plugin API Reference

This reference lists the public plugin system APIs used by generation plugins.

## ZuraffaPlugin

Location: `lib/src/core/plugin_system/plugin_interface.dart`

Required properties:

- `String get id`
- `String get name`
- `String get version`

Optional properties:

- `int get order`

Lifecycle methods:

- `Future<ValidationResult> validate(GeneratorConfig config)`
- `Future<void> beforeGenerate(GeneratorConfig config)`
- `Future<void> afterGenerate(GeneratorConfig config)`
- `Future<void> onError(GeneratorConfig config, Object error, StackTrace stackTrace)`

## FileGeneratorPlugin

Location: `lib/src/core/plugin_system/plugin_interface.dart`

Method:

- `Future<List<GeneratedFile>> generate(GeneratorConfig config)`

## ValidationResult

Location: `lib/src/core/plugin_system/plugin_lifecycle.dart`

Factory methods:

- `ValidationResult.success([String? message])`
- `ValidationResult.failure(List<String> reasons, [String? message])`

Methods:

- `ValidationResult merge(ValidationResult other)`

Fields:

- `bool isValid`
- `String? message`
- `List<String> reasons`

## PluginRegistry

Location: `lib/src/core/plugin_system/plugin_registry.dart`

Key methods:

- `void register(ZuraffaPlugin plugin)`
- `void registerAll(Iterable<ZuraffaPlugin> plugins)`
- `void discover(Iterable<ZuraffaPluginFactory> factories)`
- `ZuraffaPlugin? getById(String id)`
- `List<T> ofType<T extends ZuraffaPlugin>()`
- `Future<ValidationResult> validateAll(GeneratorConfig config)`
- `Future<void> beforeGenerateAll(GeneratorConfig config)`
- `Future<void> afterGenerateAll(GeneratorConfig config)`
- `Future<void> onErrorAll(GeneratorConfig config, Object error, StackTrace stackTrace)`

## GeneratedFile

Location: `lib/src/models/generated_file.dart`

Fields:

- `String path`
- `String type`
- `String action`
- `String? content`

## FileUtils

Location: `lib/src/utils/file_utils.dart`

Methods:

- `Future<GeneratedFile> writeFile(String filePath, String content, String type, {bool force = false, bool dryRun = false, bool verbose = false})`
- `Future<GeneratedFile> deleteFile(String filePath, String type, {bool dryRun = false, bool verbose = false})`

## AppendExecutor

Location: `lib/src/core/ast/append_executor.dart`

Method:

- `AppendResult execute(AppendRequest request)`

## AppendRequest

Location: `lib/src/core/ast/strategies/append_strategy.dart`

Factory constructors:

- `AppendRequest.method({required String source, required String className, required String memberSource})`
- `AppendRequest.field({required String source, required String className, required String memberSource})`
- `AppendRequest.extensionMethod({required String source, required String className, required String memberSource})`
- `AppendRequest.functionStatement({required String source, required String functionName, required String memberSource})`
- `AppendRequest.export({required String source, required String exportPath})`
- `AppendRequest.import({required String source, required String importPath})`

## AppendResult

Location: `lib/src/core/ast/strategies/append_strategy.dart`

Fields:

- `String source`
- `bool changed`
- `String? message`
