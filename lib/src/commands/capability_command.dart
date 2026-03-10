import 'dart:convert';
import 'package:args/command_runner.dart';
import '../core/plugin_system/capability.dart';
import '../core/plugin_system/plan_store.dart';

class CapabilityCommand extends Command<void> {
  final ZuraffaCapability capability;

  CapabilityCommand(this.capability) {
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

        if (isFlag) {
          argParser.addFlag(
            key,
            help: help,
            defaultsTo: def as bool?,
            negatable: true,
          );
        } else if (isList) {
          argParser.addMultiOption(
            key,
            help: help,
            defaultsTo: (def as List?)?.map((e) => e.toString()).toList(),
            allowed: allowed,
          );
        } else {
          argParser.addOption(
            key,
            help: help,
            defaultsTo: def?.toString(),
            allowed: allowed,
          );
        }
      });
    }

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
        if (argResults?.wasParsed(key) == true) {
          args[key] = argResults![key];
        } else if (!args.containsKey(key) && argResults?[key] != null) {
          // Use default from ArgParser if not in JSON
          args[key] = argResults![key];
        }
      }
    }

    // Handle rest arguments (map to required properties)
    if (argResults != null && argResults!.rest.isNotEmpty) {
      final required = schema['required'] as List?;
      if (required != null) {
        for (
          var i = 0;
          i < argResults!.rest.length && i < required.length;
          i++
        ) {
          final key = required[i] as String;
          if (!args.containsKey(key)) {
            args[key] = argResults!.rest[i];
          }
        }
      }
    }

    // Handle global flags
    if (argResults?['revert'] == true) {
      args['revert'] = true;
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
        print('✅ Success! Created/Modified:');
        for (final file in result.files) {
          print('  $file');
        }
      } else {
        print('❌ Failed: ${result.message}');
        // exit(1);
      }
    }
  }
}
