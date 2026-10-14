import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/app_icon_enum.dart';
import 'package:fpaint/widgets/material_free.dart';

/// A width / height entry pair joined by an aspect-ratio lock toggle.
///
/// Shared by the canvas-size and image-size sheets so both keep the same
/// behaviour: while the lock is on, editing one field rewrites the other from
/// the ratio captured when the lock engaged, and an unparsable (incomplete)
/// value leaves the other field untouched.
class SizeFieldsRow extends StatefulWidget {
  const SizeFieldsRow({
    super.key,
    required this.widthController,
    required this.heightController,
    required this.lockAspectRatio,
    required this.onLockAspectRatioChanged,
    this.widthFieldKey,
    this.heightFieldKey,
    this.lockButtonKey,
  });

  /// Backing controller for the height field.
  final TextEditingController heightController;

  /// Optional test key for the height field.
  final Key? heightFieldKey;

  /// Whether editing one field should rewrite the other to keep the ratio.
  final bool lockAspectRatio;

  /// Optional test key for the lock toggle.
  final Key? lockButtonKey;

  /// Called when the user toggles the lock; the owner holds the lock state.
  final ValueChanged<bool> onLockAspectRatioChanged;

  /// Backing controller for the width field.
  final TextEditingController widthController;

  /// Optional test key for the width field.
  final Key? widthFieldKey;
  @override
  State<SizeFieldsRow> createState() => _SizeFieldsRowState();
}

class _SizeFieldsRowState extends State<SizeFieldsRow> {
  /// width / height captured when the lock engaged (or at first build).
  double _aspectRatio = 1;

  /// Guards the two onChanged handlers from re-triggering each other while
  /// one of them programmatically updates the other field.
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _captureAspectRatio();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: AppLayout.inputFieldWidth,
          child: AppTextField(
            key: widget.widthFieldKey,
            hintText: context.l10n.width,
            keyboardType: TextInputType.number,
            controller: widget.widthController,
            selectAllOnFocus: true,
            onChanged: (String value) => _syncOther(
              widget.heightController,
              value,
              (double width) => width / _aspectRatio,
            ),
          ),
        ),
        AppButtonIcon(
          key: widget.lockButtonKey,
          icon: widget.lockAspectRatio ? AppIcon.link : AppIcon.linkOff,
          onPressed: _toggleLock,
        ),
        SizedBox(
          width: AppLayout.inputFieldWidth,
          child: AppTextField(
            key: widget.heightFieldKey,
            hintText: context.l10n.height,
            keyboardType: TextInputType.number,
            controller: widget.heightController,
            selectAllOnFocus: true,
            onChanged: (String value) => _syncOther(
              widget.widthController,
              value,
              (double height) => height * _aspectRatio,
            ),
          ),
        ),
      ],
    );
  }

  void _captureAspectRatio() {
    final double? width = double.tryParse(widget.widthController.text);
    final double? height = double.tryParse(widget.heightController.text);
    if (width != null && height != null && width > 0 && height > 0) {
      _aspectRatio = width / height;
    }
  }

  /// Rewrites [other] from the freshly typed [value] through [derive] while
  /// the lock is on, skipping unparsable input and re-entrant updates.
  void _syncOther(TextEditingController other, String value, double Function(double) derive) {
    if (!widget.lockAspectRatio || _isSyncing || _aspectRatio == 0) {
      return;
    }
    final double? parsed = double.tryParse(value);
    if (parsed == null) {
      return; // Keep the other field while input is incomplete.
    }
    _isSyncing = true;
    other.text = derive(parsed).round().toString();
    _isSyncing = false;
  }

  void _toggleLock() {
    final bool lock = !widget.lockAspectRatio;
    if (lock) {
      // Re-derive the ratio from whatever the fields hold right now.
      _captureAspectRatio();
    }
    widget.onLockAspectRatioChanged(lock);
  }
}

/// Parses the two size fields, reporting a snackbar and returning null when
/// they are not both positive numbers.
Size? parsePositiveSize(
  BuildContext context, {
  required String widthText,
  required String heightText,
  required String mustBePositiveMessage,
}) {
  final double? width = double.tryParse(widthText);
  final double? height = double.tryParse(heightText);
  if (width == null || height == null) {
    context.showSnackBarMessage(context.l10n.invalidImageSizeDimensionsMustBeNumbers);
    return null;
  }
  if (width <= 0 || height <= 0) {
    context.showSnackBarMessage(mustBePositiveMessage);
    return null;
  }
  return Size(width, height);
}

/// Extra sheet content built under the sheet's [StateSetter], so it can keep
/// its own state (e.g. the canvas anchor) across rebuilds.
typedef SizeSheetExtraBuilder = Widget Function(BuildContext context, StateSetter setSheetState);

/// Applies a validated [size] from a size sheet, with the sheet's final
/// aspect-ratio [lockAspectRatio] state.
typedef SizeSheetApply = void Function(Size size, bool lockAspectRatio);

/// Shows the shared width / height bottom sheet used by the canvas-size and
/// image-size commands.
///
/// The sheet owns (and disposes) its field controllers, seeded from
/// [initialSize]. On Apply, valid positive dimensions close the sheet and are
/// handed to [onApply]; invalid input reports [mustBePositiveMessage] (or the
/// not-a-number message) and keeps the sheet open.
Future<void> showSizeSheet({
  required BuildContext context,
  required String title,
  required Size initialSize,
  required bool initialLockAspectRatio,
  required String mustBePositiveMessage,
  required SizeSheetApply onApply,
  required Key widthFieldKey,
  required Key heightFieldKey,
  required Key lockButtonKey,
  required Key applyButtonKey,
  String? hint,
  SizeSheetExtraBuilder? extraBuilder,
}) {
  final TextEditingController widthController = TextEditingController(
    text: initialSize.width.toInt().toString(),
  );
  final TextEditingController heightController = TextEditingController(
    text: initialSize.height.toInt().toString(),
  );
  bool lockAspectRatio = initialLockAspectRatio;

  return showAppBottomSheet<void>(
    context: context,
    builder: (BuildContext context) {
      final AppLocalizations l10n = context.l10n;
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.medium,
                children: <Widget>[
                  AppText(title, variant: AppTextVariant.title),
                  if (hint != null) AppText(hint, variant: AppTextVariant.subtitle),
                  SizeFieldsRow(
                    widthController: widthController,
                    heightController: heightController,
                    lockAspectRatio: lockAspectRatio,
                    onLockAspectRatioChanged: (bool lock) {
                      setSheetState(() => lockAspectRatio = lock);
                    },
                    widthFieldKey: widthFieldKey,
                    heightFieldKey: heightFieldKey,
                    lockButtonKey: lockButtonKey,
                  ),
                  if (extraBuilder != null) extraBuilder(context, setSheetState),
                  AppButtonRow(
                    actions: <Widget>[
                      AppRowPrimaryButton(
                        key: applyButtonKey,
                        onPressed: () {
                          final Size? newSize = parsePositiveSize(
                            context,
                            widthText: widthController.text,
                            heightText: heightController.text,
                            mustBePositiveMessage: mustBePositiveMessage,
                          );
                          if (newSize == null) {
                            return;
                          }
                          // Close first: applying may be async and take a
                          // moment on a large canvas; the sheet has nothing
                          // further to show.
                          Navigator.pop(context);
                          onApply(newSize, lockAspectRatio);
                        },
                        text: l10n.apply,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(() {
    widthController.dispose();
    heightController.dispose();
  });
}
