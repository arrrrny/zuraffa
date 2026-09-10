/// Single source of truth for the CLI's usage/help wrap width.
///
/// Used by the runner-level parser (`usageLineLength` in cli_runner.dart)
/// and by command-level formatters (e.g. TddCommand's wrapped usage), so
/// those help surfaces can never drift apart. Other commands' subcommand
/// help does not use this constant.
const int kUsageLineLength = 120;
