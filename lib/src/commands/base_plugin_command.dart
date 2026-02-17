import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../models/generated_file.dart';
import 'capability_command.dart';

/// Base class for all plugin-based CLI commands.
///
/// Provides standard flags (output, dry-run, force, verbose) and helper getters.
abstract class PluginCommand extends Command<void> {
  final ZuraffaPlugin plugin;

  PluginCommand(this.plugin) {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for generated files',
      defaultsTo: 'lib/src',
    );
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview generated files without writing to disk',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      negatable: false,
      help: 'Overwrite existing files',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable detailed logging',
    );
    argParser.addFlag(
      'revert',
      negatable: false,
      help: 'Revert generated files (delete them)',
    );
    
    // Auto-register capabilities as subcommands
    for (final capability in plugin.capabilities) {
      addSubcommand(CapabilityCommand(capability));
    }
  }

  @override
  String get name => plugin.id;

  @override
  String get description => 'Run the ${plugin.name} generator';

  /// Returns true if dry-run mode is enabled.
  @protected
  bool get isDryRun => argResults?['dry-run'] == true;

  /// Returns true if force mode is enabled.
  @protected
  bool get isForce => argResults?['force'] == true;

  /// Returns true if verbose logging is enabled.
  @protected
  bool get isVerbose => argResults?['verbose'] == true;

  /// Returns true if revert mode is enabled.
  @protected
  bool get isRevert => argResults?['revert'] == true;

  /// Returns the resolved output directory.
  @protected
  String get outputDir => argResults?['output'] ?? 'lib/src';

  /// Prints a summary of generated files.
  @protected
  void logSummary(List<GeneratedFile> files) {
    if (files.isEmpty) {
      print('ℹ️  No files generated.');
      return;
    }

    final created = files.where((f) => f.action == 'created').length;
    final overwritten = files.where((f) => f.action == 'overwritten').length;
    final skipped = files.where((f) => f.action == 'skipped').length;
    final deleted = files.where((f) => f.action == 'deleted').length;

    print('\n✅ Generation complete:');
    if (created > 0) print('  ✨ Created: $created files');
    if (overwritten > 0) print('  📝 Overwritten: $overwritten files');
    if (skipped > 0) print('  ⏭ Skipped: $skipped files');
    if (deleted > 0) print('  🗑 Deleted: $deleted files');

    // If not verbose, print generated file paths (verbose mode already prints from FileUtils)
    if (!isVerbose) {
      for (final file in files) {
        if (file.action == 'created') {
          print('  ✨ ${file.path}');
        } else if (file.action == 'overwritten') {
          print('  📝 ${file.path}');
        } else if (file.action == 'deleted') {
          print('  🗑 ${file.path}');
        }
      }
    }
  }
}
