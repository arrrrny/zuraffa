/// `zfa tdd fake <channel>` — generates a framework-certified fake for a
/// platform channel (issue #831 — platform-channel test harness, VISION
/// §9 simulation worlds).
///
/// The command writes TWO artifacts:
///
///   1. The SCENARIO SCRIPT at `specs/<feature>/tdd/scenarios/<slug>.json`
///      — the committed INTENT: which methods the channel answers, with
///      which responses/errors/permission states, and (optionally) the
///      cross-platform hosted matrix (`--platforms ios,android,...`). A
///      scenario that already exists is KEPT (intent is committed, the
///      command never silently rewrites it) unless `--force` is passed;
///      a channel/platform mismatch with the committed script is an
///      honest refusal, not a silent overwrite.
///   2. The CERTIFIED FAKE at `test/tdd/<feature>/fakes/<slug>_fake.dart`
///      — a test-side handler registered via
///      `TestDefaultBinaryMessengerBinding` that replays the scenario and
///      records every observed call (method, arguments, order). This file
///      is always regenerated from the current binary (same staleness
///      contract as gen stubs, bug #683).
///
/// With `--behavior <id>` the slug is the behavior's snake-case id, so
/// `zfa tdd gen <id>` (platform kind) finds the pair by convention:
/// scenario `specs/<feature>/tdd/scenarios/<snake-id>.json` and fake
/// import `fakes/<snake-id>_fake.dart`. Without it the slug derives from
/// the channel name (standalone fakes).
///
/// Fakes are NOT agent-written mocks (no grading your own homework): the
/// responses live in the scenario file committed as intent — the fake
/// only replays them. Unscripted methods fail loudly through the
/// scenario's required default response.
///
/// Summary (house convention): the LAST stdout line is machine-readable:
///
///     fake: channel=<c> feature=<f> behavior=<b|-> slug=<s>
///           scenario=<rel> fake=<rel> platforms=<csv> — scenario
///           kept|rewritten
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../../core/project/project_root.dart';
import '../models/channel_scenario.dart';
import '../services/channel_fake_writer.dart';
import '../services/verdict_emitter.dart';
import '../models/verdict_envelope.dart';
import '../tdd_plugin.dart';

class FakeCommand extends Command<void> {
  FakeCommand(this.plugin) {
    argParser.addFlag(
      'json',
      help:
          'Emit a versioned verdict.v1 JSON envelope as the final stdout '
          'line (VISION §5, issue #964).',
      negatable: false,
    );
    argParser.addOption(
      'project',
      aliases: const ['project-root'],
      help: 'Target project root (defaults to the nearest pubspec.yaml).',
    );
    argParser.addOption(
      'feature',
      help:
          'The specs/<feature> directory the scenario intent belongs to. '
          'Required: committed intent must land in an explicit feature.',
    );
    argParser.addOption(
      'behavior',
      help:
          'Bind the fake to a behavior id — the slug becomes the '
          'behavior\'s snake-case id so `zfa tdd gen <id>` (platform '
          'kind) finds scenario + fake by convention.',
    );
    argParser.addOption(
      'platforms',
      help:
          'Comma-separated hosted-matrix targets (issue #831 requirement '
          '5). Tokens from the closed set: '
          '${_sortedPlatforms()}. The same scenario runs on every '
          'platform it names where feasible.',
    );
    argParser.addFlag(
      'force',
      help:
          'Rewrite an EXISTING scenario starter. Committed intent is '
          'never silently overwritten without this flag.',
      defaultsTo: false,
      negatable: false,
    );
  }

  final TddPlugin plugin;

  /// Issue #969: the envelope carrier the wrapper reads on exit.
  final VerdictContext _verdict = VerdictContext();

  static String _sortedPlatforms() =>
      (ChannelScenario.supportedPlatforms.toList()..sort()).join(', ');

  @override
  String get name => 'fake';

  @override
  String get description =>
      'Generate a framework-certified fake for a platform channel: a '
      'test-side handler (TestDefaultBinaryMessengerBinding) that replays '
      'a committed scenario script — responses, errors, permission '
      'states — and records the observed calls (issue #831).';

