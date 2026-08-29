/// The UI node registry — the shadcn plugin's authoritative component
/// vocabulary (spec 024, FR-001 / FR-002 / FR-007).
///
/// Combines the built-in component set (mirroring the flutter-shadcn-ui
/// fork's UINode system) with project-specific composites registered under
/// `.zfa/ui/components/*.json` (written by `zfa make <Name> --ui`).
library;

import 'dart:convert';
import 'dart:io';

/// One property of a node definition.
class UiPropDefinition {
  const UiPropDefinition({
    required this.name,
    required this.type,
    this.enumValues,
    this.defaultValue,
    this.required = false,
  });

  /// Property name, e.g. `label`.
  final String name;

  /// `string` | `number` | `boolean` | `enum`.
  final String type;

  /// Allowed values when [type] is `enum`.
  final List<String>? enumValues;

  final Object? defaultValue;

  /// Whether the property must be present.
  final bool required;

  Map<String, dynamic> toJson() => _sorted({
    if (required) 'required': true,
    ...{
      'type': type == 'enum' ? 'string' : type,
      if (enumValues != null) 'enum': enumValues,
      if (defaultValue != null) 'default': defaultValue,
      'description': description,
    },
  });

  String get description =>
      '$name property (${enumValues != null ? 'one of ${enumValues!.join(", ")}' : type}).';

  static Map<String, dynamic> _sorted(Map<String, dynamic> map) {
    final keys = map.keys.toList()..sort();
    return {for (final key in keys) key: map[key]};
  }

  factory UiPropDefinition.fromJson(String name, Map<String, dynamic> json) {
    final enumValues = json['enum'];
    final type = json['type'];
    return UiPropDefinition(
      name: name,
      type: type is String ? type : 'string',
      enumValues: enumValues is List
          ? enumValues.map((e) => e.toString()).toList()
          : null,
      defaultValue: json['default'],
      required: json['required'] == true,
    );
  }
}

/// Children constraint of a node definition.
class UiChildrenConstraint {
  const UiChildrenConstraint({this.min, this.max, this.allowedChildTypes});

  /// Minimum number of children (null = unconstrained).
  final int? min;

  /// Maximum number of children (null = unconstrained; 0 = leaf).
  final int? max;

  /// Allowed child node types (null = any vocabulary type).
  final List<String>? allowedChildTypes;

  Map<String, dynamic> toJson() => _sorted({
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (allowedChildTypes != null) 'allowed': allowedChildTypes,
  });

  static Map<String, dynamic> _sorted(Map<String, dynamic> map) {
    final keys = map.keys.toList()..sort();
    return {for (final key in keys) key: map[key]};
  }

  factory UiChildrenConstraint.fromJson(Map<String, dynamic> json) {
    final allowed = json['allowed'];
    final min = json['min'];
    final max = json['max'];
    return UiChildrenConstraint(
      // Registrations are hand-editable, so a non-int bound is treated as
      // absent rather than escaping as an uncaught CastError.
      min: min is int ? min : null,
      max: max is int ? max : null,
      allowedChildTypes: allowed is List
          ? allowed.map((e) => e.toString()).toList()
          : null,
    );
  }
}

/// A node definition in the vocabulary.
class UiNodeDefinition {
  const UiNodeDefinition({
    required this.name,
    required this.category,
    required this.props,
    required this.children,
    this.isComposite = false,
  });

  /// Vocabulary key, e.g. `card` (snake_case).
  final String name;

  /// `layout` | `content` | `input` | `feedback` | `composite` ...
  final String category;

  final Map<String, UiPropDefinition> props;

  final UiChildrenConstraint children;

  final bool isComposite;
}

/// Raised when a composite registration cannot be loaded.
class NodeRegistryException implements Exception {
  NodeRegistryException(this.message);
  final String message;

  @override
  String toString() => 'NodeRegistryException: $message';
}

/// The authoritative node registry (spec Key Entities).
class NodeRegistry {
  NodeRegistry._(
    this._definitions, {
    required this.maxDepth,
    required this.maxNodes,
    required this.styleTokens,
  });

