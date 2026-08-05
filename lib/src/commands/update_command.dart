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
      throw Exception('Failed to check for updates: $e');
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
      throw Exception('Update failed. Try: dart pub global activate zuraffa');
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
      final latest = json['latest'] as Map<String, dynamic>?;
      return latest?['version'] as String? ?? 'unknown';
    } finally {
      client.close(force: true);
    }
  }

  /// Compare two semantic versions.
  /// Returns negative if [a] < [b], zero if equal, positive if [a] > [b].
  /// Follows SemVer: pre-release versions have lower precedence than stable.
  static int compareVersions(String a, String b) {
    final aParsed = parseVersion(a);
    final bParsed = parseVersion(b);

    // Compare major.minor.patch
    for (var i = 0; i < 3; i++) {
      if (aParsed.numeric[i] != bParsed.numeric[i]) {
        return aParsed.numeric[i] - bParsed.numeric[i];
      }
    }

    // If numeric parts are equal, compare pre-release identifiers
    // Per SemVer: stable > pre-release, pre-release compared lexically
    if (aParsed.preRelease == null && bParsed.preRelease == null) {
      return 0; // Both stable and equal
    }
    if (aParsed.preRelease == null) {
      return 1; // a is stable, b is pre-release: a > b
    }
    if (bParsed.preRelease == null) {
      return -1; // a is pre-release, b is stable: a < b
    }

    // Both have pre-release: compare lexically
    return aParsed.preRelease!.compareTo(bParsed.preRelease!);
  }

  /// Parse a version string like "1.2.3" or "1.2.3-alpha" into numeric and pre-release parts.
  /// Build metadata (after +) is ignored per SemVer.
  static ({List<int> numeric, String? preRelease}) parseVersion(String v) {
    // Strip build metadata (everything after +)
    final withoutBuild = v.split('+').first;

    // Split on - to separate numeric from pre-release
    final parts = withoutBuild.split('-');
    final numericPart = parts.first;
    final preRelease = parts.length > 1 ? parts.sublist(1).join('-') : null;

    final numericParts = numericPart.split('.');
    final numeric = [
      int.tryParse(numericParts.elementAtOrNull(0) ?? '0') ?? 0,
      int.tryParse(numericParts.elementAtOrNull(1) ?? '0') ?? 0,
      int.tryParse(numericParts.elementAtOrNull(2) ?? '0') ?? 0,
    ];

    return (numeric: numeric, preRelease: preRelease);
  }
}
