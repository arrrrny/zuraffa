#!/usr/bin/env dart

// Zuraffa CLI (Modular)
//
// Generates Clean Architecture components from simple command-line arguments.

import "package:zuraffa/src/zfa_cli.dart" as cli;
import "package:zuraffa/zuraffa.dart";

void main(List<String> arguments) {
  // Guarded boot (issue #2099): any uncaught error the CLI lets escape is
  // logged at SEVERE on Logger.root (and optionally reported as a failure
  // span) instead of vanishing into the console. This is the core CLI's
  // demonstration of the family-wide `runGuarded` surface.
  Zuraffa.runGuarded(() => cli.run(arguments));
}
