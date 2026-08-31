// Fixture-corpus helper (spec 050-corpus-import, task T001).
//
// Builds the 3-feature import matrix from spec.md SC-001 / quickstart.md
// scenario 2 under Directory.systemTemp:
//
//   001-clean         spec.md with a Given/When/Then acceptance scenario + FR
//   002-no-scenarios  prose-only spec.md (no acceptance scenarios)
//   003-speckit       spec.md + speckit-era foreign artifacts (checklists/,
//                     tdd/test-list.md in a foreign format)
//
// Shared by the importer unit tests (test/cli/services/) and the command /
// acceptance tests (test/commands/) so both drive the same corpus shape the
// spec's independent test describes.
library;

import 'dart:io';

/// A throwaway fixture corpus rooted at [root].
///
/// Growth (user story 2) and divergence editing are exposed as methods so
/// tests mutate the SOURCE corpus without touching imported targets.
class FixtureCorpus {
  /// Root directory of the corpus (a corpus root: feature dirs, no
  /// spec.md directly at this level).
  final Directory root;

  const FixtureCorpus(this.root);

  /// The three fixture feature names, in lexicographic order.
  static const List<String> featureNames = [
    '001-clean',
    '002-no-scenarios',
    '003-speckit',
  ];

  /// Creates the 3-feature fixture corpus under a fresh system temp dir.
  static FixtureCorpus create() {
    final root = Directory.systemTemp.createTempSync('zfa_fixture_corpus_');
    addFeature(root.path, '001-clean', cleanSpec('001-clean'));
    addFeature(
      root.path,
      '002-no-scenarios',
      proseOnlySpec('002-no-scenarios'),
    );
    addFeature(
      root.path,
      '003-speckit',
      cleanSpec('003-speckit'),
      foreignArtifacts: true,
    );
    return FixtureCorpus(root);
  }

  /// Appends a new feature directory with [specMd] to the corpus (US2's
  /// corpus growth: re-import must import only these).
  static void addFeature(
    String corpusRoot,
    String name,
    String specMd, {
    bool foreignArtifacts = false,
  }) {
    final dir = Directory('$corpusRoot/$name')..createSync(recursive: true);
    File('${dir.path}/spec.md').writeAsStringSync(specMd);
    if (foreignArtifacts) {
      _addForeignArtifacts(dir.path);
    }
  }

  static void _addForeignArtifacts(String featureDir) {
    Directory('$featureDir/checklists').createSync(recursive: true);
    File('$featureDir/checklists/requirements.md').writeAsStringSync(
      '# Requirements checklist (speckit-era artifact)\n\n'
      '- [x] spec drafted\n',
    );
    Directory('$featureDir/tdd').createSync(recursive: true);
    File('$featureDir/tdd/test-list.md').writeAsStringSync(
      '# Test List (foreign speckit dialect)\n\n'
      '| id  | behavior | traces | kind | state | test |\n'
      '| --- | -------- | ------ | ---- | ----- | ---- |\n'
      '| A1  | legacy row | AC-1 | example | DONE | somewhere_test.dart |\n',
    );
  }

  /// A loop-ready spec: numbered Given/When/Then acceptance scenarios
  /// plus bolded functional requirements — exactly the dialect
  /// `SpecParser` (and therefore `zfa tdd plan`) consumes.
  static String cleanSpec(String feature) =>
      '# Feature Specification: $feature\n'
      '\n'
      '## Acceptance Scenarios\n'
      '\n'
      '1. **Given** a calculator **When** the user adds two numbers '
      '**Then** the sum is returned\n'
      '\n'
      '1. **Given** a calculator with a stored value **When** the user '
      'clears it **Then** the calculator is empty\n'
      '\n'
      '## Functional Requirements\n'
      '\n'
      '- **FR-001**: adds two numbers and returns the sum\n'
      '- **FR-002**: clears the stored value on demand\n';

  /// A prose-only spec: no Given/When/Then blocks, no bolded FRs. Loop
  /// planning must refuse it; corpus import must still copy it verbatim.
  static String proseOnlySpec(String feature) =>
      '# Feature Specification: $feature\n'
      '\n'
      'This feature is described in prose only. There is no acceptance '
      'scenario section and no functional requirement list, so the TDD '
      'loop cannot derive a test list from it without inventing '
      'requirements.\n';

  /// Rewrites a feature's spec.md content (US2's divergence source).
  void editSpec(String name, String newSpecMd) {
    File('${root.path}/$name/spec.md').writeAsStringSync(newSpecMd);
  }

  /// Adds two growth features (011/012) — quickstart scenario 4 shape.
  void grow() {
    addFeature(root.path, '011-growth-a', cleanSpec('011-growth-a'));
    addFeature(root.path, '012-growth-b', cleanSpec('012-growth-b'));
  }

  /// Deletes the fixture corpus from disk.
  void dispose() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}