  static const int defaultMaxDepth = 12;
  static const int defaultMaxNodes = 256;

  static const List<String> defaultStyleTokens = [
    'accent',
    'danger',
    'muted',
    'neutral',
    'primary',
    'secondary',
    'success',
    'tertiary',
    'warning',
  ];

  final Map<String, UiNodeDefinition> _definitions;

  /// Maximum tree depth (structural rule).
  final int maxDepth;

  /// Maximum total node count (structural rule).
  final int maxNodes;

  /// The canonical style token vocabulary.
  final List<String> styleTokens;

  /// Built-in component definitions (the fork's UINode system mirror).
  static final Map<String, UiNodeDefinition> builtIns = _buildBuiltIns();

  /// A registry with only the built-in vocabulary.
  factory NodeRegistry.builtInsOnly() => NodeRegistry._(
    Map.unmodifiable(builtIns),
    maxDepth: defaultMaxDepth,
    maxNodes: defaultMaxNodes,
    styleTokens: defaultStyleTokens,
  );

  /// An empty registry (minimal schema export edge case).
  factory NodeRegistry.empty() => NodeRegistry._(
    const {},
    maxDepth: defaultMaxDepth,
    maxNodes: defaultMaxNodes,
    styleTokens: defaultStyleTokens,
  );

