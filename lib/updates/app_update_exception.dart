/// Why an update could not be installed; the UI turns it into a localized
/// message.
enum AppUpdateFailure {
  /// GitHub answered with an error, or could not be reached.
  network,

  /// fPaint cannot write in the folder it is installed in.
  notWritable,

  /// The downloaded build does not hold the app.
  invalidBuild,

  /// A command unpacking the build failed.
  unpack,
}

/// Thrown by the updater; [detail] names the folder, URL or command involved.
class AppUpdateException implements Exception {
  /// Creates an exception of [failure] about [detail].
  const AppUpdateException(this.failure, this.detail);

  /// The folder, URL or command the failure is about.
  final String detail;

  /// What went wrong.
  final AppUpdateFailure failure;

  @override
  String toString() => '${failure.name}: $detail';
}
