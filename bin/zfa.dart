#!/usr/bin/env dart

// ZFA CLI - Zuraffa Code Generator (Modular)
//
// Generates UseCases, Repositories, and VPC (View/Presenter/Controller) layers
// from simple command-line flags or JSON input.

import "package:zuraffa/src/zfa_cli.dart" as cli;
import "package:zuraffa/zuraffa.dart";

void main(List<String> arguments) {
  // Guarded boot (issue #2099): any uncaught error the CLI lets escape is
  // logged at SEVERE on Logger.root (and optionally reported as a failure
  // span) instead of vanishing into the console. This is the core CLI's
  // demonstration of the family-wide `runGuarded` surface.
  //
  // `onError` replaces the funnel's log-only default with the CLI's own exit
  // contract: the error still goes through the funnel, but it also reaches
  // stderr and sets the process exit code, so a failure before command
  // dispatch can never exit 0 silently. Only errors escaping `cli.run` get
  // here — the runner exits on every error it handles itself.
  Zuraffa.runGuarded(
    () => cli.run(arguments),
    onError: cli.reportUncaughtCliError,
  );
}
