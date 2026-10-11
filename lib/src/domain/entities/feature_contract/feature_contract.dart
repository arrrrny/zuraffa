/// FeatureContract (spec 1098, issue #1098): the typed carrier of feature
/// identity across slice, xray, FeaturePlugin and engine receipts.
///
/// Feature identity in the plugin subsystem was a raw, unvalidated `String`
/// everywhere it traveled: slice took `required String feature`, xray
/// subcommands took `feature: String`, all FeaturePlugin capabilities read
/// `args['name'] as String`, and no plugin could ask "does this feature
/// exist, what does it own, where are its boundaries?" — because no such
/// object existed.
///
/// This entity is that object: one definition of 'feature' with
/// [id], [displayName], [entities], [boundary] (what slice hands the
/// agent), [routes] (the skin/route contract table), [xrayLayer] (deck
/// layer assignment) and [argSchema] (capability argument validation).
///
/// Zorphy codegen (build_runner) generates the immutable concrete class:
/// run `dart run build_runner build --delete-conflicting-outputs`.
library;

import 'package:zorphy/zorphy.dart';

import '../../../plugins/slice/models/slice_boundary.dart';
import 'xray_layer.dart';

export 'xray_layer.dart';

part 'feature_contract.zorphy.dart';

/// The typed feature contract (spec 1098).
///
/// Collection surfaces are nullable in the generated constructor and
/// normalize to empty defaults at the read sites (registry parser,
/// decorators, compose) — construct through [parseFeatureContractYaml] or
/// pass explicit values.
@Zorphy()
abstract class $FeatureContract {
  /// Stable kebab-case feature id (e.g. `login`, `login-skin`).
  String get id;

  /// Human-readable name (e.g. `Login`).
  String get displayName;

  /// Entities scoped to the feature.
  List<String>? get entities;

  /// Slice boundary: what the agent receives for this feature.
  SliceBoundary? get boundary;

  /// The skin/route contract table.
  Set<String>? get routes;

  /// XRay deck layer assignment.
  XRayLayer? get xrayLayer;

  /// Capability argument validation schema (JSON Schema map).
  Map<String, dynamic>? get argSchema;
}
