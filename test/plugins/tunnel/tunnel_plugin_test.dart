import 'package:test/test.dart';
import 'package:zuraffa/src/commands/tunnel_command.dart';
import 'package:zuraffa/src/plugins/tunnel/tunnel_plugin.dart';

void main() {
  group('TunnelPlugin', () {
    test('id is "tunnel"', () {
      expect(TunnelPlugin(outputDir: 'lib/src').id, 'tunnel');
    });

    test('name is "Tunnel Plugin"', () {
      expect(TunnelPlugin(outputDir: 'lib/src').name, 'Tunnel Plugin');
    });

    test('version is 1.0.0', () {
      expect(TunnelPlugin(outputDir: 'lib/src').version, '1.0.0');
    });

    test('is a runtime plugin: no codegen capabilities', () {
      final plugin = TunnelPlugin(outputDir: 'lib/src');
      expect(plugin.capabilities, isEmpty);
    });

    test('createCommand returns a TunnelCommand named "tunnel"', () {
      final plugin = TunnelPlugin(outputDir: 'lib/src');
      final cmd = plugin.createCommand();
      expect(cmd, isA<TunnelCommand>());
      expect(cmd.name, 'tunnel');
    });

    test('TunnelCommand registers run + status subcommands', () {
      final plugin = TunnelPlugin(outputDir: 'lib/src');
      final cmd = plugin.createCommand() as TunnelCommand;
      expect(cmd.subcommands.keys, containsAll(['run', 'status']));
    });
  });
}
