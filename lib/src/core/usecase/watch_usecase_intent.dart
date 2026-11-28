import 'package:zorphy_annotation/zorphy_annotation.dart' show ZorphyIntentBase;

/// Adapts legacy generator params to the v8 watch-usecase intent contract.
class WatchUseCaseIntent<Params> implements ZorphyIntentBase {
  const WatchUseCaseIntent(this.params);

  final Params params;
}
