import 'cancel_token.dart';

/// Strategy interface for pluggable data-fetching pipelines.
///
/// Defines HOW a piece of data is fetched and returned. Injected into
/// providers/services alongside other dependencies, making the pipeline
/// selection a construction-time concern rather than runtime branching.
///
/// This is analogous to [SyncStrategy] for sync-enabled repositories —
/// it is the swappable strategy that controls the fetch pipeline without
/// the caller needing to know which pipeline runs.
///
/// ## Naming contract
///
/// `Input` is the request descriptor (e.g. `UrlSpark`, `BarcodeSpark`).
/// `Output` is the domain result type (e.g. `Listing`, `BarcodeListing`).
///
/// ## Implementations
///
/// A strategy implementation should do exactly one thing: given an `Input`,
/// produce an `Output` using a specific pipeline (scraper config, AI, cache,
/// etc.). It should NOT contain selection logic — selection belongs in a
/// [StrategySelector] or in the use case that picks the strategy.
///
/// ## Example implementations
///
/// - `ScraperFetchStrategy`: uses a `ChannelConfig`-backed scraper pipeline
/// - `AiFetchStrategy`: scrapes with WebView + AI parser for unknown sites
/// - `FallbackFetchStrategy`: tries scraper first, falls back to AI on failure
///
/// ## Usage with use cases
///
/// ```dart
/// class GetUrlListingUseCase extends StreamUseCase<UrlListing, UrlSpark> {
///   final ListingService _service;
///   final FetchStrategy<UrlSpark, Listing> _strategy;
///
///   GetUrlListingUseCase(this._service, this._strategy);
///
///   @override
///   Stream<UrlListing> execute(UrlSpark params, CancelToken? cancelToken) {
///     return _strategy.fetch(params, cancelToken: cancelToken)
///         .map((l) => l.changeToUrlListing(url: l.url!));
///   }
/// }
/// ```
///
/// ## Usage with a selector
///
/// ```dart
/// final strategy = await selector.select(spark);
/// final listing = await strategy.fetchOne(spark);
/// ```
abstract class FetchStrategy<Input, Output> {
  /// Fetch a single result for [input].
  ///
  /// Throw an [AppFailure] subclass for expected/recoverable errors.
  /// Any other exception will propagate to the caller.
  ///
  /// Respects [cancelToken] for long-running operations.
  Future<Output> fetchOne(Input input, {CancelToken? cancelToken});

  /// Fetch results as a stream for [input].
  ///
  /// Use this when the pipeline naturally produces multiple results
  /// (e.g. paginated scraping, progressive enrichment).
  ///
  /// Default implementation wraps [fetchOne] in a single-element stream.
  /// Override for pipelines that produce multiple emissions.
  Stream<Output> fetch(Input input, {CancelToken? cancelToken}) async* {
    yield await fetchOne(input, cancelToken: cancelToken);
  }

  /// Whether this strategy can handle [input].
  ///
  /// A [StrategySelector] calls this to pick the right strategy.
  /// Return `true` if this strategy is applicable, `false` to skip.
  ///
  /// Default: always applicable. Override to restrict.
  Future<bool> canHandle(Input input) async => true;

  /// Human-readable name for logging and diagnostics.
  String get name;
}

/// Selects a [FetchStrategy] for a given [Input] at runtime.
///
/// Evaluates a list of candidates in priority order, returning the first
/// strategy for which [FetchStrategy.canHandle] returns `true`.
///
/// This is the only place where "which pipeline?" logic lives. Every
/// other component receives a pre-selected strategy and just runs it.
///
/// ## Example
///
/// ```dart
/// final selector = StrategySelector<UrlSpark, Listing>([
///   ScraperFetchStrategy(channelConfigRepo),   // preferred — fast
///   AiFetchStrategy(scrapeService),            // fallback — universal
/// ]);
///
/// // In the use case:
/// final strategy = await selector.select(spark);
/// final listing  = await strategy.fetchOne(spark);
/// ```
class StrategySelector<Input, Output> {
  final List<FetchStrategy<Input, Output>> _candidates;

  StrategySelector(this._candidates)
    : assert(
        _candidates.isNotEmpty,
        'StrategySelector requires at least one candidate',
      );

  /// Returns the first strategy that can handle [input].
  ///
  /// Throws [StateError] if no strategy can handle [input].
  Future<FetchStrategy<Input, Output>> select(Input input) async {
    for (final candidate in _candidates) {
      if (await candidate.canHandle(input)) {
        return candidate;
      }
    }
    throw StateError(
      'No FetchStrategy can handle input: $input. '
      'Registered strategies: ${_candidates.map((s) => s.name).join(', ')}',
    );
  }

  /// Returns ALL strategies that can handle [input], in priority order.
  ///
  /// Use this when you want to try strategies in sequence (fallback chain)
  /// rather than picking the best single match.
  Future<List<FetchStrategy<Input, Output>>> selectAll(Input input) async {
    final applicable = <FetchStrategy<Input, Output>>[];
    for (final candidate in _candidates) {
      if (await candidate.canHandle(input)) {
        applicable.add(candidate);
      }
    }
    return applicable;
  }
}
