/// Abstraction for components that can flush pending state to persistent
/// storage.  Used so that widget-level code does not depend directly on the
/// concrete [DraftRecoveryController] in the `recovery` package.
abstract class DraftFlusher {
  /// Immediately persists any pending draft data.
  Future<void> flushNow();
}
