import 'dart:async';
import 'package:zuraffa/zuraffa.dart';

/// Benchmark comparing Signal (O(1)) vs Stream (O(N)) read performance.
///
/// Run with: `dart run benchmark/signal_benchmark.dart`
void main() async {
  const iterations = 100000;

  print('=== Zuraffa Signal Pipeline Benchmark ===\n');

  // ── Benchmark 1: Signal read (O(1)) ──
  final signal = Signal<int>(42);
  final sw1 = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    final _ = signal.value; // O(1) direct read
  }
  sw1.stop();
  print('Signal read ($iterations iterations): ${sw1.elapsedMicroseconds} µs');
  print('  → ${sw1.elapsedMicroseconds / iterations} µs per read (O(1))\n');

  // ── Benchmark 2: Stream read (O(N) with listener overhead) ──
  final controller = StreamController<int>.broadcast();
  final stream = controller.stream;
  stream.listen((_) {});
  controller.add(42);
  await Future.delayed(Duration.zero); // let listener process

  final sw2 = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    // To read a stream's current value, you need a listener + buffer.
    // This simulates the overhead: creating a new listener each time.
    stream.listen((_) {});
  }
  sw2.stop();
  print(
    'Stream listener creation ($iterations iterations): ${sw2.elapsedMicroseconds} µs',
  );
  print(
    '  → ${sw2.elapsedMicroseconds / iterations} µs per read (O(N) overhead)\n',
  );

  // ── Benchmark 3: Signal notification (O(1) per listener) ──
  final signal3 = Signal<int>(0);
  final listenerCount = [1, 10, 100];
  for (final count in listenerCount) {
    final subs = <SignalSubscription>[];
    var notifications = 0;
    for (var i = 0; i < count; i++) {
      subs.add(signal3.listen((_) => notifications++));
    }

    final sw3 = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      signal3.value = i;
    }
    sw3.stop();

    for (final sub in subs) {
      sub.cancel();
    }
    print(
      'Signal notify with $count listeners ($iterations writes): ${sw3.elapsedMicroseconds} µs',
    );
    print('  → ${sw3.elapsedMicroseconds / iterations} µs per write');
    print('  → Total notifications: $notifications\n');
  }

  // ── Benchmark 4: Stream notification (O(N) per listener) ──
  for (final count in listenerCount) {
    final controller = StreamController<int>.broadcast();
    final stream = controller.stream;
    var notifications = 0;
    final subs = <StreamSubscription<int>>[];
    for (var i = 0; i < count; i++) {
      subs.add(stream.listen((_) => notifications++));
    }

    final sw4 = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      controller.add(i);
    }
    sw4.stop();

    for (final sub in subs) {
      sub.cancel();
    }
    print(
      'Stream notify with $count listeners ($iterations writes): ${sw4.elapsedMicroseconds} µs',
    );
    print('  → ${sw4.elapsedMicroseconds / iterations} µs per write');
    print('  → Total notifications: $notifications\n');
  }

  print('=== End Benchmark ===');
}
