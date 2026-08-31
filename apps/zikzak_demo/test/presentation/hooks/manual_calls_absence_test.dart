import 'dart:io';

import 'package:test/test.dart';

/// C5 (spec 011 US3): zero manual engagement call sites in the presentation
/// layer. Engagement capture is fully automated via the EngagementHook
/// registered in main() — no controller may call the legacy
/// CreateTelemetryEventUseCase or any trackXxx()-style method.
void main() {
  test(
    'C5: presentation layer contains zero manual engagement calls',
    () async {
      final presentationDir = Directory(
        '${Directory.current.path}/lib/src/presentation',
      );
      expect(
        presentationDir.existsSync(),
        isTrue,
        reason: 'lib/src/presentation must exist for the scan',
      );

      final offenders = <String>[];
      await for (final entity in presentationDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = await entity.readAsLines();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('CreateTelemetryEventUseCase') ||
              lines[i].contains('track')) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'manual engagement calls must be removed (bug 501, criterion C5); '
            'found ${offenders.length} offending line(s)',
      );
    },
  );
}
