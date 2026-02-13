import '../core/context/progress_reporter.dart';

ProgressReporter createCliProgressReporter({
  required bool verbose,
  required bool quiet,
}) {
  if (quiet) {
    return NullProgressReporter();
  }
  return CliProgressReporter(verbose: verbose);
}
