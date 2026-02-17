import 'base_plugin_command.dart';
import '../plugins/feature/feature_plugin.dart';

class FeatureCommand extends PluginCommand {
  @override
  final FeaturePlugin plugin;

  FeatureCommand(this.plugin) : super(plugin);

  @override
  String get name => 'feature';

  @override
  String get description => 'Scaffold full features';

  @override
  Future<void> run() async {
    // Default behavior if no subcommand is called
    print('Use "zfa feature scaffold" to generate a feature.');
  }
}
