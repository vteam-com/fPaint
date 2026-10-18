import 'package:fpaint/models/tool_kind.dart';

/// Transient state that lives only while one of [tools] is the selected tool.
///
/// Tool switching walks a list of scopes instead of hard-coding each
/// subsystem's cleanup, so a new tool session registers one scope rather than
/// editing the tool setter (Open/Closed).
class ToolScope {
  const ToolScope({
    required this.tools,
    required this.release,
    this.enter,
  });

  /// The tools whose selection keeps this scope's state alive.
  final Set<ToolKind> tools;

  /// Frees the scope's state; runs whenever a tool outside [tools] is selected.
  final void Function() release;

  /// Prepares the scope; runs whenever a tool in [tools] is selected.
  final void Function()? enter;

  /// Releases or enters this scope for a newly selected [tool].
  void apply(ToolKind tool) {
    if (tools.contains(tool)) {
      enter?.call();
    } else {
      release();
    }
  }
}
