import '../../../core/ast/ast_helper.dart';
import '../../../core/context/file_system.dart';
import '../../../utils/method_extractor.dart';
import '../../../models/parsed_usecase_info.dart';

/// Shape-check staleness detection for the mock datasource lane
/// (issue #1570).
///
/// The lane's old skip decision was "file exists → skip" — an
/// existence check. A certified mock generated earlier (e.g.
/// `zfa mock create --methods=get`) kept its earlier member set while
/// `zfa make --methods=get,getList` appended the new members to the
/// interface, so interface and implementer drifted apart and the tree
/// stopped compiling (`non_abstract_class_inherits_abstract_member`,
/// `zfa build` gate red — the #1530 "coherence pass" failure family).
///
/// The detector replaces that decision with the same structural
/// comparison the mock certification performs (and the tdd lane's
/// stale-mirror comparison follows): the interface's declared member
/// set vs the mock class's implemented member set, both read from the
/// AST with no package resolution. Drift = interface members the mock
/// does not implement.
///
/// Fail-open: when the interface surface (file / class) or the mock
/// class cannot be read or parsed, the detector returns an empty list
/// — the lane keeps its pre-#1571 skip behavior instead of fabricating
/// members from nothing. Extra (invented) mock members are NOT drift:
/// only missing members are repairable (removing them is the
/// certification gate's report, never this lane's decision).
abstract final class MockStalenessDetector {
  /// Returns the interface members the mock at [mockPath] does not
  /// implement, in interface declaration order. Empty = in-sync or
  /// fail-open (no trustworthy surface to compare).
  static Future<List<ParsedUseCaseInfo>> detectMockStaleness({
    required String interfacePath,
    required String interfaceClass,
    required String mockPath,
    required String mockClass,
    FileSystem? fileSystem,
  }) async {
    final fs = fileSystem ?? const DefaultFileSystem();

    // 1. Interface members (AST — the certification's primitive).
    if (!await fs.exists(interfacePath)) return const [];
    final interfaceMembers = await MethodExtractor.extractMethodsFromInterface(
      interfacePath,
      interfaceClass,
      fileSystem: fs,
    );
    if (interfaceMembers.isEmpty) return const [];

    // 2. Implemented members of the mock class (AST — same parse as
    //    MockCertificationService.certify's implementedMethods).
    if (!await fs.exists(mockPath)) return const [];
    final helper = const AstHelper();
    final parseResult = await helper.parseFile(mockPath, fileSystem: fs);
    final unit = parseResult.unit;
    if (unit == null) return const [];
    final classNode = helper.findClass(unit, mockClass);
    if (classNode == null) return const [];
    final implemented = helper
        .findMethods(classNode)
        .map((m) => m.name.toString())
        .toSet();

    // 3. Drift = interface members the mock never declared.
    return [
      for (final member in interfaceMembers)
        if (!implemented.contains(member.fieldName)) member,
    ];
  }
}
