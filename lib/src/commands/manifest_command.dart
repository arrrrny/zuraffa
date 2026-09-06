import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import '../cli/exit_protocol.dart';
import '../core/plugin_system/cli_flag_surface.dart';
import '../core/plugin_system/cli_aware_plugin.dart';
import '../core/plugin_system/plugin_registry.dart';
import '../utils/string_utils.dart';
import 'base_plugin_command.dart';

/// Command to list all available capabilities in JSON format.
///
/// This is used by MCP clients to discover available tools.
///
/// SPEC 917 (issue #917, absorbing #776/#979): `zfa manifest --verify
/// [pluginIds...]` is the machine-checkable treaty gate — manifest
/// inputSchemas ↔ CLI flags ↔ help text. For every CLI-aware plugin (or
/// the requested subset) the gate runs four legs:
///
///   1. **schema→flags** — every `inputSchema.properties` entry (the
///      required ones per #902, the optional ones per #904) must be
///      accepted by the command that serves the capability
///      (camelCase → kebab-case). Hand-rolled `ArgParser.allowAnything()`
///      dispatchers declare their real grammar via [CliFlagSurface].
///   2. **help text** — every schema-derived flag must appear in the
///      serving command's usage surface; a parseable-but-hidden flag is
///      drift (help text and flags must never disagree).
///   3. **dead flags** (#876 family, spec #979) — a [PluginCommand]
///      parent-level option outside [PluginCommand.consumedParentFlags]
///      is parsed and advertised but never read.
///   4. **resolution** — every advertised capability must resolve in the
///      command tree (the phantom-capability family).
///
/// Drift exits **3** — the canonical contract-drift code of the ratified
/// exit protocol (VISION §3: the treaty must be sacred). A clean pass
/// exits 0, which is what drops the gate into CI
/// (`.github/workflows/conformance.yml`). `--format json` emits one
/// machine-verifiable `manifest-verify.v1` document.
class ManifestCommand extends Command<void> {
  final PluginRegistry registry;

  ManifestCommand([PluginRegistry? registry])
    : registry = registry ?? PluginRegistry.instance {
    argParser.addOption(
      'format',
      abbr: 'f',
      allowed: ['json', 'mcp'],
      defaultsTo: 'json',
      help: 'Output format',
    );
    argParser.addFlag(
      'verify',
      negatable: false,
      help:
          'Certify the treaty: manifest inputSchemas ↔ CLI flags ↔ help '
          'text (drift exits 3). Optional trailing plugin ids scope the '
          'certification.',
    );
  }

  @override
  String get name => 'manifest';

  @override
  String get description => 'List all available capabilities';

  @override
  Future<void> run() async {
    if (argResults?['verify'] == true) {
      await _runVerify(
        argResults?.rest ?? const <String>[],
        machineFormat:
            argResults?['format'] == 'json' && _verifyFormatRequested,
      );
      return;
    }

    final format = argResults?['format'] ?? 'json';

    if (format == 'mcp') {
      // Format as MCP tools definition
      final tools = <Map<String, dynamic>>[];
      for (final plugin in registry.plugins) {
        // Only capabilities of CLI-aware plugins are advertised: the manifest
        // is a command-invocation contract, and capabilities of plugins without
        // a registered command (internal orchestrators) are unreachable from
        // the CLI and would mislead MCP/tooling clients that auto-resolve
        // names against this list.
        if (plugin is! CliAwarePlugin) continue;
        for (final capability in plugin.capabilities) {
          tools.add({
            'name': 'zfa_${plugin.id}_${capability.name}',
            'description': capability.description,
            'inputSchema': capability.inputSchema,
          });
        }
      }
      print(jsonEncode({'tools': tools}));
    } else {
      // Default JSON format with full details
      //
      // Only capabilities of CLI-aware plugins are advertised: the manifest
      // is a command-invocation contract, and capabilities of plugins without
      // a registered command (internal orchestrators) are unreachable from
      // the CLI and would mislead MCP/tooling clients that auto-resolve
      // names against this list.
      final output = <Map<String, dynamic>>[];
      for (final plugin in registry.plugins) {
        if (plugin is! CliAwarePlugin) continue;
        for (final capability in plugin.capabilities) {
          output.add({
            'plugin': plugin.id,
            'name': capability.name,
            'description': capability.description,
            'inputSchema': capability.inputSchema,
            'outputSchema': capability.outputSchema,
          });
        }
      }
      print(jsonEncode(output));
    }
  }

  /// `--format=json` on the verify mode itself: the generic --format flag
  /// governs the LISTING format; the verify envelope is requested by
  /// composing `--verify --format json`. (Kept explicit so the listing
  /// default of json does not silently envelop the text certification.)
  bool get _verifyFormatRequested => argResults?.wasParsed('format') ?? false;

