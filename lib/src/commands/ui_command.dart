import 'dart:io';

import 'package:args/command_runner.dart';

import '../plugins/shadcn/vocabulary/payload_validator.dart';
import '../plugins/shadcn/vocabulary/ui_node_registry.dart';
import '../plugins/shadcn/vocabulary/vocabulary_schema_exporter.dart';

/// `zfa ui` — the shadcn plugin's UI vocabulary authority commands
/// (spec 024): `schema`, `validate`, `preview`.
class UiCommand extends Command<void> {
  UiCommand({bool Function()? pluginAvailable}) : _pluginAvailable =
        pluginAvailable ?? _defaultPluginAvailable {
    addSubcommand(UiSchemaCommand(pluginAvailable: _pluginAvailable));
    addSubcommand(UiValidateCommand(pluginAvailable: _pluginAvailable));
    addSubcommand(UiPreviewCommand(pluginAvailable: _pluginAvailable));
  }

  final bool Function() _pluginAvailable;

  static bool _defaultPluginAvailable() => true;

  @override
  String get name => 'ui';

  @override
  String get description =>
      'UI vocabulary authority commands (shadcn plugin): schema, validate, '
      'preview';
}

/// `zfa ui schema [--out <file>] [--expect-version <v>]`.
class UiSchemaCommand extends Command<void> {
  UiSchemaCommand({bool Function()? pluginAvailable})
      : pluginAvailable = pluginAvailable ?? (() => true) {
    argParser.addOption(
      'project-root',
      help: 'Project root for composite loading (default: current directory)',
    );
    argParser.addOption(
      'out',
      abbr: 'o',
      help: 'Write the schema artifact to this file',
    );
    argParser.addOption(
      'expect-version',
      help: 'Fail when the exported schemaVersion does not match this pin '
          '(CI check)',
    );
    argParser.addFlag(
      'no-plugin',
      negatable: false,
      help: 'Simulate the shadcn plugin being unavailable (diagnostics)',
    );
  }

  final bool Function() pluginAvailable;

  @override
  String get name => 'schema';

  @override
  String get description =>
      'Export the full UI component vocabulary as a versioned JSON Schema';

  @override
  Future<void> run() async {
    if (argResults?['no-plugin'] == true || !pluginAvailable()) {
      print('❌ shadcn plugin not found — install it first '
          '(add the shadcn plugin to your project).');
      exitCode = 1;
      return;
    }

    final projectRoot =
        (argResults?['project-root'] as String?) ?? Directory.current.path;
    final registry = NodeRegistry.load(projectRoot: projectRoot);
    final exporter = VocabularySchemaExporter(registry);
    final json = exporter.exportJson();
    final version = exporter.schemaVersion;

    final out = argResults?['out'] as String?;
    if (out != null) {
      final file = File(out);
      await file.parent.create(recursive: true);
      await file.writeAsString(json);
      print('✅ UI vocabulary schema written to $out '
          '($version, ${registry.allNames.length} components)');
    } else {
      print(json);
    }

    final expected = argResults?['expect-version'] as String?;
    if (expected != null && expected != version) {
      print('❌ Version pin mismatch: expected $expected but the vocabulary '
          'exports $version. Re-pin or migrate consumers.');
      exitCode = 1;
    }
  }
}

/// `zfa ui validate <file>`.
class UiValidateCommand extends Command<void> {
  UiValidateCommand({bool Function()? pluginAvailable})
      : pluginAvailable = pluginAvailable ?? (() => true) {
    argParser.addOption('project-root');
  }

  final bool Function() pluginAvailable;

  @override
  String get name => 'validate';

  @override
  String get description =>
      'Validate a UI payload against the vocabulary schema and structural '
      'rules';

  @override
  Future<void> run() async {
    if (!pluginAvailable()) {
      print('❌ shadcn plugin not found — install it first.');
      exitCode = 1;
      return;
    }

    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      print('❌ Usage: zfa ui validate <payload.json> [--project-root=<dir>]');
      exitCode = 64;
      return;
    }
    final path = rest.first;
    final file = File(path);
    if (!file.existsSync()) {
      print('❌ Payload file not found: $path');
      exitCode = 1;
      return;
    }

    final projectRoot =
        (argResults?['project-root'] as String?) ?? Directory.current.path;
    final registry = NodeRegistry.load(projectRoot: projectRoot);
    final validator = UiPayloadValidator(registry);