  /// Loads the built-ins merged with project composites from
  /// `<projectRoot>/.zfa/ui/components/*.json`.
  factory NodeRegistry.load({required String projectRoot}) {
    final merged = Map<String, UiNodeDefinition>.of(builtIns);
    final dir = Directory('$projectRoot/.zfa/ui/components');
    if (dir.existsSync()) {
      final files =
          dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        final registration = _readRegistration(file);
        merged[registration.name] = registration;
      }
    }
    return NodeRegistry._(
      Map.unmodifiable(merged),
      maxDepth: defaultMaxDepth,
      maxNodes: defaultMaxNodes,
      styleTokens: defaultStyleTokens,
    );
  }

  static UiNodeDefinition _readRegistration(File file) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('registration root is not an object');
      }
      json = decoded;
    } on FormatException catch (e) {
      throw NodeRegistryException(
        'Composite registration ${file.path} is not valid JSON: ${e.message}',
      );
    }
    final rawName = json['name'];
    final name = rawName is String ? rawName : null;
    if (name == null || name.isEmpty) {
      throw NodeRegistryException(
        'Composite registration ${file.path} is missing a string "name" '
        'field.',
      );
    }
    final propsJson = json['props'];
    final props = <String, UiPropDefinition>{};
    if (propsJson is Map<String, dynamic>) {
      for (final entry in propsJson.entries) {
        final value = entry.value;
        props[entry.key] = value is Map<String, dynamic>
            ? UiPropDefinition.fromJson(entry.key, value)
            : UiPropDefinition(name: entry.key, type: 'string');
      }
    }
    final childrenJson = json['children'];
    final children = childrenJson is Map<String, dynamic>
        ? UiChildrenConstraint.fromJson(childrenJson)
        : const UiChildrenConstraint(min: 0, max: 32);
    return UiNodeDefinition(
      name: name,
      category: json['category'] is String
          ? json['category'] as String
          : 'composite',
      props: props,
      children: children,
      isComposite: true,
    );
  }

  // ------------------------------------------------------------------
  // Lookups
  // ------------------------------------------------------------------

  bool contains(String name) => _definitions.containsKey(name);

  UiNodeDefinition? definition(String name) => _definitions[name];

  bool isComposite(String name) => _definitions[name]?.isComposite ?? false;

  /// Built-in names only (reserved, FR-007).
  Set<String> get reservedNames => builtIns.keys.toSet();

  /// Built-in names in sorted order.
  List<String> get builtInNames {
    final names = builtIns.keys.toList()..sort();
    return names;
  }

  /// Project composite names in sorted order.
  List<String> get compositeNames {
    final names =
        _definitions.values
            .where((d) => d.isComposite)
            .map((d) => d.name)
            .toList()
          ..sort();
    return names;
  }

  /// All vocabulary names in sorted order.
  List<String> get allNames {
    final names = _definitions.keys.toList()..sort();
    return names;
  }

  /// Definitions sorted by name (deterministic export order).
  List<UiNodeDefinition> get sortedDefinitions {
    final definitions = _definitions.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return definitions;
  }

  // ------------------------------------------------------------------
  // Built-in vocabulary (mirror of the flutter-shadcn-ui fork's UINode set)
  // ------------------------------------------------------------------

  static Map<String, UiNodeDefinition> _buildBuiltIns() {
    UiNodeDefinition def(
      String name,
      String category, {
      Map<String, UiPropDefinition> props = const {},
      UiChildrenConstraint? children,
    }) => UiNodeDefinition(
      name: name,
      category: category,
      props: props,
      children: children ?? const UiChildrenConstraint(min: 0, max: 32),
    );

    const variants = ['primary', 'secondary', 'outline', 'ghost', 'danger'];

    return {
      'root': def(
        'root',
        'layout',
        children: const UiChildrenConstraint(min: 1, max: 1),
      ),
      'container': def(
        'container',
        'layout',
        props: {
          'padding': const UiPropDefinition(
            name: 'padding',
            type: 'enum',
            enumValues: ['none', 'sm', 'md', 'lg'],
            defaultValue: 'md',
          ),
          'align': const UiPropDefinition(
            name: 'align',
            type: 'enum',
            enumValues: ['start', 'center', 'end', 'stretch'],
          ),
        },
      ),
      'card': def(
        'card',
        'layout',
        props: {
          'title': const UiPropDefinition(name: 'title', type: 'string'),
          'elevation': const UiPropDefinition(
            name: 'elevation',
            type: 'enum',
            enumValues: ['flat', 'raised', 'overlay'],
            defaultValue: 'raised',
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 8),
      ),
      'row': def(
        'row',
        'layout',
        props: {
          'gap': const UiPropDefinition(name: 'gap', type: 'number'),
          'crossAxisAlignment': const UiPropDefinition(
            name: 'crossAxisAlignment',
            type: 'enum',
            enumValues: ['start', 'center', 'end'],
          ),
        },
      ),
      'column': def(
        'column',
        'layout',
        props: {'gap': const UiPropDefinition(name: 'gap', type: 'number')},
      ),
      'list': def(
        'list',
        'layout',
        props: {
          'direction': const UiPropDefinition(
            name: 'direction',
            type: 'enum',
            enumValues: ['vertical', 'horizontal'],
            defaultValue: 'vertical',
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 64),
      ),
      'divider': def(
        'divider',
        'layout',
        props: {
          'orientation': const UiPropDefinition(
            name: 'orientation',
            type: 'enum',
            enumValues: ['horizontal', 'vertical'],
            defaultValue: 'horizontal',
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'text': def(
        'text',
        'content',
        props: {
          'value': const UiPropDefinition(name: 'value', type: 'string'),
          'size': const UiPropDefinition(
            name: 'size',
            type: 'enum',
            enumValues: ['xs', 'sm', 'md', 'lg', 'xl'],
            defaultValue: 'md',
          ),
          'weight': const UiPropDefinition(
            name: 'weight',
            type: 'enum',
            enumValues: ['normal', 'medium', 'bold'],
            defaultValue: 'normal',
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'heading': def(
        'heading',
        'content',
        props: {
          'value': const UiPropDefinition(name: 'value', type: 'string'),
          'level': const UiPropDefinition(
            name: 'level',
            type: 'enum',
            enumValues: ['h1', 'h2', 'h3', 'h4'],
            defaultValue: 'h2',
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'label': def(
        'label',
        'content',
        props: {'value': const UiPropDefinition(name: 'value', type: 'string')},
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'image': def(
        'image',
        'content',
        props: {
          'src': const UiPropDefinition(name: 'src', type: 'string'),
          'alt': const UiPropDefinition(name: 'alt', type: 'string'),
          'fit': const UiPropDefinition(
            name: 'fit',
            type: 'enum',
            enumValues: ['cover', 'contain', 'fill'],
            defaultValue: 'cover',
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'avatar': def(
        'avatar',
        'content',
        props: {
          'src': const UiPropDefinition(name: 'src', type: 'string'),
          'fallback': const UiPropDefinition(
            name: 'fallback',
            type: 'string',
            defaultValue: '?',
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'badge': def(
        'badge',
        'content',
        props: {
          'value': const UiPropDefinition(name: 'value', type: 'string'),
          'tone': const UiPropDefinition(
            name: 'tone',
            type: 'enum',
            enumValues: ['default', 'success', 'warning', 'danger'],
            defaultValue: 'default',
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'button': def(
        'button',
        'input',
        props: {
          'label': const UiPropDefinition(name: 'label', type: 'string'),
          'variant': const UiPropDefinition(
            name: 'variant',
            type: 'enum',
            enumValues: variants,
            defaultValue: 'primary',
          ),
          'size': const UiPropDefinition(
            name: 'size',
            type: 'enum',
            enumValues: ['sm', 'md', 'lg'],
            defaultValue: 'md',
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'input': def(
        'input',
        'input',
        props: {
          'placeholder': const UiPropDefinition(
            name: 'placeholder',
            type: 'string',
          ),
          'value': const UiPropDefinition(name: 'value', type: 'string'),
          'keyboard': const UiPropDefinition(
            name: 'keyboard',
            type: 'enum',
            enumValues: ['text', 'number', 'email', 'password'],
            defaultValue: 'text',
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'textarea': def(
        'textarea',
        'input',
        props: {
          'placeholder': const UiPropDefinition(
            name: 'placeholder',
            type: 'string',
          ),
          'rows': const UiPropDefinition(
            name: 'rows',
            type: 'number',
            defaultValue: 3,
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'checkbox': def(
        'checkbox',
        'input',
        props: {
          'checked': const UiPropDefinition(
            name: 'checked',
            type: 'boolean',
            defaultValue: false,
          ),
          'label': const UiPropDefinition(name: 'label', type: 'string'),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'switch': def(
        'switch',
        'input',
        props: {
          'checked': const UiPropDefinition(
            name: 'checked',
            type: 'boolean',
            defaultValue: false,
          ),
          'label': const UiPropDefinition(name: 'label', type: 'string'),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'select': def(
        'select',
        'input',
        props: {
          'placeholder': const UiPropDefinition(
            name: 'placeholder',
            type: 'string',
          ),
          'value': const UiPropDefinition(name: 'value', type: 'string'),
        },
        children: const UiChildrenConstraint(
          min: 0,
          max: 32,
          allowedChildTypes: ['option'],
        ),
      ),
      'option': def(
        'option',
        'input',
        props: {
          'value': const UiPropDefinition(name: 'value', type: 'string'),
          'label': const UiPropDefinition(name: 'label', type: 'string'),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'slider': def(
        'slider',
        'input',
        props: {
          'min': const UiPropDefinition(
            name: 'min',
            type: 'number',
            defaultValue: 0,
          ),
          'max': const UiPropDefinition(
            name: 'max',
            type: 'number',
            defaultValue: 100,
          ),
          'value': const UiPropDefinition(
            name: 'value',
            type: 'number',
            defaultValue: 0,
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'progress': def(
        'progress',
        'feedback',
        props: {
          'value': const UiPropDefinition(
            name: 'value',
            type: 'number',
            defaultValue: 0,
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 0),
      ),
      'tooltip': def(
        'tooltip',
        'feedback',
        props: {
          'message': const UiPropDefinition(name: 'message', type: 'string'),
        },
        children: const UiChildrenConstraint(min: 0, max: 4),
      ),
      'alert': def(
        'alert',
        'feedback',
        props: {
          'title': const UiPropDefinition(name: 'title', type: 'string'),
          'message': const UiPropDefinition(name: 'message', type: 'string'),
          'tone': const UiPropDefinition(
            name: 'tone',
            type: 'enum',
            enumValues: ['info', 'success', 'warning', 'danger'],
            defaultValue: 'info',
          ),
        },
        children: const UiChildrenConstraint(min: 0, max: 4),
      ),
    };
  }
}