  /// The help-text oracle: the serving command's usage surface must list
  /// [flagName]. Detached command roots (created via
  /// `PluginCommand.createCommand()` without a runner) crash
  /// `Command.usage` on the package:args parent walk (the #761 family),
  /// so the auto-generated parser usage is the fallback surface — which
  /// is exactly the surface `--help` prints for generated grammars.
  ///
  /// Negatable booleans render as `--[no-]flag`, so the check is
  /// negation-aware (SPEC 917: `zfa feature --help` advertises
  /// `--[no-]vpcs` and that IS an advertisement of --vpcs).
  bool _helpSurfaceAdmits(Command<void> serving, String flagName) {
    String surface;
    try {
      surface = serving.usage;
    } catch (_) {
      surface = serving.argParser.usage;
    }
    final pattern = RegExp(
      '--(\\[no-\\])?${RegExp.escape(flagName)}(\\s|,|\$|\\))',
      multiLine: true,
    );
    return pattern.hasMatch(surface);
  }

  /// One treaty finding. `kind` is machine-actionable vocabulary:
  /// `dead-flag` (#876), `schema-flag-unaccepted` (#902/#904),
  /// `help-text-drift`, or `flag-surface-unverifiable` (the gate could
  /// not check mechanically — reported, not drift).
  static const _kDeadFlag = 'dead-flag';
  static const _kSchemaFlagUnaccepted = 'schema-flag-unaccepted';
  static const _kHelpTextDrift = 'help-text-drift';
  static const _kUnverifiable = 'flag-surface-unverifiable';

