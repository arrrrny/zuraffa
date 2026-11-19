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
  Zuraffa.runGuarded(() => cli.run(arguments));
}