  @override
  String get invocation => 'zfa tdd fake <channel> [options]';

  @override
  Future<void> run() => runWithVerdictEnvelope(this, _verdict, _run);

  Future<void> _run() async {
    // Fail fast on missing arguments.
    final rest = argResults!.rest;
    if (rest.isEmpty) {
      usageException(
        'zfa tdd fake: a platform channel name is required, e.g. '
        '`zfa tdd fake app.camera --feature <feature>`',
      );
    }
    final channel = rest.first.trim();
    if (channel.isEmpty) {
      usageException('zfa tdd fake: the channel name must not be empty');
    }

    // --feature is required: committed intent must land in an explicit
    // feature (a guess would write intent into the wrong home).
    final feature = (argResults!['feature'] as String?)?.trim() ?? '';
    if (feature.isEmpty) {
      stderr.writeln(
        'zfa tdd fake: --feature is required — the scenario intent must '
        'land in an explicit specs/<feature> directory.',
      );
      usageException(
        'zfa tdd fake: missing --feature (the scenario intent needs an '
        'explicit feature home)',
      );
    }
    _validateFeatureSegment(feature);

    final projectFlag = argResults!['project'] as String?;
    final cwd = projectFlag != null && projectFlag.isNotEmpty
        ? p.absolute(projectFlag)
        : ProjectRoot.find();

    final platforms = _parsePlatforms(argResults!['platforms'] as String?);
    final force = argResults!['force'] as bool;
    final behavior = (argResults!['behavior'] as String?)?.trim() ?? '';

    final slug = behavior.isNotEmpty
        ? _toSnakeCase(behavior)
        : ChannelFakeWriter.slugForChannel(channel);

    final scenarioPath = p.join(
      cwd,
      'specs',
      feature,
      'tdd',
      'scenarios',
      '$slug.json',
    );
    final fakePath = p.join(
      cwd,
      'test',
      'tdd',
      feature,
      'fakes',
      '${slug}_fake.dart',
    );
    final scenarioRelative = p.join(
      'specs',
      feature,
      'tdd',
      'scenarios',
      '$slug.json',
    );
    final fakeRelative = p.join(
      'test',
      'tdd',
      feature,
      'fakes',
      '${slug}_fake.dart',
    );

    // Scenario: committed intent. An existing script is kept unless
    // --force; a channel/matrix drift between the argument and the
    // committed script is refused (drift is surfaced, never papered
    // over).
    var scenarioStatus = 'rewritten';
    final existingFile = File(scenarioPath);
    final existing = existingFile.existsSync()
        ? _loadScenarioOrNull(existingFile)
        : null;
    if (existing != null) {
      if (existing.channel != channel) {
        stderr.writeln(
          'zfa tdd fake: scenario at ${_rel(cwd, scenarioPath)} is bound '
          'to channel "${existing.channel}", not "$channel" — re-commit '
          'it with --force if the drift is intended.',
        );
        exitCode = 1;
        print(
          'fake: refused channel drift — channel=$channel '
          'feature=$feature slug=$slug scenario=$scenarioRelative',
        );
        _verdict
          ..exitClass = 'refused'
          ..outcome = VerdictOutcome.fail
          ..fix =
              're-commit the scenario with --force if the channel drift '
              'is intended'
          ..details['channel'] = channel
          ..details['slug'] = slug
          ..feature = feature;
        return;
      }
      if (platforms.isNotEmpty &&
          platforms.join(',') != existing.platforms.join(',') &&
          !force) {
        stderr.writeln(
          'zfa tdd fake: --platforms ${platforms.join(',')} disagrees '
          'with the committed matrix '
          '[${existing.platforms.join(', ')}] — pass --force to rewrite '
          'the scenario.',
        );
        exitCode = 1;
        print(
          'fake: refused platform-matrix drift — channel=$channel '
          'feature=$feature slug=$slug scenario=$scenarioRelative',
        );
        return;
      }
      if (!force) scenarioStatus = 'kept';
    }

    if (scenarioStatus == 'rewritten') {
      final starter = _starterScenario(channel, feature, platforms);
      await existingFile.parent.create(recursive: true);
      final encoder = const JsonEncoder.withIndent('  ');
      await existingFile.writeAsString(
        '${encoder.convert(starter.toJson())}\n',
      );
    }

    // The fake is always regenerated from the CURRENT binary (same
    // staleness contract as gen stubs, bug #683). When the scenario was
    // kept, the fake replays the COMMITTED matrix, not the flag's.
    var fakePlatforms = platforms;
    if (scenarioStatus == 'kept') {
      fakePlatforms = existing!.platforms;
    }
    await const ChannelFakeWriter().write(
      fakePath: fakePath,
      channel: channel,
      slug: slug,
      feature: feature,
      platforms: fakePlatforms,
    );

    print(
      'scenario: $scenarioStatus (${_rel(cwd, scenarioPath)}) — commit it '
      'as intent (issue #831)',
    );
    print(
      'fake: channel=$channel feature=$feature '
      'behavior=${behavior.isEmpty ? '-' : behavior} slug=$slug '
      'scenario=$scenarioRelative fake=$fakeRelative '
      'platforms=${fakePlatforms.join(',')} — scenario $scenarioStatus',
    );
    // Issue #969: the scenario status IS the exit class.
    _verdict
      ..exitClass = scenarioStatus
      ..outcome = VerdictOutcome.pass
      ..details['channel'] = channel
      ..details['slug'] = slug
      ..details['scenario'] = scenarioRelative
      ..feature = feature;
  }

