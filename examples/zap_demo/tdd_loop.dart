// ZAP demo (spec 071, issue #809) — the TDD loop fixture driven through
// the protocol.
//
// A pure-SDK script (no package imports, no pubspec): three real checks.
//
//   dart examples/zap_demo/tdd_loop.dart red     -> exit 1 (a REAL failing
//                                                   check, by design)
//   dart examples/zap_demo/tdd_loop.dart green   -> exit 0 (the fix)
//   dart examples/zap_demo/tdd_loop.dart verify  -> exit 0 (the suite)
//
// The `red` command runs the PRE-fix calculator (add is broken), `green`
// runs the POST-fix calculator, `verify` runs all three checks against
// the fixed implementation. This is the honest TDD shape the ZAP
// discipline rules certify: a red that exits non-zero because the check
// genuinely fails, a green that exits zero because the fix genuinely
// works.

import 'dart:io';

const _buggyAdd = 6; // add(2, 3) with the bug: 2 + 3 * something
const _fixedAdd = 5; // add(2, 3) fixed

int addPreFix(int a, int b) => a + b + 1; // the bug: off by one
int addPostFix(int a, int b) => a + b; // the fix

void main(List<String> args) {
  final mode = args.isNotEmpty ? args.first : '';
  switch (mode) {
    case 'red':
      _red();
      break;
    case 'green':
      _green();
      break;
    case 'verify':
      _verify();
      break;
    default:
      stderr.writeln('usage: dart tdd_loop.dart red|green|verify');
      exit(64);
  }
}

void _red() {
  final actual = addPreFix(2, 3);
  if (actual == _buggyAdd) {
    stdout.writeln(
      'ZAP DEMO red: 1 check FAILED (by design) — '
      'add(2, 3) returned $actual, expected $_fixedAdd',
    );
    exit(1); // the honest red: the test exists and FAILS
  }
  stdout.writeln(
    'ZAP DEMO red: unexpected — the pre-fix add no longer '
    'fails the check (returned $actual)',
  );
  exit(2);
}

void _green() {
  final actual = addPostFix(2, 3);
  if (actual == _fixedAdd) {
    stdout.writeln(
      'ZAP DEMO green: 1 check passed (by design) — '
      'add(2, 3) returned $actual, expected $_fixedAdd',
    );
    exit(0);
  }
  stdout.writeln(
    'ZAP DEMO green: check FAILED — add(2, 3) returned '
    '$actual, expected $_fixedAdd',
  );
  exit(1);
}

void _verify() {
  final results = <(String, bool)>[
    ('add(2, 3) == $_fixedAdd', addPostFix(2, 3) == _fixedAdd),
    ('add(0, 0) == 0', addPostFix(0, 0) == 0),
    ('add(-1, 1) == 0', addPostFix(-1, 1) == 0),
  ];
  final failed = results.where((r) => !r.$2).toList();
  if (failed.isEmpty) {
    stdout.writeln(
      'ZAP DEMO verify: ${results.length} checks passed — '
      'the suite is green',
    );
    exit(0);
  }
  stdout.writeln(
    'ZAP DEMO verify: ${failed.length}/${results.length} '
    'checks FAILED',
  );
  exit(1);
}
