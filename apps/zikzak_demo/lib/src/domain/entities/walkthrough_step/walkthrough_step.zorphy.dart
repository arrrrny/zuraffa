// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'walkthrough_step.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class WalkthroughStep {
  WalkthroughStep({
    required String this.id,
    required String this.title,
    required String this.description,
    String? this.imagePath,
    String? this.iconPath,
    required int this.order,
    String? this.buttonText,
    String? this.targetWidget,
  });

  factory WalkthroughStep.fromJson(Map<String, dynamic> json) =>
      _$WalkthroughStepFromJson(json);

  final String id;

  final String title;

  final String description;

  final String? imagePath;

  final String? iconPath;

  final int order;

  final String? buttonText;

  final String? targetWidget;

  WalkthroughStep copyWith({
    String? id,
    String? title,
    String? description,
    String? imagePath,
    String? iconPath,
    int? order,
    String? buttonText,
    String? targetWidget,
  }) {
    return WalkthroughStep(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      iconPath: iconPath ?? this.iconPath,
      order: order ?? this.order,
      buttonText: buttonText ?? this.buttonText,
      targetWidget: targetWidget ?? this.targetWidget,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  WalkthroughStep copyWithField<T>(Field<WalkthroughStep, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'title':
        return copyWith(title: value as String);
      case 'description':
        return copyWith(description: value as String);
      case 'imagePath':
        return copyWith(imagePath: value as String?);
      case 'iconPath':
        return copyWith(iconPath: value as String?);
      case 'order':
        return copyWith(order: value as int);
      case 'buttonText':
        return copyWith(buttonText: value as String?);
      case 'targetWidget':
        return copyWith(targetWidget: value as String?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'WalkthroughStep has no settable field with this name',
        );
    }
  }

  WalkthroughStep copyWithWalkthroughStep({
    String? id,
    String? title,
    String? description,
    String? imagePath,
    String? iconPath,
    int? order,
    String? buttonText,
    String? targetWidget,
  }) {
    return copyWith(
      id: id,
      title: title,
      description: description,
      imagePath: imagePath,
      iconPath: iconPath,
      order: order,
      buttonText: buttonText,
      targetWidget: targetWidget,
    );
  }

  WalkthroughStep patchWithWalkthroughStep([WalkthroughStepPatch? patchInput]) {
    final _patcher = patchInput ?? WalkthroughStepPatch();
    final _patchMap = _patcher.patchMap;
    return WalkthroughStep(
      id: _patchMap.containsKey(WalkthroughStep$.id)
          ? ((_patchMap[WalkthroughStep$.id] is Function)
                    ? _patchMap[WalkthroughStep$.id](this.id)
                    : (_patchMap[WalkthroughStep$.id] is Patch)
                    ? _patchMap[WalkthroughStep$.id].applyTo(this.id)
                    : _patchMap[WalkthroughStep$.id])
                as String
          : this.id,
      title: _patchMap.containsKey(WalkthroughStep$.title)
          ? ((_patchMap[WalkthroughStep$.title] is Function)
                    ? _patchMap[WalkthroughStep$.title](this.title)
                    : (_patchMap[WalkthroughStep$.title] is Patch)
                    ? _patchMap[WalkthroughStep$.title].applyTo(this.title)
                    : _patchMap[WalkthroughStep$.title])
                as String
          : this.title,
      description: _patchMap.containsKey(WalkthroughStep$.description)
          ? ((_patchMap[WalkthroughStep$.description] is Function)
                    ? _patchMap[WalkthroughStep$.description](this.description)
                    : (_patchMap[WalkthroughStep$.description] is Patch)
                    ? _patchMap[WalkthroughStep$.description].applyTo(
                        this.description,
                      )
                    : _patchMap[WalkthroughStep$.description])
                as String
          : this.description,
      imagePath: _patchMap.containsKey(WalkthroughStep$.imagePath)
          ? ((_patchMap[WalkthroughStep$.imagePath] is Function)
                    ? _patchMap[WalkthroughStep$.imagePath](this.imagePath)
                    : (_patchMap[WalkthroughStep$.imagePath] is Patch)
                    ? _patchMap[WalkthroughStep$.imagePath].applyTo(
                        this.imagePath,
                      )
                    : _patchMap[WalkthroughStep$.imagePath])
                as String?
          : this.imagePath,
      iconPath: _patchMap.containsKey(WalkthroughStep$.iconPath)
          ? ((_patchMap[WalkthroughStep$.iconPath] is Function)
                    ? _patchMap[WalkthroughStep$.iconPath](this.iconPath)
                    : (_patchMap[WalkthroughStep$.iconPath] is Patch)
                    ? _patchMap[WalkthroughStep$.iconPath].applyTo(
                        this.iconPath,
                      )
                    : _patchMap[WalkthroughStep$.iconPath])
                as String?
          : this.iconPath,
      order: _patchMap.containsKey(WalkthroughStep$.order)
          ? ((_patchMap[WalkthroughStep$.order] is Function)
                    ? _patchMap[WalkthroughStep$.order](this.order)
                    : (_patchMap[WalkthroughStep$.order] is Patch)
                    ? _patchMap[WalkthroughStep$.order].applyTo(this.order)
                    : _patchMap[WalkthroughStep$.order])
                as int
          : this.order,
      buttonText: _patchMap.containsKey(WalkthroughStep$.buttonText)
          ? ((_patchMap[WalkthroughStep$.buttonText] is Function)
                    ? _patchMap[WalkthroughStep$.buttonText](this.buttonText)
                    : (_patchMap[WalkthroughStep$.buttonText] is Patch)
                    ? _patchMap[WalkthroughStep$.buttonText].applyTo(
                        this.buttonText,
                      )
                    : _patchMap[WalkthroughStep$.buttonText])
                as String?
          : this.buttonText,
      targetWidget: _patchMap.containsKey(WalkthroughStep$.targetWidget)
          ? ((_patchMap[WalkthroughStep$.targetWidget] is Function)
                    ? _patchMap[WalkthroughStep$.targetWidget](
                        this.targetWidget,
                      )
                    : (_patchMap[WalkthroughStep$.targetWidget] is Patch)
                    ? _patchMap[WalkthroughStep$.targetWidget].applyTo(
                        this.targetWidget,
                      )
                    : _patchMap[WalkthroughStep$.targetWidget])
                as String?
          : this.targetWidget,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalkthroughStep &&
        id == other.id &&
        title == other.title &&
        description == other.description &&
        imagePath == other.imagePath &&
        iconPath == other.iconPath &&
        order == other.order &&
        buttonText == other.buttonText &&
        targetWidget == other.targetWidget;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.title,
      this.description,
      this.imagePath,
      this.iconPath,
      this.order,
      this.buttonText,
      this.targetWidget,
    );
  }

  @override
  String toString() {
    return 'WalkthroughStep(' +
        'id: ${id}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'description: ${description}' +
        ', ' +
        'imagePath: ${imagePath}' +
        ', ' +
        'iconPath: ${iconPath}' +
        ', ' +
        'order: ${order}' +
        ', ' +
        'buttonText: ${buttonText}' +
        ', ' +
        'targetWidget: ${targetWidget})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$WalkthroughStepToJson(this);
    _sanitizeJson(data);
    return data;
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('__typename');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

extension WalkthroughStepPropertyHelpers on WalkthroughStep {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasTitle {
    return this.title.isNotEmpty;
  }

  bool get noTitle {
    return this.title.isEmpty;
  }

  bool get hasDescription {
    return this.description.isNotEmpty;
  }

  bool get noDescription {
    return this.description.isEmpty;
  }

  bool get hasImagePath {
    return this.imagePath?.isNotEmpty == true;
  }

  bool get noImagePath {
    return this.imagePath?.isEmpty ?? true;
  }

  String get imagePathRequired {
    return this.imagePath ??
        (throw StateError('imagePath is required but was null'));
  }

  bool get hasIconPath {
    return this.iconPath?.isNotEmpty == true;
  }

  bool get noIconPath {
    return this.iconPath?.isEmpty ?? true;
  }

  String get iconPathRequired {
    return this.iconPath ??
        (throw StateError('iconPath is required but was null'));
  }

  bool get hasButtonText {
    return this.buttonText?.isNotEmpty == true;
  }

  bool get noButtonText {
    return this.buttonText?.isEmpty ?? true;
  }

  String get buttonTextRequired {
    return this.buttonText ??
        (throw StateError('buttonText is required but was null'));
  }

  bool get hasTargetWidget {
    return this.targetWidget?.isNotEmpty == true;
  }

  bool get noTargetWidget {
    return this.targetWidget?.isEmpty ?? true;
  }

  String get targetWidgetRequired {
    return this.targetWidget ??
        (throw StateError('targetWidget is required but was null'));
  }
}

extension WalkthroughStepSerialization on WalkthroughStep {
  Map<String, dynamic> toJson() {
    return _$WalkthroughStepToJson(this);
  }
}

enum WalkthroughStep$ {
  id,
  title,
  description,
  imagePath,
  iconPath,
  order,
  buttonText,
  targetWidget,
}

class WalkthroughStepPatch
    extends PatchBase<WalkthroughStep, WalkthroughStep$> {
  WalkthroughStep applyTo(WalkthroughStep entity) {
    return entity.patchWithWalkthroughStep(this);
  }

  WalkthroughStepPatch withId(String? value) {
    patchMap[WalkthroughStep$.id] = value;
    return this;
  }

  WalkthroughStepPatch withTitle(String? value) {
    patchMap[WalkthroughStep$.title] = value;
    return this;
  }

  WalkthroughStepPatch withDescription(String? value) {
    patchMap[WalkthroughStep$.description] = value;
    return this;
  }

  WalkthroughStepPatch withImagePath(String? value) {
    patchMap[WalkthroughStep$.imagePath] = value;
    return this;
  }

  WalkthroughStepPatch withIconPath(String? value) {
    patchMap[WalkthroughStep$.iconPath] = value;
    return this;
  }

  WalkthroughStepPatch withOrder(int? value) {
    patchMap[WalkthroughStep$.order] = value;
    return this;
  }

  WalkthroughStepPatch withButtonText(String? value) {
    patchMap[WalkthroughStep$.buttonText] = value;
    return this;
  }

  WalkthroughStepPatch withTargetWidget(String? value) {
    patchMap[WalkthroughStep$.targetWidget] = value;
    return this;
  }
}

/// Field descriptors for [WalkthroughStep] query construction
abstract final class WalkthroughStepFields {
  static const id = Field<WalkthroughStep, String>('id', _$id);

  static const title = Field<WalkthroughStep, String>('title', _$title);

  static const description = Field<WalkthroughStep, String>(
    'description',
    _$description,
  );

  static const imagePath = Field<WalkthroughStep, String?>(
    'imagePath',
    _$imagePath,
  );

  static const iconPath = Field<WalkthroughStep, String?>(
    'iconPath',
    _$iconPath,
  );

  static const order = Field<WalkthroughStep, int>('order', _$order);

  static const buttonText = Field<WalkthroughStep, String?>(
    'buttonText',
    _$buttonText,
  );

  static const targetWidget = Field<WalkthroughStep, String?>(
    'targetWidget',
    _$targetWidget,
  );

  static String _$id(WalkthroughStep e) {
    return e.id;
  }

  static String _$title(WalkthroughStep e) {
    return e.title;
  }

  static String _$description(WalkthroughStep e) {
    return e.description;
  }

  static String? _$imagePath(WalkthroughStep e) {
    return e.imagePath;
  }

  static String? _$iconPath(WalkthroughStep e) {
    return e.iconPath;
  }

  static int _$order(WalkthroughStep e) {
    return e.order;
  }

  static String? _$buttonText(WalkthroughStep e) {
    return e.buttonText;
  }

  static String? _$targetWidget(WalkthroughStep e) {
    return e.targetWidget;
  }
}

extension WalkthroughStepCompareE on WalkthroughStep {
  Map<String, dynamic> compareToWalkthroughStep(WalkthroughStep other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (title != other.title) {
      diff['title'] = () => other.title;
    }

    if (description != other.description) {
      diff['description'] = () => other.description;
    }

    if (imagePath != other.imagePath) {
      diff['imagePath'] = () => other.imagePath;
    }

    if (iconPath != other.iconPath) {
      diff['iconPath'] = () => other.iconPath;
    }

    if (order != other.order) {
      diff['order'] = () => other.order;
    }

    if (buttonText != other.buttonText) {
      diff['buttonText'] = () => other.buttonText;
    }

    if (targetWidget != other.targetWidget) {
      diff['targetWidget'] = () => other.targetWidget;
    }
    return diff;
  }
}