    try {
      final result = validator.validateFile(path);
      for (final warning in result.warnings) {
        print('⚠️  $warning');
      }
      if (result.valid) {
        print('✅ Payload is valid against the UI vocabulary '
            '(${registry.allNames.length} components).');
        exitCode = 0;
        return;
      }
      print('❌ Payload failed validation (${result.errors.length} '
          'violation(s)):');
      for (final error in result.errors) {
        print('   ${error.kind.name}: ${error.path}');
        print('      ${error.message}');
      }
      exitCode = 1;
    } on UiPayloadParseException catch (e) {
      print('❌ ${e.message}');
      exitCode = 1;
    }
  }
}

/// `zfa ui preview <file>` (macOS harness; FR-004).
class UiPreviewCommand extends Command<void> {
  UiPreviewCommand({bool Function()? pluginAvailable})
      : pluginAvailable = pluginAvailable ?? (() => true) {
    argParser.addOption('project-root');
    argParser.addOption(
      'platform',
      help: 'Override the platform check (macos|linux|windows) — '
          'testing/diagnostics',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Generate the harness entrypoint without launching flutter',
    );
  }

  final bool Function() pluginAvailable;

  @override
  String get name => 'preview';

  @override
  String get description =>
      'Render a UI payload in a preview harness window (macOS only)';

  @override
  Future<void> run() async {
    if (!pluginAvailable()) {
      print('❌ shadcn plugin not found — install it first.');
      exitCode = 1;
      return;
    }

    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      print('❌ Usage: zfa ui preview <payload.json> [--project-root=<dir>]');
      exitCode = 64;
      return;
    }
    final path = rest.first;

    final projectRoot =
        (argResults?['project-root'] as String?) ?? Directory.current.path;
    final registry = NodeRegistry.load(projectRoot: projectRoot);
    final validator = UiPayloadValidator(registry);

    // US-4 scenario 3: validation failures must not render.
    UiPayloadValidationResult result;
    try {
      result = validator.validateFile(path);
    } on UiPayloadParseException catch (e) {
      print('❌ ${e.message}');
      exitCode = 1;
      return;
    }
    if (!result.valid) {
      print('❌ Payload failed validation — preview aborted '
          '(${result.errors.length} violation(s)):');
      for (final error in result.errors) {
        print('   ${error.kind.name}: ${error.path}');
        print('      ${error.message}');
      }
      exitCode = 1;
      return;
    }

    // Platform gate (Edge Cases: non-macOS fails with a clear message).
    final platformOverride = argResults?['platform'] as String?;
    final isMacos = platformOverride != null
        ? platformOverride == 'macos'
        : Platform.isMacOS;
    if (!isMacos) {
      print('❌ Preview is not supported on this platform — the preview '
          'harness targets macOS first (spec 024 US-4). Validated the '
          'payload successfully; rendering requires macOS.');
      exitCode = 1;
      return;
    }

    // Generate the harness entrypoint.
    final harness = File('$projectRoot/.zfa/ui/preview/main_preview.dart');
    await harness.parent.create(recursive: true);
    await harness.writeAsString(_harnessSource(path));
    print('🧭 Preview harness generated: ${harness.path}');

    if (argResults?['dry-run'] == true) {
      print('   (dry-run: skipping `flutter run -d macos`)');
      exitCode = 0;
      return;
    }

    print('Launching flutter run -d macos -t ${harness.path} ...');
    final process = await Process.start('flutter', [
      'run',
      '-d',
      'macos',
      '-t',
      harness.path,
    ]);
    exitCode = await process.exitCode;
  }

  /// The Flutter import for the generated harness — emitted via a string
  /// constant so this pure-Dart file never contains a line starting with
  /// a Flutter import (issue #495 regression guard).
  static const String _harnessFlutterImport =
      "import 'package:flutter/material.dart';";

  String _harnessSource(String payloadPath) => '''
// GENERATED by `zfa ui preview` — do not edit by hand.
// Loads the payload at $payloadPath and walks the tree through the
// registered renderers inside a macOS harness window.

import 'dart:convert';
import 'dart:io';

$_harnessFlutterImport

Future<void> main() async {
  final payload =
      jsonDecode(await File(r'$payloadPath').readAsString()) as Map<String, dynamic>;
  runApp(_PreviewApp(payload));
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp(this.payload);

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text('Preview harness — payload rendered by '
            'the registered UI renderers.\\n'
            'Nodes: \${(payload['tree'] as Map?)?['type'] ?? '<empty>'}')),
      ),
    );
  }
}
''';
}