  /// The starter scenario written for a fresh slug: one scripted method
  /// (`available` -> true) and a LOUD default — unscripted methods throw
  /// a PlatformException instead of returning a plausible null.
  ChannelScenario _starterScenario(
    String channel,
    String feature,
    List<String> platforms,
  ) => ChannelScenario(
    channel: channel,
    platforms: platforms,
    responses: {'available': const ChannelResponse.value(true)},
    defaultResponse: const ChannelResponse.error(
      errorCode: 'unscripted',
      errorMessage:
          'No scripted response for this method — extend the scenario '
          '(issue #831).',
    ),
  );

  /// Parse + validate the hosted-matrix tokens BEFORE any write (fail
  /// fast — an unknown platform must not leave a half-written intent).
  List<String> _parsePlatforms(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const [];
    final tokens = csv
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
    for (final token in tokens) {
      if (!ChannelScenario.supportedPlatforms.contains(token)) {
        usageException(
          'zfa tdd fake: unknown platform "$token" — supported: '
          '${_sortedPlatforms()}',
        );
      }
    }
    return tokens;
  }

  /// Parse an existing scenario for the drift checks; an unparseable
  /// committed script is a hard refusal (drift must be surfaced, and
  /// only --force may replace it).
  ChannelScenario _loadScenarioOrNull(File file) {
    try {
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      return ChannelScenario.fromJson(decoded);
    } on ChannelScenarioException catch (e) {
      stderr.writeln(
        'zfa tdd fake: existing scenario at ${file.path} violates the '
        'schema: $e — fix it or pass --force to rewrite the starter.',
      );
      exitCode = 1;
      throw StateError(
        'zfa tdd fake: existing scenario violates the schema — $e',
      );
    } on FormatException catch (e) {
      stderr.writeln(
        'zfa tdd fake: existing scenario at ${file.path} is not valid '
        'JSON: $e — fix it or pass --force to rewrite the starter.',
      );
      exitCode = 1;
      throw StateError(
        'zfa tdd fake: existing scenario is not valid JSON — $e',
      );
    }
  }

  void _validateFeatureSegment(String feature) {
    if (feature.contains('/') ||
        feature.contains(r'\') ||
        feature == '.' ||
        feature == '..' ||
        feature.isEmpty) {
      usageException(
        'zfa tdd fake: invalid feature "$feature": expected a single spec '
        'directory name such as 013-barcode, not a path.',
      );
    }
  }

  String _toSnakeCase(String s) => _slugify(s);

  String _rel(String cwd, String absolute) => p.relative(absolute, from: cwd);

  /// Snake-case slug: lowercase, every non-alphanumeric run collapses to
  /// a single underscore, no leading/trailing underscore.
  static String _slugify(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
