/// Annotation classes for middleware decorators: `@RequiresAuth`, `@Retry`, `@TrackEvent`.
///
/// These cross-cutting decorators wrap UseCase execution with security,
/// resilience, and telemetry concerns without polluting domain code.
library;

/// Authorization mode for `@RequiresAuth`.
enum AuthorizationMode {
  /// The user must possess **all** listed roles.
  all,

  /// The user must possess **at least one** of the listed roles.
  any,
}

/// Role hierarchy for authorization checks.
///
/// Built-in roles support implicit hierarchy: `admin` implies `manager`
/// implies `user` implies `guest`.
class Role {
  const Role(this.name, {this.level = 0});

  /// The display name of the role.
  final String name;

  /// Numeric level for hierarchy comparison. Higher = more privileged.
  final int level;

  // ── Built-in roles ──

  static const Role guest = Role('guest', level: 0);
  static const Role user = Role('user', level: 1);
  static const Role manager = Role('manager', level: 2);
  static const Role admin = Role('admin', level: 3);

  /// Check whether [candidate] satisfies [requiredRole] according to
  /// the built-in hierarchy.
  ///
  /// `admin` satisfies `admin`, `manager`, `user`, and `guest`.
  static bool satisfies(Role candidate, Role requiredRole) {
    return candidate.level >= requiredRole.level;
  }

  @override
  bool operator ==(Object other) => other is Role && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'Role.$name';
}

/// Backoff strategy for `@Retry`.
enum BackoffStrategy {
  /// Fixed delay between attempts.
  fixed,

  /// Exponential delay: `base * 2^attempt`, capped at [maxDelay].
  exponential,

  /// Exponential with jitter to avoid thundering herd.
  decorrelatedJitter,
}

/// Marks a UseCase class or method as requiring authentication/authorization.
///
/// The DDA pipeline generates a security interceptor that checks the
/// user's role(s) before allowing execution. Unauthorized calls emit
/// `AppFailure.session` without executing the UseCase.
class RequiresAuth {
  /// A single required role. Shorthand for `roles: [role]` with `mode: all`.
  final Role? role;

  /// List of accepted roles. When set, [mode] determines matching logic.
  final List<Role>? roles;

  /// How to match multiple roles. Defaults to [AuthorizationMode.all].
  final AuthorizationMode mode;

  const RequiresAuth({
    this.role,
    this.roles,
    this.mode = AuthorizationMode.all,
  });

  /// Convenience constructor for single-role auth.
  const RequiresAuth.single(this.role)
      : roles = null,
        mode = AuthorizationMode.all;
}

/// Marks a UseCase or datasource method for automatic retry on failure.
///
/// The DDA pipeline generates a retry wrapper that catches retryable
/// failures and re-executes with the configured backoff strategy.
class Retry {
  /// Maximum number of attempts (including the initial call).
  final int attempts;

  /// Backoff strategy between retries.
  final BackoffStrategy backoff;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Base duration for exponential backoff.
  final Duration baseDelay;

  /// Retry budget: maximum cumulative time across all attempts.
  final Duration? maxCumulativeTime;

  /// Failure types that trigger a retry.
  final List<String> retryOn;

  const Retry({
    this.attempts = 3,
    this.backoff = BackoffStrategy.exponential,
    this.maxDelay = const Duration(seconds: 30),
    this.baseDelay = const Duration(seconds: 1),
    this.maxCumulativeTime,
    this.retryOn = const ['network', 'server'],
  });

  /// Convenience constructor for a simple fixed-delay retry.
  const Retry.fixed({
    int attempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) : this(
          attempts: attempts,
          backoff: BackoffStrategy.fixed,
          baseDelay: delay,
          maxDelay: delay,
        );
}

/// Marks a UseCase method for automatic telemetry event tracking.
///
/// The DDA pipeline generates pre/post execution hooks that call
/// an analytics service, keeping domain code free of analytics calls.
class TrackEvent {
  /// The event name sent to the analytics backend.
  final String eventName;

  /// Parameter names from the UseCase to include as event properties.
  final List<String> properties;

  /// Whether to track the execution duration.
  final bool trackDuration;

  /// Whether to track the result (success/failure).
  final bool trackResult;

  /// The analytics service type to use.
  final String analyticsService;

  const TrackEvent({
    required this.eventName,
    this.properties = const [],
    this.trackDuration = true,
    this.trackResult = true,
    this.analyticsService = 'AnalyticsService',
  });
}
