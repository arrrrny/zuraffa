/// Zuraffa State Management
///
/// Zero-dependency reactive state management for Flutter.
///
/// Core concepts:
/// - **Providers**: Hold state and logic
/// - **ZuraffaRef**: Access providers via read/watch
/// - **ZuraffaWidget**: Auto-rebuilding widgets
/// - **ZuraffaScope**: Root container
///
/// Example:
/// ```dart
/// // 1. Wrap your app
/// void main() {
///   runApp(ZuraffaScope(child: MyApp()));
/// }
///
/// // 2. Create a provider
/// final counterProvider = ZuraffaNotifierProvider<CounterNotifier, int>(
///   () => CounterNotifier(),
///   id: 'counter',
/// );
///
/// // 3. Use in your widget
/// class CounterPage extends ZuraffaWidget {
///   @override
///   Widget build(BuildContext context, ZuraffaRef ref) {
///     final count = ref.watch(counterProvider);
///     return Text('Count: $count');
///   }
/// }
/// ```

// Core
export 'zuraffa_ref.dart';
export 'zuraffa_notifier.dart';
export 'provider_base.dart';
export 'zuraffa_container.dart';

// Flutter integration
export 'zuraffa_scope.dart';
export 'zuraffa_widget.dart';

// Code generation
export 'zuraffa_annotation.dart';
export 'retry.dart';
