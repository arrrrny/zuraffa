/// Base contract for the parameter objects a `UseCase` receives.
///
/// The concrete parameter families ([QueryParams], [ListQueryParams],
/// [CreateParams], [UpdateParams], [DeleteParams], [ToggleParams],
/// [InitializationParams], [Settings], [Credentials]) are zorphy v3 value
/// types that implement this interface. It carries no generated surface of
/// its own: under zorphy v3 the former `$$Params` source class would become a
/// `final class` that no sibling value could extend or implement, so the
/// contract is a plain Dart interface instead.
abstract interface class Params {
  /// Optional additional parameters.
  Map<String, dynamic>? get params;
}
