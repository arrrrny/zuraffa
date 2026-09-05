import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as path;
import '../core/project/receipt_store.dart';
import '../models/generated_file.dart';
import '../core/plugin_system/capability.dart';
import '../core/plugin_system/capability_invocation_wrapper.dart';
import '../core/project/project_root.dart';
import '../core/plugin_system/plan_store.dart';
import '../utils/string_utils.dart';
import '../version.dart';

class CapabilityCommand extends Command<void> {
  final ZuraffaCapability capability;

  /// Owning plugin id (`di`, `cache`, ...). Injected by [PluginCommand]
  /// at registration; falls back to the parent command's name, which for
  /// plugin commands IS the plugin id.
  final String? pluginId;

  /// Project root the receipt store lives under (issue #996). Defaults
  /// to the resolved project root; tests inject a temp fixture.
  final String? projectRoot;

  CapabilityCommand(this.capability, {this.pluginId, this.projectRoot}) {
    // Add generic JSON input option
    argParser.addOption('json', help: 'Pass arguments as JSON string');

    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview changes without executing',
    );
    argParser.addFlag(
      'revert',
      negatable: false,
      help: 'Revert generated files (delete them)',
    );

    // Dynamically add options based on schema
    final schema = capability.inputSchema;
    if (schema['properties'] is Map) {
      final props = schema['properties'] as Map<String, dynamic>;
      props.forEach((key, value) {
        final type = value['type'];
        final help = value['description'];
        final def = value['default'];
        final isFlag = type == 'boolean';
        final isList = type == 'array';
        final allowed = value['enum'] != null
            ? (value['enum'] as List).map((e) => e.toString()).toList()
            : null;

        final flagName = key.contains('-')
            ? key
            : StringUtils.camelToSnake(key).replaceAll('_', '-');
        if (argParser.options.containsKey(flagName)) {
          return;
        }

        if (isFlag) {
          argParser.addFlag(
            flagName,
            help: help,
            defaultsTo: def as bool?,
            negatable: true,
          );
        } else if (isList) {
          argParser.addMultiOption(
            flagName,
            help: help,
            defaultsTo: (def as List?)?.map((e) => e.toString()).toList(),
            allowed: allowed,
          );
        } else {
          argParser.addOption(
            flagName,
            help: help,
            defaultsTo: def?.toString(),
            allowed: allowed,
          );
        }
      });
    }
  }

  @override
  String get name {
    // Derive subcommand name from capability name
    // e.g. "create_usecase" -> "create" (if parent is "usecase")
    // or just use the full name if ambiguous.
    // For now, let's just use the last part if it contains underscores.
    if (capability.name.contains('_')) {
      return capability.name.split('_').first;
      // Wait, "create_usecase" inside "usecase" command should be "create".
      // But standard naming is often "verb_noun".
      // Let's try to be smart or just use the full name?
      // The proposal says "zfa usecase create".
      // So "create_usecase" -> "create".
      // But "zfa feature scaffold" -> "scaffold".
      // So it seems to be the "verb".
    }
    return capability.name;
  }

  @override
  String get description => capability.description;

  @override
  Future<void> run() async {
    final args = <String, dynamic>{};

    // Parse JSON if provided
    if (argResults?['json'] != null) {
      final jsonArgs = jsonDecode(argResults!['json']);
      if (jsonArgs is Map<String, dynamic>) {
        args.addAll(jsonArgs);
      }
    }

    // Parse CLI flags (override JSON)
    final schema = capability.inputSchema;
    if (schema['properties'] is Map) {
      final props = schema['properties'] as Map<String, dynamic>;
      for (final key in props.keys) {
        final prop = props[key] as Map<String, dynamic>;
        final isList = prop['type'] == 'array';
        final flagName = key.contains('-')
            ? key
            : StringUtils.camelToSnake(key).replaceAll('_', '-');

        if (argResults?.wasParsed(flagName) == true ||
            (!args.containsKey(key) && argResults?[flagName] != null)) {
          final value = argResults![flagName];
          if (isList && value is String) {
            args[key] = value.split(',').map((e) => e.trim()).toList();
          } else {
            args[key] = value;
          }
        }
      }
    }

    // Handle rest arguments (map to required properties)
    if (argResults != null && argResults!.rest.isNotEmpty) {
      final requiredFields = schema['required'] as List?;
      if (requiredFields != null) {
        for (var i = 0; i < argResults!.rest.length; i++) {
          if (i < requiredFields.length) {
            final key = requiredFields[i].toString();
            final prop = (schema['properties'] as Map)[key] as Map?;
            final isList = prop?['type'] == 'array';

            if (isList) {
              final list = args[key] as List? ?? [];
              list.add(argResults!.rest[i]);
              args[key] = list;
            } else if (!args.containsKey(key)) {
              args[key] = argResults!.rest[i];
            }
          } else {
            // Add extra arguments to the last required field if it's a list
            final lastKey = requiredFields.last.toString();
            final prop = (schema['properties'] as Map)[lastKey] as Map?;
            final isList = prop?['type'] == 'array';
            if (isList) {
              final list = args[lastKey] as List? ?? [];
              list.add(argResults!.rest[i]);
              args[lastKey] = list;
            }
          }
        }
      }
    }

    // Handle global flags
    if (argResults?['revert'] == true) {
      args['revert'] = true;
    }

    // Coerce schema-declared properties to the declared type (CLI options
    // arrive as Strings — including `def?.toString()` defaults, which is
    // why `zfa sync enable` with zero flags leaked a String '50' into an
    // `integer` property and crashed on `GeneratorConfig(syncBatchSize:
    // ...)`). Non-String values (bools from flags, ints from JSON
    // payloads) pass through untouched, and unparseable input passes
    // through unchanged so capabilities keep owning their validation and
    // error UX. Issue #773.
    final allProps = schema['properties'];
    if (allProps is Map) {
      allProps.forEach((key, prop) {
        if (prop is! Map) return;
        final type = prop['type'];
        if (type is! String) return;
        final value = args[key];
        if (value is! String) return;
        switch (type) {
          case 'integer':
            final parsed = int.tryParse(value);
            if (parsed != null) args[key] = parsed;
          case 'number':
            final parsed = double.tryParse(value);
            if (parsed != null) args[key] = parsed;
          case 'boolean':
            if (value == 'true') args[key] = true;
            if (value == 'false') args[key] = false;
          default:
            // string / array / object / null — keep as-is.
            break;
        }
      });
    }

    // Validate required fields
    final required = schema['required'] as List?;
    if (required != null) {
      final missing = <String>[];
      for (final key in required) {
        if (!args.containsKey(key) || args[key] == null) {
          missing.add(key as String);
        }
      }
      if (missing.isNotEmpty) {
        // Issue #978: error paths are machine-actionable. Every refusal
        // ends with a `--> fix:` line naming the invocation + the missing
        // required flags (the VISION.md verdict protocol), and machine
        // mode (`--json`) gets a single parseable verdict object instead
        // of prose (issue #778).
        final fixFlags = missing
            .map((key) {
              final flag = key.contains('-')
                  ? key
                  : StringUtils.camelToSnake(key).replaceAll('_', '-');
              return '--$flag <$flag>';
            })
            .join(' ');
        final commandPath = parent != null ? '${parent!.name} $name' : name;
        final fix = 'zfa $commandPath $fixFlags';
        final machineMode = argResults?['json'] != null;
        if (machineMode) {
          print(
            jsonEncode({
              'schema': 1,
              'ok': false,
              'error': 'Missing required arguments: ${missing.join(', ')}',
              'fix': fix,
            }),
          );
        } else {
          print('❌ Error: Missing required arguments: ${missing.join(', ')}');
        }
        print('   --> fix: $fix');
        exitCode = 64;
        return;
      }
    }

    if (args['verbose'] == true) {
      print('DEBUG: Executing capability with args: $args');
    }

    final isDryRun = argResults?['dry-run'] == true;

    if (isDryRun) {
      final report = await capability.plan(args);
      // Save plan for later execution
      await PlanStore.instance.savePlan(report);
      print(jsonEncode(report.toJson()));
    } else {
      // Issue #996: execute through the CapabilityInvocationWrapper so
      // every successful standalone invocation auto-persists a
      // proof.v1 receipt into .zfa/receipts/. Best-effort inside the
      // wrapper — a receipt failure never fails the generation.
      final effectivePluginId = pluginId ?? parent?.name ?? 'unknown';
      final wrapper = CapabilityInvocationWrapper(
        capability: capability,
        pluginId: effectivePluginId,
        projectRoot: projectRoot ?? ProjectRoot.find(),
      );
      final result = await wrapper.execute(args);
      if (result.success) {
        // Issue #978: machine verdict mode. When the caller passed `--json`
        // (the machine-input channel) and the capability returned a
        // structured `verdict` in its result data, print exactly one
        // parseable verdict object (issue #778 convention — no prose) and
        // set the exit code from the verdict's own `ok` flag. Capabilities
        // without a verdict keep the prose path unchanged.
        final machineMode = argResults?['json'] != null;
        final verdict = result.data?['verdict'];
        if (machineMode && verdict is Map<String, dynamic>) {
          print(jsonEncode(verdict));
          final ok = verdict['ok'] == true;
          if (!ok) {
            final fix = verdict['fix'];
            print('   --> fix: $fix');
          }
          exitCode = ok ? 0 : 1;
          return;
        }

        // Spec 0974: the #769 zero-files guard only applies to GENERATOR
        // capabilities — the ones that report their artifacts under
        // data['generatedFiles']. Read-only capabilities (e.g. the
        // `zfa di verify` gate) ship a verdict message and no generated
        // files by design; they must not trip a guard about generation.
        final isGenerator = result.data?.containsKey('generatedFiles') == true;
        final files =
            result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
        if (isGenerator && files.isEmpty) {
          // Issue #769: zero files means the request produced nothing —
          // e.g. a pure-Dart guard skipped presenter/controller/view
          // generation. That is not a success: claiming "✅ Success!"
          // (and exiting 0) misleads automation into reading a declined
          // generation as a win. The generator's own skip note above
          // explains WHY nothing was emitted; here we only refuse to
          // dress the outcome up as success and set a failure exit code.
          print(
            '⚠️ No files were generated (nothing changed). If the '
            'generator printed a skip note above, re-run inside a '
            'project that satisfies its guard; otherwise re-run with '
            '--verbose to inspect the resolved arguments.',
          );
          exitCode = 1;
          return;
        }

        // Read-only capabilities (verify-style gates) carry their verdict
        // in the message; surface it so a clean pass is not a silent exit 0.
        if (!isGenerator && result.message != null) {
          print('✅ ${result.message}');
        }

        final created = files.where((f) => f.action == 'created').toList();
        final overwritten = files
            .where((f) => f.action == 'overwritten')
            .toList();
        final updated = files.where((f) => f.action == 'updated').toList();
        final skipped = files.where((f) => f.action == 'skipped').toList();
        final deleted = files.where((f) => f.action == 'deleted').toList();

        if (created.isNotEmpty ||
            overwritten.isNotEmpty ||
            updated.isNotEmpty ||
            deleted.isNotEmpty) {
          print('✅ Success! Created/Modified:');
          for (final file in created) {
            print('  ✨ ${file.path}');
          }
          for (final file in overwritten) {
            print('  📝 ${file.path}');
          }
          for (final file in updated) {
            print('  📝 ${file.path}');
          }
          for (final file in deleted) {
            print('  🗑 ${file.path}');
          }
        }

        if (skipped.isNotEmpty) {
          print('\n⏭ Skipped (use --force to overwrite):');
          for (final file in skipped) {
            print('  ${file.path}');
          }
        }

        // Issue #996: every successful standalone capability invocation
        // ships a `proof.v1` receipt. Previously only the `zfa make` path
        // wrote receipts (PluginManager._persistGenerationReceipt), so
        // `zfa di create`, `zfa cache adapter`, `zfa repository create`,
        // etc. produced artifacts with zero provenance — violating the
        // VISION's "every artifact ships a verifiable receipt" and the
        // epic #1011 truth-floor exit criterion. Best-effort: a receipt
        // failure degrades to a warning so a store hiccup never turns a
        // successful generation into a CLI failure.
        await _persistCapabilityReceipt(args: args, files: files);
      } else {
        print('❌ Failed: ${result.message}');
        // Issue #767: a failed capability execution must not report success
        // to automation. Exit 1 — a runtime/generation failure, distinct
        // from the usage-error family (64) used for missing arguments.
        exitCode = 1;
      }
    }
  }

  /// Issue #996: writes a `proof.v1` receipt binding every on-disk file
  /// this standalone capability invocation committed. Mirrors the
  /// make-path `PluginManager._persistGenerationReceipt` but for the
  /// `zfa <plugin> <capability> <target>` standalone invocation path.
  ///
  /// Best-effort by design: the artifacts already exist on disk, so a
  /// receipt failure degrades to a warning instead of failing the run.
  /// Files that the capability reported but did not actually write
  /// (e.g. `skipped`, or paths the capability emitted in-memory only)
  /// are skipped via the `existsSync` guard — a receipt binds real
  /// bytes, not intentions.
  Future<void> _persistCapabilityReceipt({
    required Map<String, dynamic> args,
    required List<GeneratedFile> files,
  }) async {
    try {
      final projectRoot = Directory.current.path;
      final receiptFiles = <GenerationReceiptFile>[];
      for (final f in files) {
        // Skipped/deleted operations have no final bytes to bind.
        if (f.action == 'skipped' || f.action == 'deleted') continue;
        final abs = path.isAbsolute(f.path)
            ? f.path
            : path.join(projectRoot, f.path);
        final file = File(abs);
        if (!file.existsSync()) continue;
        final bytes = file.readAsBytesSync();
        final keepSnapshot = bytes.length <= ReceiptStore.maxSnapshotBytes;
        receiptFiles.add(
          GenerationReceiptFile(
            path: f.path.replaceAll('\\', '/'),
            action: f.action,
            sha256: crypto.sha256.convert(bytes).toString(),
            bytes: bytes.length,
            snapshot: keepSnapshot && !_isLikelyBinary(bytes)
                ? file.readAsStringSync()
                : null,
          ),
        );
      }
      // Nothing provenance-worthy landed on disk — don't ship an empty
      // receipt (it would certify nothing while looking like proof).
      if (receiptFiles.isEmpty) return;
      receiptFiles.sort((a, b) => a.path.compareTo(b.path));

      // Derive names from the command hierarchy: `zfa <plugin> <verb>`
      // where <plugin> = parent?.name (e.g. "di") and <verb> = this.name
      // (e.g. "create"). For programmatic invocations without a parent
      // (test harness), fall back to the capability name.
      final pluginName = parent?.name ?? 'standalone';
      final verb = name;
      final target = _extractCapabilityTarget(args);
      final repro =
          'zfa $pluginName $verb'
          '${target.isNotEmpty ? ' $target' : ''}';

      // Issue #1130: hyphenated command and spec binding. The capability
      // may set args['_spec'] (a GenerationReceiptSpec) before calling
      // _emitReceipt; propagate it so the CapabilityCommand receipt
      // carries the same provenance as the capability's own receipt.
      GenerationReceiptSpec? spec;
      final rawSpec = args['_spec'];
      if (rawSpec is GenerationReceiptSpec) {
        spec = rawSpec;
      }

      // Merge raw args with canonical keys the test suite expects.
      // Capabilities store entity in args['name'] and discovered
      // entities in args['_discoveredEntities']; the receipt schema
      // uses 'entity' and 'discoveredEntities' as top-level input keys.
      // Capabilities also surface _registrarHash and _buildStatus as
      // internal keys that need public-facing aliases in the receipt.
      final input = <String, dynamic>{
        if (target.isNotEmpty) 'entity': target,
        if (args['_discoveredEntities'] is List)
          'discoveredEntities': args['_discoveredEntities'],
        if (args.containsKey('_registrarHash'))
          'registrarHash': args['_registrarHash'],
        if (args.containsKey('_buildStatus'))
          'buildStatus': args['_buildStatus'],
      };

      await ReceiptStore(projectRoot: projectRoot).save(
        GenerationReceipt(
          command: '$pluginName-$verb',
          target: target,
          repro: repro,
          at: DateTime.now().toUtc(),
          generatorVersion: version,
          input: input,
          spec: spec,
          files: receiptFiles,
        ),
      );
    } catch (e) {
      print('⚠️  Capability receipt not written: $e');
    }
  }

  /// Best-effort: pull the entity/target name out of [args] for the
  /// receipt's `target` field. Capability schemas use a mix of `name`,
  /// `entity_name`, `entityName`, `class_name` — try each in order and
  /// return '' when none are present (the receipt still records the
  /// full `input` map, so the target is recoverable from there).
  String _extractCapabilityTarget(Map<String, dynamic> args) {
    for (final key in [
      'name',
      'entity_name',
      'entityName',
      'class_name',
      'className',
    ]) {
      final v = args[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  /// Snapshots are diffed as text; refuse to store bytes that are not
  /// valid UTF-8 (defensive — generated outputs are text).
  bool _isLikelyBinary(List<int> bytes) {
    final probe = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
    try {
      utf8.decode(probe);
      return false;
    } on FormatException {
      return true;
    }
  }
}
