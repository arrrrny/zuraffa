import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/tunnel/cloudflared_locator.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cloudflared_locator_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  String makeExecutable(String name) {
    final file = File(p.join(tmp.path, name))..createSync();
    // A real file is enough — the locator checks existence, the supervisor
    // owns execution.
    return file.path;
  }

  group('CloudflaredLocator', () {
    test('finds the binary in a declared PATH entry', () {
      makeExecutable('cloudflared');
      final locator = CloudflaredLocator(pathEntries: [tmp.path]);
      final info = locator.locate();
      expect(info, isNotNull);
      expect(info!.path, p.join(tmp.path, 'cloudflared'));
    });

    test('falls back to the extra candidates when PATH misses', () {
      final candidate = makeExecutable('cloudflared-named-candidate');
      final locator = CloudflaredLocator(
        pathEntries: [Directory.systemTemp.path],
        extraCandidates: [candidate],
      );
      final info = locator.locate();
      expect(info, isNotNull);
      expect(info!.path, candidate);
    });

    test('PATH entries win over extra candidates', () {
      makeExecutable('cloudflared');
      final candidate = makeExecutable('cloudflared-named-candidate');
      final locator = CloudflaredLocator(
        pathEntries: [tmp.path],
        extraCandidates: [candidate],
      );
      expect(locator.locate()!.path, p.join(tmp.path, 'cloudflared'));
    });

    test('returns null when the binary is nowhere', () {
      final locator = CloudflaredLocator(
        pathEntries: [p.join(tmp.path, 'missing-dir')],
        extraCandidates: const [],
      );
      expect(locator.locate(), isNull);
    });

    test('install remediation is non-empty and names an install path', () {
      expect(CloudflaredLocator.installRemediation, isNotEmpty);
      expect(
        CloudflaredLocator.installRemediation.toLowerCase(),
        contains('cloudflared'),
      );
    });

    test('queries the located binary for its version', () {
      makeExecutable('cloudflared');
      var askedExecutable = '';
      var askedArguments = <String>[];
      final locator = CloudflaredLocator(
        pathEntries: [tmp.path],
        versionRunner: (executable, arguments) {
          askedExecutable = executable;
          askedArguments = arguments;
          return ProcessResult(0, 0, 'cloudflared version 2026.1.1', '');
        },
      );
      final info = locator.locate();
      expect(info, isNotNull);
      expect(info!.version, '2026.1.1');
      expect(askedExecutable, p.join(tmp.path, 'cloudflared'));
      expect(askedArguments, ['--version']);
    });

    test('a failed version probe keeps the path with a null version', () {
      makeExecutable('cloudflared');
      final locator = CloudflaredLocator(
        pathEntries: [tmp.path],
        versionRunner: (executable, arguments) {
          return ProcessResult(0, 1, '', 'boom');
        },
      );
      final info = locator.locate();
      expect(info, isNotNull);
      expect(info!.path, isNotEmpty);
      expect(info.version, isNull);
    });
  });
}
