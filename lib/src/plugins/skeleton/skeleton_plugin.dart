/// The skeleton plugin: generates self-contained feature scaffolds ("bones").
library;

import 'package:args/command_runner.dart';

import '../../core/plugin_system/cli_aware_plugin.dart';
import '../../core/plugin_system/plugin_interface.dart';
import 'bone_command.dart';

/// Skeleton plugin implementing [CliAwarePlugin].
class SkeletonPlugin extends ZuraffaPlugin implements CliAwarePlugin {
  /// Creates the skeleton plugin.
  SkeletonPlugin();

  @override
  String get id => 'skeleton';

  @override
  String get name => 'Skeleton';

  @override
  String get version => '1.0.0';

  @override
  List<String> get runAfter => const [];

  @override
  Command<void> createCommand() => BoneCommand();
}
