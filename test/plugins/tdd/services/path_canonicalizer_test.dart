// Direct unit tests for the shared missing-path canonicalizer
// `canonicalizeMissingPath` (lib/src/plugins/tdd/services/
// path_canonicalizer.dart) — the walk-up loop the command pins
// (U-V11/U-V12/U-V13, U-W3/U-1603e) can only observe through the
// inside/outside verdict of the containment guard (issue #1610).
//
// Spec: specs/1610-extract-canonicalize-missing-path/spec.md (FR-004,
// SC-2/SC-3). The four pins:
//   U1: the nearest EXISTING ancestor resolves through a SYMLINK — the
//       result is the resolved root form plus the re-appended missing
//       segments, never the raw alias form.
//   U2: nested missing segments are re-appended in ORIGINAL order — the
//       tail-order assertion the command pins cannot make (a two-segment
//       tail under a dropped-`.reversed` mutant still lands inside the
//       root, so only an exact-match expectation here can catch it).
//   U3: one-segment boundary — a missing leaf whose direct parent is an
//       existing symlinked directory: the parent's link resolves and the
//       basename is re-appended.
//   U4: root-boundary walk — a missing path directly under the (aliased)
//       root resolves the root and re-appends the basename. The helper's
//       defensive no-ancestor fallback (input returned unchanged) is NOT
//       assertable through the public surface: on POSIX the filesystem
//       root itself always resolves, so the walk never exhausts it — the
//       branch is documented as defensive in the helper's doc comment
//       (no fake filesystem seam: that would restructure the helper,
//       which the chore's hard constraint forbids).
//
// Windows skips per the repo's `onPlatform` convention (symlink creation
// may need privileges there).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/path_canonicalizer.dart';

void main() {
  late Directory root;
  late String aliasPath;
  late String resolvedRoot;

  setUp(() {
    root = Directory.systemTemp.createTempSync('tdd_canon_root_');
    // Sibling alias (the U-V11 fixture shape): deterministic on every
    // platform, no dependency on the temp dir itself being symlinked.
    aliasPath = '${root.path}_alias';
    Link(aliasPath).createSync(root.path);
    resolvedRoot = Directory(root.path).resolveSymbolicLinksSync();
    addTearDown(() {
      if (FileSystemEntity.isLinkSync(aliasPath)) {
        Link(aliasPath).deleteSync();
      }
      root.deleteSync(recursive: true);
    });
  });

  test(
    'U1: nearest existing ancestor behind a symlink resolves through the '
    'link and re-appends the missing segments',
    () async {
      // `<alias>/missing/subject.dart`: the alias exists, nothing under it
      // does. The walk-up resolves the ALIAS's target and re-appends
      // `missing/subject.dart`.
      final result = await canonicalizeMissingPath(
        p.join(aliasPath, 'missing', 'subject.dart'),
      );

      expect(result, p.join(resolvedRoot, 'missing', 'subject.dart'));
      expect(
        result,
        isNot(startsWith(aliasPath)),
        reason: 'the raw alias form must never leak into the result',
      );
    },
    onPlatform: {'windows': const Skip('symlink creation may need privileges')},
  );

  test(
    'U2: nested missing segments are re-appended in ORIGINAL order '
    '(the tail-order assertion the command pins cannot make)',
    () async {
      // Both middle segments missing: tail accumulates
      // [subject.dart, missing_b, missing_a] during the walk and MUST be
      // re-joined reversed. A dropped `.reversed` yields
      // `<resolvedRoot>/subject.dart/missing_b/missing_a` — a wrong path
      // no command-level inside/outside pin can distinguish from correct
      // (it still lands inside the root). The chain travels the ALIAS
      // form so a walk-up-skipping mutant (raw input returned) ALSO fails
      // the exact match even on hosts whose temp root is not itself
      // symlinked.
      final result = await canonicalizeMissingPath(
        p.join(aliasPath, 'missing_a', 'missing_b', 'subject.dart'),
      );

      expect(
        result,
        p.join(resolvedRoot, 'missing_a', 'missing_b', 'subject.dart'),
      );
    },
    onPlatform: {'windows': const Skip('symlink creation may need privileges')},
  );

  test(
    'U3: a missing leaf whose direct parent is an existing symlinked '
    'directory resolves the parent and re-appends the basename',
    () async {
      // One-segment tail boundary: the walk stops at the FIRST existing
      // ancestor (`link_parent`), resolves it to `real_parent`, and
      // re-appends exactly one segment.
      Directory(p.join(root.path, 'real_parent')).createSync();
      Link(
        p.join(root.path, 'link_parent'),
      ).createSync(p.join(root.path, 'real_parent'));
      addTearDown(() {
        final link = Link(p.join(root.path, 'link_parent'));
        if (FileSystemEntity.isLinkSync(link.path)) link.deleteSync();
      });

      final result = await canonicalizeMissingPath(
        p.join(root.path, 'link_parent', 'subject.dart'),
      );

      expect(result, p.join(resolvedRoot, 'real_parent', 'subject.dart'));
    },
    onPlatform: {'windows': const Skip('symlink creation may need privileges')},
  );

  test(
    'U4: a missing path directly under an aliased root resolves the root '
    'and re-appends the basename (root-boundary walk)',
    () async {
      // The loop's normal exit with a one-segment tail over the aliased
      // root; the defensive no-ancestor fallback (input returned unchanged
      // when even the filesystem root fails to resolve) is unreachable
      // through the public surface on POSIX — the root always resolves —
      // and is documented as defensive in the helper's doc comment rather
      // than faked with a seam (the chore forbids restructuring the
      // helper).
      final result = await canonicalizeMissingPath(
        p.join(aliasPath, 'subject.dart'),
      );

      expect(result, p.join(resolvedRoot, 'subject.dart'));
    },
    onPlatform: {'windows': const Skip('symlink creation may need privileges')},
  );
}
