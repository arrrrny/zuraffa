// Spec 1653-trim-heavy-deps (issue #1661) — the light trace seam pin.
//
// U3: core's hook-context assembly reads trace ids from the light
//     `TraceObserver` seam, never from the otel-backed concrete class.
//     The seam's default yields nulls (today's no-span behavior), and
//     the observability companion replaces the instance when enabled.
//     (FR-009 — seams are contracts, heavy implementations are plugins.)
//
// The source-level half mirrors the no-JIT spawn scan precedent: core
// sources are swept for the old concrete reads so the de-typing cannot
// silently regress.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/trace_observer.dart';

String _repoRoot(String from) {
  var dir = Directory(from).absolute.path;
  while (!File(p.join(dir, 'pubspec.yaml')).existsSync()) {
    final parent = p.dirname(dir);
    if (parent == dir) {
      throw StateError('repo root with pubspec.yaml not found above $from');
    }
    dir = parent;
  }
  return dir;
}

/// A recording observer used to prove the seam is replaceable.
class _FixedTraceObserver implements TraceObserver {
  @override
  String? get currentTraceId => 'trace-1653';

  @override
  String? get currentSpanId => 'span-1653';
}

void main() {
  group('U3: the TraceObserver seam (FR-009)', () {
    test('the default observer yields null trace/span ids', () {
      // Restore the default around the probe.
      final saved = TraceObserver.instance;
      addTearDown(() => TraceObserver.instance = saved);
      TraceObserver.resetToDefault();

      expect(TraceObserver.instance.currentTraceId, isNull);
      expect(TraceObserver.instance.currentSpanId, isNull);
    });

    test('the seam is replaceable — a registered observer is read', () {
      final saved = TraceObserver.instance;
      addTearDown(() => TraceObserver.instance = saved);

      TraceObserver.instance = _FixedTraceObserver();
      expect(TraceObserver.instance.currentTraceId, 'trace-1653');
      expect(TraceObserver.instance.currentSpanId, 'span-1653');
    });

    test('core sources read the seam, not the otel-backed concrete '
        'class (the de-typing pin)', () {
      final root = _repoRoot(Directory.current.path);
      final offenders = <String>[];
      for (final relative in [
        'lib/src/core/hook.dart',
        'lib/src/domain/usecase.dart',
        'lib/src/domain/stream_usecase.dart',
      ]) {
        final content = File(p.join(root, relative)).readAsStringSync();
        if (content.contains('OtelTracer')) offenders.add(relative);
        if (!content.contains('TraceObserver')) offenders.add(relative);
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the trace fields must come from the light TraceObserver '
            'seam — these files still reference the otel-backed '
            'OtelTracer:\n${offenders.join('\n')}',
      );
    });
  });
}
