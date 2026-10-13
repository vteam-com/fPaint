import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';

/// Publishes the active [InteractionLayoutProfile] so shared controls (icons,
/// icon buttons) size themselves for the current input: compact,
/// desktop-density controls under a mouse, larger targets under touch or pen.
///
/// Installed once above the navigator, so every page, dialog, and popup
/// follows the same density and re-lays out when the input modality changes.
class InteractionDensity extends InheritedWidget {
  /// Creates a scope publishing [profile] to [child].
  const InteractionDensity({
    super.key,
    required this.profile,
    required super.child,
  });

  /// Profile used where no [InteractionDensity] is installed (tests, widget
  /// previews): the roomier touch sizing the controls were designed with.
  static const InteractionLayoutProfile fallback = AppInteractionProfiles.touch;

  /// The sizing profile for the current input modality.
  final InteractionLayoutProfile profile;

  /// The nearest profile, registering [context] to rebuild when it changes.
  static InteractionLayoutProfile of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InteractionDensity>()?.profile ?? fallback;
  }

  @override
  bool updateShouldNotify(InteractionDensity oldWidget) => !identical(profile, oldWidget.profile);
}
