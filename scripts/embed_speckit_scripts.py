#!/usr/bin/env python3
"""Re-embeds the framework's canonical speckit helper scripts into
lib/src/commands/speckit_scaffolding.dart (issue #1417).

Re-run this script whenever .specify/scripts/bash/{common,setup-plan,
check-prerequisites,setup-tasks}.sh evolve in the framework repo, then run
the drift-guard test (U-1417-b9) to confirm.

Scope guard (review fix): this tool replaces ONLY the marker-delimited
constants region in the target file —

    // BEGIN EMBEDDED SCRIPTS
    ...
    // END EMBEDDED SCRIPTS

Everything else (the writer logic) is left byte-identical, so a Dart-side
fix can never be silently reverted by a re-embed. The tool refuses to run
when the markers are missing instead of falling back to a full rewrite.
"""
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
TARGET = REPO / "lib/src/commands/speckit_scaffolding.dart"
SCRIPTS = ["common.sh", "setup-plan.sh", "check-prerequisites.sh", "setup-tasks.sh"]

BEGIN = "// BEGIN EMBEDDED SCRIPTS"
END = "// END EMBEDDED SCRIPTS"

names = {
    "common.sh": "kSpeckitCommonSh",
    "setup-plan.sh": "kSpeckitSetupPlanSh",
    "check-prerequisites.sh": "kSpeckitCheckPrerequisitesSh",
    "setup-tasks.sh": "kSpeckitSetupTasksSh",
}


def region_text() -> str:
    blocks = []
    for name in SCRIPTS:
        content = (REPO / ".specify/scripts/bash" / name).read_text()
        assert "'''" not in content, f"{name} contains triple quotes"
        blocks.append(
            f"/// Byte-identical embed of `.specify/scripts/bash/{name}`\n"
            f"const String {names[name]} = r'''{content}''';\n"
        )
    return "\n".join(blocks)


def main() -> int:
    text = TARGET.read_text()
    if BEGIN not in text or END not in text:
        print(
            f"error: {TARGET} is missing the {BEGIN!r}/{END!r} markers; "
            "refusing to rewrite the file. Restore the markers around the "
            "embedded constants first."
        )
        return 1
    if text.index(END) < text.index(BEGIN):
        print(f"error: {END!r} appears before {BEGIN!r} in {TARGET}.")
        return 1

    start = text.index(BEGIN)
    end = text.index(END, start)
    out = text[:start] + BEGIN + "\n" + region_text() + text[end:]
    TARGET.write_text(out)
    print(f"re-embedded {len(SCRIPTS)} scripts into {TARGET}")

    # byte-identity sanity check: strip each constant back out and compare
    ok = True
    for name in SCRIPTS:
        m = re.search(r"const String " + names[name] + r" = r'''(.*?)''';", out, re.S)
        embedded = m.group(1)
        original = (REPO / ".specify/scripts/bash" / name).read_text()
        identical = embedded == original
        ok = ok and identical
        print(f"  {name}: byte-identical={identical}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
