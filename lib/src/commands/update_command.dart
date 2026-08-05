import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../version.dart';

/// CLI command to check for and apply updates to the zfa CLI.
class UpdateCommand extends Command<void> {
  static const _pubDevUrl = 'https://pub.dev/api/packages/zuraffa';
  static const _timeout = Duration(seconds: 15);

  @override
  String get name => 'update';

  @override
  String get description => 'Check for updates and update the installed zfa CLI.';

  UpdateCommand() {
    argParser.addFlag(
      'dry-run',
      negatable: false,
      help: 'Check for updates without installing.',
    );
    argParser.addFlag(
      'force',
      negatable: false,
      help: 'Force reinstall the latest version even if already up to date.',
    );
  }

  @override
  Future<void> run() async {
    final dryRun = argResults!['dry-run'] == true;
    final force = argResults!['force'] == true;

    final current = version;
    print('Current version: $current');
    print('Checking pub.dev for latest version...');

    String latest;
    try {
      latest = await _fetchLatestVersion();
    } catch (e) {
      print('  Failed to check for updates: $e');
      exit(1);
    }

    print('Latest version:  $latest');

    final cmp = compareVersions(current, latest);

    if (cmp >= 0 && !force) {
      print('');
      print('zfa is already up to date.');
      return;
    }

    if (dryRun) {
      print('');
      print('Update available: $current -> $latest');
      print('Run "zfa update" to install.');
      return;
    }

    print('');
    if (force && cmp >= 0) {
      print('Force reinstalling zuraffa...');
    } else {
      print('Updating zuraffa $current -> $latest...');
    }

    final result = await Process.run(
      'dart',
      ['pub', 'global', 'activate', 'zuraffa'],
    ).timeout(_timeout * 4);

    if (result.exitCode == 0) {
      print(result.stdout.toString().trim());
      print('');
      print('Update complete. Restart your terminal or run:');
      print('  zfa --version');
    } else {
      final stderr = result.stderr.toString().trim();
      if (stderr.isNotEmpty) {
        print('  $stderr');
      }
      final stdout = result.stdout.toString().trim();
      if (stdout.isNotEmpty) {
        print('  $stdout');
      }
      print('Update failed. Try: dart pub global activate zuraffa');
      exit(1);
    }
  }

  /// Fetch the latest version string from the pub.dev API.
  Future<String> _fetchLatestVersion() async {
    final client = HttpClient()
      ..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(Uri.parse(_pubDevUrl));
      request.headers.set('User-Agent', 'zfa update');
      final response = await request.close().timeout(_timeout);

      if (response.statusCode != 200) {
        throw HttpException(
          'pub.dev returned ${response.statusCode}',
          uri: Uri.parse(_pubDevUrl),
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['latest'] as String? ?? 'unknown';
    } finally {
      client.close(force: true);
    }
  }

  /// Compare two semantic versions.
  /// Returns negative if [a] < [b], zero if equal, positive if [a] > [b].
  static int compareVersions(String a, String b) {
    final aParts = parseVersion(a);
    final bParts = parseVersion(b);
    for (var i = 0; i < 3; i++) {
      if (aParts[i] != bParts[i]) return aParts[i] - bParts[i];
    }
    return 0;
  }

  /// Parse a version string like "1.2.3" into a list of 3 ints.
  /// Pre-release/build suffixes are stripped before parsing.
  static List<int> parseVersion(String v) {
    final clean = v.split(RegExp(r'[-+]')).first;
    final parts = clean.split('.');
    return [
      int.tryParse(parts.elementAtOrNull(0) ?? '0') ?? 0,
      int.tryParse(parts.elementAtOrNull(1) ?? '0') ?? 0,
      int.tryParse(parts.elementAtOrNull(2) ?? '0') ?? 0,
    ];
  }
}