  Future<void> _runVerify(
    List<String> scope, {
    required bool machineFormat,
  }) async {
    // SPEC 917: an unknown plugin id is a usage error (the treaty cannot
    // certify what is absent) — never a silent exit-0 pass.
    final knownIds = <String>{
      for (final p in registry.plugins)
        if (p is CliAwarePlugin) p.id,
    };
    final unknownScope = scope.where((id) => !knownIds.contains(id)).toList();
    if (unknownScope.isNotEmpty) {
      print(
        '❌ manifest verify: unknown plugin id(s): '
        '${unknownScope.map((id) => '`$id`').join(', ')}',
      );
      print(
        ExitProtocol.fixLine(
          're-run with plugin id(s) from `zfa manifest --format json` '
          '(or `zfa --help`) — unknown ids cannot be certified',
        ),
      );
      exitCode = ExitProtocol.usage;
      return;
    }

    // The flags every PluginCommand carries as shared machinery, plus
    // package:args' automatic --help — none of these are the plugin
    // contract.
    const baseFlags = {
      'output',
      'dry-run',
      'force',
      'verbose',
      'revert',
      'help',
    };

    final findings = <Map<String, String>>[];
    final certified = <String>[];

    void finding(
      String kind, {
      required String plugin,
      String? capability,
      String? flag,
      required String message,
      required String fix,
    }) {
      findings.add({
        'kind': kind,
        'plugin': plugin,
        'capability': ?capability,
        'flag': ?flag,
        'message': message,
        'fix': fix,
      });
    }

    for (final plugin in registry.plugins) {
      if (plugin is! CliAwarePlugin) continue;
      if (scope.isNotEmpty && !scope.contains(plugin.id)) continue;

      final command = (plugin as CliAwarePlugin).createCommand();

      // ---- Leg: dead parent flags (#876 family, scoped to the
      // PluginCommand family the check was designed for — hand-rolled
      // commands own their flags directly and are covered by the schema
      // legs below).
      if (command is PluginCommand) {
        final pluginFlags = command.argParser.options.keys
            .where((f) => !baseFlags.contains(f))
            .toSet();
        final consumed = command.consumedParentFlags;
        for (final flag in pluginFlags.difference(consumed)) {
          finding(
            _kDeadFlag,
            plugin: plugin.id,
            flag: flag,
            message:
                'zfa ${plugin.id} --$flag is parsed and advertised by '
                '--help but never read in run() (issue #876 family)',
            fix:
                'delete the parent-level --$flag registration — the live '
                'surface is `zfa ${plugin.id} <subcommand> --$flag`, '
                'synthesized from the capability inputSchema — or consume '
                'it in run() and declare it in consumedParentFlags.',
          );
        }
      }

      // ---- Legs: schema↔flags↔help, per capability.
      for (final capability in plugin.capabilities) {
        final serving = resolveServingCommand(command, capability.name);
        final props = capability.inputSchema['properties'];
        final propNames = props is Map
            ? props.keys.map((k) => k.toString()).toList()
            : const <String>[];

        if (serving != command) {
          certified.add(
            '  ✓ ${plugin.id} ${capability.name} → '
            '`zfa ${plugin.id} ${serving.name}` resolves',
          );
        } else {
          certified.add(
            '  ✓ ${plugin.id} ${capability.name} → '
            '`zfa ${plugin.id} ${capability.name.split('_').first} ...` '
            '(hand-rolled dispatch)',
          );
        }

        final manualGrammar =
            identical(serving.argParser.options, const {}) ||
            serving.argParser.options.isEmpty;

        for (final prop in propNames) {
          final flagName = prop.contains('-')
              ? prop
              : StringUtils.camelToSnake(prop).replaceAll('_', '-');

          if (manualGrammar) {
            // Hand-rolled dispatcher: the parser accepts everything, so
            // the honest oracle is the declared flag surface.
            final surface = serving is CliFlagSurface
                ? serving as CliFlagSurface
                : null;
            if (surface == null) {
              finding(
                _kUnverifiable,
                plugin: plugin.id,
                capability: capability.name,
                flag: flagName,
                message:
                    'zfa ${plugin.id} ${capability.name} dispatches with a '
                    'permissive parser and declares no CliFlagSurface — '
                    'the gate cannot mechanically check --$flagName',
                fix:
                    'implement CliFlagSurface on ${serving.name} listing '
                    'the flags run() actually accepts, or register real '
                    'ArgParser options.',
              );
              continue;
            }
            if (!surface.acceptedFlags.contains(flagName)) {
              finding(
                _kSchemaFlagUnaccepted,
                plugin: plugin.id,
                capability: capability.name,
                flag: flagName,
                message:
                    'the manifest inputSchema advertises --$flagName but '
                    'the hand-rolled grammar of `zfa ${plugin.id} '
                    '${capability.name}` rejects it (#904 drift class: '
                    '"Could not find an option")',
                fix:
                    'add --$flagName to the dispatch (aliasing the '
                    'canonical flag when one exists) or stop advertising '
                    'the property in the capability inputSchema.',
              );
            }
            continue;
          }

          // Registered-parser command: the flag must parse…
          final accepted = serving.argParser.options.containsKey(flagName);
          if (!accepted) {
            finding(
              _kSchemaFlagUnaccepted,
              plugin: plugin.id,
              capability: capability.name,
              flag: flagName,
              message:
                  'the manifest inputSchema advertises --$flagName but the '
                  'parser of `zfa ${plugin.id} ${serving.name}` rejects it '
                  '(#902/#904 drift class: "Could not find an option")',
              fix:
                  'register --$flagName on the serving parser (aliasing the '
                  'canonical flag when one exists) or stop advertising the '
                  'property in the capability inputSchema.',
            );
            continue;
          }
          // …and the help text must admit it.
          if (!_helpSurfaceAdmits(serving, flagName)) {
            finding(
              _kHelpTextDrift,
              plugin: plugin.id,
              capability: capability.name,
              flag: flagName,
              message:
                  '--$flagName is accepted by `zfa ${plugin.id} '
                  '${serving.name}` but never appears in its usage/help '
                  'surface — help text and flags disagree',
              fix:
                  'make the usage surface list --$flagName (or remove the '
                  'option registration and the schema property together).',
            );
          }
        }
      }
    }

    final realFindings = findings
        .where((f) => f['kind'] != _kUnverifiable)
        .toList();
    final unverifiableFindings = findings
        .where((f) => f['kind'] == _kUnverifiable)
        .toList();
    final fix = realFindings.isEmpty ? null : realFindings.first['fix'];
    final exit = realFindings.isEmpty
        ? ExitProtocol.success
        : ExitProtocol.drift;

    if (machineFormat) {
      // One machine-verifiable document (issue #778 conventions): the
      // LAST stdout line, no prose around it.
      print(
        jsonEncode({
          'schema': 'manifest-verify.v1',
          'ok': realFindings.isEmpty,
          'exit_code': exit,
          'certified': certified.length,
          'findings': realFindings,
          'unverifiable': unverifiableFindings,
          'fix': ?fix,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      exitCode = exit;
      return;
    }

    print(
      'manifest verify: ${certified.length} capability route(s) certified, '
      '${realFindings.length} drift finding(s)'
      '${unverifiableFindings.isEmpty ? '' : ', ${unverifiableFindings.length} unverifiable flag surface(s)'}',
    );
    for (final line in certified) {
      print(line);
    }
    if (findings.isEmpty) {
      print(
        '✅ treaty holds: manifest inputSchemas ↔ CLI flags ↔ help text '
        'are in conformance (exit 0).',
      );
      exitCode = ExitProtocol.success;
      return;
    }

    print('');
    print('Findings (${findings.length}):');
    for (final f in findings) {
      print(
        '  [${f['kind']}] ${f['plugin']}'
        '${f['capability'] != null ? ' ${f['capability']}' : ''}'
        '${f['flag'] != null ? ' --${f['flag']}' : ''}: '
        '${f['message']}',
      );
      print('    --> fix: ${f['fix']}');
    }
    if (realFindings.isNotEmpty) {
      print('');
      print(
        '❌ treaty drift: ${realFindings.length} finding(s) — exit '
        '${ExitProtocol.drift} (contract/spec drift).',
      );
    }
    exitCode = exit;
  }
}
