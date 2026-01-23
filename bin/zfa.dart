#!/usr/bin/env dart
// ZFA CLI - Zuraffa Code Generator (Modular)
//
// Generates UseCases, Repositories, and VPC (View/Presenter/Controller) layers
// from simple command-line flags or JSON input.

import "package:zuraffa/src/zfa_cli.dart" as cli;

void main(List<String> arguments) {
  cli.run(arguments);
}
