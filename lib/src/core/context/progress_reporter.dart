enum ProgressEvent { started, completed, failed, warning, info }

class ProgressReport {
  final String message;
  final int percent;
  final String? currentStep;
  final int totalSteps;
  final int completedSteps;
  final ProgressEvent event;

  const ProgressReport({
    required this.message,
    required this.percent,
    required this.currentStep,
    required this.totalSteps,
    required this.completedSteps,
    required this.event,
  });

  const ProgressReport.started(String message, int totalSteps)
    : this(
        message: message,
        percent: 0,
        currentStep: null,
        totalSteps: totalSteps,
        completedSteps: 0,
        event: ProgressEvent.started,
      );

  ProgressReport nextStep(String step) {
    final nextCompleted = completedSteps + 1;
    final nextPercent = totalSteps > 0
        ? (nextCompleted / totalSteps * 100).round()
        : 0;
    return ProgressReport(
      message: message,
      percent: nextPercent,
      currentStep: step,
      totalSteps: totalSteps,
      completedSteps: nextCompleted,
      event: ProgressEvent.info,
    );
  }

  const ProgressReport.completed()
    : this(
        message: '',
        percent: 100,
        currentStep: null,
        totalSteps: 0,
        completedSteps: 0,
        event: ProgressEvent.completed,
      );

  const ProgressReport.failed(String error)
    : this(
        message: error,
        percent: 0,
        currentStep: null,
        totalSteps: 0,
        completedSteps: 0,
        event: ProgressEvent.failed,
      );

  const ProgressReport.warning(String message)
    : this(
        message: message,
        percent: 0,
        currentStep: null,
        totalSteps: 0,
        completedSteps: 0,
        event: ProgressEvent.warning,
      );

  const ProgressReport.info(String message)
    : this(
        message: message,
        percent: 0,
        currentStep: null,
        totalSteps: 0,
        completedSteps: 0,
        event: ProgressEvent.info,
      );
}

abstract class ProgressReporter {
  void report(ProgressReport report);

  void started(String message, int totalSteps);
  void update(String currentStep);
  void completed();
  void failed(String error);
  void warning(String message);
  void info(String message);
}

class NullProgressReporter implements ProgressReporter {
  @override
  void report(ProgressReport report) {}

  @override
  void started(String message, int totalSteps) {}

  @override
  void update(String currentStep) {}

  @override
  void completed() {}

  @override
  void failed(String error) {}

  @override
  void warning(String message) {}

  @override
  void info(String message) {}
}

class CliProgressReporter implements ProgressReporter {
  final bool verbose;
  int _totalSteps = 0;
  int _completedSteps = 0;
  ProgressReport? _report;

  CliProgressReporter({this.verbose = false});

  @override
  void report(ProgressReport report) {
    switch (report.event) {
      case ProgressEvent.started:
        _totalSteps = report.totalSteps;
        _completedSteps = report.completedSteps;
        print('[_] ${report.message}');
        break;
      case ProgressEvent.info:
        if (verbose) {
          print('    → ${report.currentStep ?? report.message}');
        }
        break;
      case ProgressEvent.completed:
        print('[✓] Completed');
        break;
      case ProgressEvent.failed:
        print('[✗] ${report.message}');
        break;
      case ProgressEvent.warning:
        print('[!] ${report.message}');
        break;
    }
  }

  @override
  void started(String message, int totalSteps) {
    _report = ProgressReport.started(message, totalSteps);
    report(_report!);
  }

  @override
  void update(String currentStep) {
    _report ??= ProgressReport.started('', 0);
    _report = _report!.nextStep(currentStep);
    _completedSteps = _report!.completedSteps;
    if (verbose) {
      report(_report!);
      return;
    }
    final percent = _totalSteps > 0
        ? (_completedSteps / _totalSteps * 100).round()
        : 0;
    final filled = percent ~/ 10;
    final bar = '${'=' * filled}>${' ' * (10 - filled)}';
    print('[$bar] $_completedSteps/$_totalSteps');
  }

  @override
  void completed() {
    report(const ProgressReport.completed());
    print('');
  }

  @override
  void failed(String error) {
    report(ProgressReport.failed(error));
  }

  @override
  void warning(String message) {
    report(ProgressReport.warning(message));
  }

  @override
  void info(String message) {
    if (verbose) {
      report(ProgressReport.info(message));
    }
  }
}
