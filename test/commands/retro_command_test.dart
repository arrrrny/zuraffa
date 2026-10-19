import "package:test/test.dart";
import "package:zuraffa/src/cli/cli_runner.dart";

void main() {
  test("retro command is registered", () async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(["retro", "--help"]);
    expect(out, isNot(contains("Unknown command")));
    expect(out, contains("retro"));
  });

  test("retro scan subcommand is registered", () async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(["retro", "scan", "--help"]);
    expect(out, isNot(contains("Unknown command")));
    expect(out, contains("scan"));
  });
}
