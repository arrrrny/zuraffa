Performance Benchmarks

Run generation benchmark:

  dart run benchmark/generation_benchmark.dart
  dart run benchmark/generation_benchmark.dart 10

Run memory benchmark:

  dart run benchmark/memory_benchmark.dart
  dart run benchmark/memory_benchmark.dart 5

Targets:
  - Standard full entity generation under 2s on a modern laptop
  - Peak RSS under 100MB
  - Large entity file (10k fields) handled without errors

Latest Results (2026-02-11):
  - Generation: iterations=5 min_ms=653 avg_ms=1052 max_ms=1925
  - Memory: iterations=3 avg_delta_mb=-11.0 peak_mb=769.3
