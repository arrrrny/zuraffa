import 'dart:convert';
import 'package:args/command_runner.dart';
import '../models/generated_file.dart';
import '../core/plugin_system/capability.dart';
import '../core/plugin_system/plan_store.dart';
import '../utils/string_utils.dart';

class CapabilityCommand extends Command<void> {
  final ZuraffaCapability capability;

  CapabilityCommand(this.capability) {
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
        print('❌ Error: Missing required arguments: ${missing.join(', ')}');
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
      final result = await capability.execute(args);
      if (result.success) {
        final files =
            result.data?['generatedFiles'] as List<GeneratedFile>? ?? [];
        if (files.isEmpty) {
          print('✅ Success! (No changes required)');
          return;
        }

        final created = files.where((f) => f.action == 'created').toList();
        final overwritten = files
            .where((f) => f.action == 'overwritten')
            .toList();
        final skipped = files.where((f) => f.action == 'skipped').toList();
        final deleted = files.where((f) => f.action == 'deleted').toList();

        if (created.isNotEmpty ||
            overwritten.isNotEmpty ||
            deleted.isNotEmpty) {
          print('✅ Success! Created/Modified:');
          for (final file in created) {
            print('  ✨ ${file.path}');
          }
          for (final file in overwritten) {
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
      } else {
        print('❌ Failed: ${result.message}');
        // exit(1);
      }
    }
  }
}
