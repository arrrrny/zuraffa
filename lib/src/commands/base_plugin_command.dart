import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:meta/meta.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../models/generated_file.dart';
import 'capability_command.dart';

/// Base class for all plugin-based CLI commands.
///
/// Provides standard flags (output, dry-run, force, verbose) and helper getters.
abstract class PluginCommand extends Command<void> {
  static const String fixedOutputDir = 'lib/src';

  final ZuraffaPlugin plugin;

  /// When false, capabilities are NOT registered as subcommands. This lets a
  /// command accept the entity name as a positional argument (e.g.
  /// `zfa api <Entity>`) instead of requiring it to be a subcommand.
  final bool registerSubcommands;

  /// Subcommand names the concrete command class registers itself (typically
  /// richer first-party subcommands such as `JsonMockCommand`). Capabilities
  /// whose derived subcommand name appears here are skipped during automatic
  /// registration so the manual registration cannot collide with them.
  ///
  /// Why this hook exists (issue #761): in package:args, `addSubcommand`
  /// writes the subcommand-map entry *before* calling `argParser.addCommand`
  /// and only sets `command._parent` afterwards. A duplicate name therefore
  /// throws mid-registration, leaving the manually-registered subcommand
  /// dispatchable but unparented (`parent == null` → `runner == null`), which
  /// crashes `Command.invocation` — i.e. `--help` — with "Null check operator
  /// used on a null value" while normal dispatch keeps working.
  Set<String> get manualSubcommandNames => const {};

  PluginCommand(this.plugin, {this.registerSubcommands = true}) {
    argParser.addOption(
      'output',
      abbr: 'o',
      help:
          'Output directory for generated files (fixed to lib/src in v5; custom values are ignored)',
      defaultsTo: fixedOutputDir,
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

    // Auto-register capabilities as subcommands, skipping any whose derived
    // subcommand name the concrete class registers itself (see
    // [manualSubcommandNames] for why the duplicate must never happen).
    if (registerSubcommands) {
      for (final capability in plugin.capabilities) {
        // Issue #996: the plugin id rides along so every capability
        // invocation can persist its receipt keyed
        // <plugin>-<capability>-<entity>-<timestamp>.json.
        final subcommand = CapabilityCommand(capability, pluginId: plugin.id);
        if (manualSubcommandNames.contains(subcommand.name)) {
          continue;
        }
        addSubcommand(subcommand);
      }
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
  String get outputDir => fixedOutputDir;

  /// Prints the live subcommand grammar and signals a usage error (bug
  /// #856).
  ///
  /// The positional grammars these commands' usage strings advertised
  /// (`zfa repository <EntityName>`) are unreachable through the CLI:
  /// [PluginCommand] auto-registers every capability as a subcommand, so
  /// package:args rejects a bare entity name — and any
  /// flags-then-positional shape — with "Could not find a subcommand"
  /// before run() ever executes. run() is only reachable through direct
  /// (programmatic) invocation; it must therefore tell the truth about
  /// the grammar, never generate, and exit non-zero instead of looking
  /// like a success.
  @protected
  void reportSubcommandUsage() {
    print('❌ Usage: zfa $name <subcommand> [arguments]');
    print('   Run `zfa $name --help` to list subcommands.');
    exitCode = 64;
  }

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
