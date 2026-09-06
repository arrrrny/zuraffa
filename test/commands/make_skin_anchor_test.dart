// Issue #1112 — the generated per-view seam: `zfa make --skin
// --skin-anchor=signin-guest` emits one `debugTap<PascalAnchor>()`
// per anchor, so the function lookup is just `debugTapGuest()`.
library;

import 'package:code_builder/code_builder.dart';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/commands/make_command.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/view/builders/view_class_builder.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

void main() {
  group('issue #1112 — per-view debugTap seam (unit)', () {
    const builder = ViewClassBuilder();

    ViewClassSpec spec({List<String> anchors = const []}) => ViewClassSpec(
      viewName: 'SigninView',
      controllerName: 'SigninController',
      presenterName: 'SigninPresenter',
      entityName: 'Signin',
      repoFields: const [],
      routeFields: const [],
      repoPresenterArgs: const [],
      initialMethodCall: Block((b) => b),
      imports: const ['package:flutter/material.dart'],
      withState: false,
      withSkinAudit: true,
      skinAnchors: anchors,
    );

    test('T5.3 emits debugTapGuest delegating to debugTapAnchor', () {
      final src = builder.build(spec(anchors: ['signin-guest']));
      expect(
        src,
        contains(
          "Future<TapResult> debugTapGuest() => "
          "debugTapAnchor('zfa:signin-guest');",
        ),
      );
    });

    test('T5.4 multi-segment ids Pascal-case after the first segment', () {
      final src = builder.build(spec(anchors: ['signin-log-out']));
      expect(
        src,
        contains(
          "Future<TapResult> debugTapLogOut() => "
          "debugTapAnchor('zfa:signin-log-out');",
        ),
      );
    });

    test('T5.5 no anchors → no seam functions (output unchanged)', () {
      final src = builder.build(spec(anchors: []));
      expect(src, isNot(contains('debugTap')));
    });

    test('T5.6 every seam carries the issue doc pointer', () {
      final src = builder.build(spec(anchors: ['signin-guest']));
      expect(src, contains('issue #1112'));
    });
  });

  group('issue #1112 — the --skin-anchor make surface', () {
    test('T5.1 make exposes a repeatable --skin-anchor option', () {
      // The registry is lazily populated by the CLI's plugin loader;
      // register the view plugin the way bin/zfa.dart does, then the
      // make schema walk maps its `skin-anchor` array property to a
      // repeatable multi-option.
      final registry = PluginRegistry();
      registry.register(
        ViewPlugin(outputDir: Directory.systemTemp.path),
      );
      final command = MakeCommand(registry);
      expect(command.argParser.options, contains('skin-anchor'));
      expect(
        command.argParser.options['skin-anchor']!.isMultiple,
        isTrue,
      );
    });

    test('T5.2 the config carries skinAnchors from the parsed flags', () {
      final config = GeneratorConfig.fromJson({
        'name': 'Signin',
        'skin': true,
        'skin_anchor': ['signin-guest', 'signin-log-out'],
      }, 'Signin');
      expect(config.skinAnchors, const ['signin-guest', 'signin-log-out']);
      final empty = GeneratorConfig.fromJson({'name': 'Signin'}, 'Signin');
      expect(empty.skinAnchors, isEmpty);
    });

    test('T5.7 the view plugin schema declares skin-anchor (string array)', () {
      final schema = ViewPlugin(
        outputDir: Directory.systemTemp.path,
      ).configSchema;
      final properties = schema['properties'] as Map<String, dynamic>;
      // Schema keys follow the dashed convention ('layout-targets').
      final anchors = properties['skin-anchor'] as Map<String, dynamic>?;
      expect(anchors, isNotNull);
      expect(anchors!['type'], 'array');
    });
  });
}
