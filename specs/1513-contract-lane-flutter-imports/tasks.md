# Tasks — Spec 1513 contract lane flutter imports (MVP-first)

- [x] T001. [behavior: B1] [behavior: B2] Contract test writer import surface:
      flutterTest=true → flutter_test; default → package:test (parseable
      template). Traces FR-1 / SC-1 / AS-1.
- [x] T002. [behavior: B3] Unparseable template honors flutterTest. Traces
      FR-4 / SC-4 / AS-1.
- [x] T003. [behavior: B4] [behavior: B5] Subject import: package URI under
      lib/ (promoted static), relative fallback outside lib/ or without
      pubspec. Traces FR-2 / SC-2 / AS-2.
- [x] T004. [behavior: B6] packageSubjectImportFor direct pins (under-lib →
      package URI; no pubspec → null; outside lib → null). Traces FR-2 / SC-2.
- [x] T005. [behavior: B7] _writersFor threads flutterTest end to end: gen
      contract:A1 on a flutter-dependency fixture emits flutter_test; pure-Dart
      fixture keeps package:test. Traces FR-3 / SC-3 / SC-6.
- [x] T006. [behavior: B8] Byte-stability: default writer output for the
      no-pubspec fixture shape is byte-identical to the pre-fix render
      (golden). Traces FR-5 / SC-5.
- [x] T007. Implement the fix (contract_test_writer.dart: flutterTest field +
      _testImport + resolved subject import in both templates;
      behavior_test_writer.dart: promote packageSubjectImportFor;
      gen_command.dart: thread flutterTest). Traces FR-1..FR-4.
- [x] T008. Non-behavioural: scoped analyze green (tdd services + commands),
      dart format clean, contract_kind_1007 suite still green.
