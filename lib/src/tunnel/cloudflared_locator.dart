/// Locates the `cloudflared` binary (specs/1724-zuraffa-tunnel - issue
/// #2045, FR-005).
///
/// PATH first, then the common install locations. The tool never bundles or
/// downloads cloudflared (see the spec's Assumptions): when nothing is
/// found, [installRemediation] is what the command prints.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

class CloudflaredInfo {
  const CloudflaredInfo({required this.path, this.version});

  final String path;

  /// Best-effort version string; `null` when the probe fails — the path is
  /// still usable.
  final String? version;
}

/// The `Process.runSync` seam for the version probe (hermetic tests).
typedef CloudflaredVersionRunner =
    ProcessResult Function(String executable, List<String> arguments);

class CloudflaredLocator {
  const CloudflaredLocator({
    List<String>? pathEntries,
    List<String>? extraCandidates,
    CloudflaredVersionRunner? versionRunner,
  }) : _pathEntries = pathEntries,
       _extraCandidates = extraCandidates,
       _versionRunner = versionRunner;

  static const String _executable = 'cloudflared';

  static const List<String> _defaultCandidates = [
    '/usr/local/bin/cloudflared',
    '/opt/homebrew/bin/cloudflared',
  ];

  /// What `zfa tunnel` prints when the binary is absent — the machine-
  /// actionable line ends with the protocol's `--> fix:` shape.
  static const String installRemediation =
      'cloudflared was not found on PATH or in the common install locations '
      '(/usr/local/bin, /opt/homebrew/bin).\n'
      '--> fix: install cloudflared — `brew install cloudflare/cloudflare/cloudflared` '
      '(macOS), or download the binary from '
      'https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/ '
      'and put it on PATH.';

  final List<String>? _pathEntries;
  final List<String>? _extraCandidates;
  final CloudflaredVersionRunner? _versionRunner;

  /// The located binary, or `null` when it is nowhere on this machine.
  CloudflaredInfo? locate() {
    for (final dir in pathEntries) {
      final candidate = p.join(dir, _executable);
      if (File(candidate).existsSync()) return _describe(candidate);
    }
    for (final candidate in extraCandidates) {
      if (File(candidate).existsSync()) return _describe(candidate);
    }
    return null;
  }

  List<String> get pathEntries =>
      _pathEntries ??
      (Platform.environment['PATH']?.split(Platform.isWindows ? ';' : ':') ??
          const <String>[]);

  List<String> get extraCandidates => _extraCandidates ?? _defaultCandidates;

  CloudflaredInfo _describe(String path) {
    final runner = _versionRunner ?? _defaultVersionRunner;
    try {
      final result = runner(path, ['--version']);
      if (result.exitCode != 0) return CloudflaredInfo(path: path);
      final match = RegExp(
        r'(\d+\.\d+(?:\.\d+)*)',
      ).firstMatch('${result.stdout}');
      return CloudflaredInfo(path: path, version: match?.group(1));
    } on Exception {
      return CloudflaredInfo(path: path);
    }
  }

  static ProcessResult _defaultVersionRunner(
    String executable,
    List<String> arguments,
  ) => Process.runSync(executable, arguments);
}
