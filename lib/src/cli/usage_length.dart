/// Single source of truth for the CLI's usage/help wrap width.
///
/// Used by the runner-level parser (`usageLineLength` in cli_runner.dart)
/// and by command-level formatters (e.g. TddCommand's wrapped usage), so the
/// help surfaces can never drift apart (review of #1460).
const int kUsageLineLength = 120;
