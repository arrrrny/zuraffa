/// Preset for common generation patterns.
class GenerationPreset {
  final String name;
  final String description;
  final List<String> plugins;
  final List<String> methods;

  const GenerationPreset({
    required this.name,
    required this.description,
    required this.plugins,
    this.methods = const ['get', 'getList', 'create', 'update', 'delete'],
  });

  static const entityCrud = GenerationPreset(
    name: 'entity-crud',
    description: 'Entity + Repository + UseCases for CRUD operations',
    plugins: ['repository', 'usecase'],
  );

  static const vpc = GenerationPreset(
    name: 'vpc',
    description: 'View + Presenter + Controller for presentation layer',
    plugins: ['view', 'presenter', 'controller'],
    methods: ['get', 'getList', 'create', 'update', 'delete'],
  );

  static const vpcWithState = GenerationPreset(
    name: 'vpc-state',
    description: 'VPC with State management',
    plugins: ['view', 'presenter', 'controller', 'state'],
  );

  static const fullStack = GenerationPreset(
    name: 'full-stack',
    description:
        'Complete feature: Repository, UseCases, VPC, DI, Routes, Tests',
    plugins: [
      'repository',
      'usecase',
      'view',
      'presenter',
      'controller',
      'di',
      'route',
      'test',
    ],
  );

  static const dataLayer = GenerationPreset(
    name: 'data-layer',
    description: 'Repository + DataSource for data layer',
    plugins: ['repository', 'datasource'],
  );

  static const all = [entityCrud, vpc, vpcWithState, fullStack, dataLayer];

  static GenerationPreset? byName(String name) {
    for (final preset in all) {
      if (preset.name == name) return preset;
    }
    return null;
  }
}
