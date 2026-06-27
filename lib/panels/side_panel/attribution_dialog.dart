import 'package:flutter/foundation.dart' show LicenseEntry, LicenseParagraph, LicenseRegistry;
import 'package:flutter/widgets.dart';
import 'package:fpaint/constants/constants.dart';
import 'package:fpaint/l10n/app_localizations_x.dart';
import 'package:fpaint/models/dependency_versions.dart';
import 'package:fpaint/widgets/material_free.dart';

const double _attributionIconSize = AppLayout.appIconSize;
const String _packageDelimiter = ', ';
const String _sdkPlaceholderVersion = '0.0.0';
const String _packageVersionPrefix = 'v';
const String _normalizedYearToken = '<year>';
final RegExp _yearsPattern = RegExp(r'\b(?:19|20)\d{2}(?:-(?:19|20)\d{2})?\b');
final RegExp _whitespacePattern = RegExp(r'\s+');

class _AttributionTextGroup {
  _AttributionTextGroup();

  final Set<String> normalizedTexts = <String>{};
  final List<String> displayTexts = <String>[];
}

class _AttributionSection {
  const _AttributionSection({
    required this.packages,
    required this.licenses,
  });

  final List<String> packages;
  final List<String> licenses;
}

String _normalizeAttributionText(final String text) {
  final String withoutYearDifferences = text.replaceAll(_yearsPattern, _normalizedYearToken);
  return withoutYearDifferences.replaceAll(_whitespacePattern, ' ').trim();
}

String _formatPackageName(final String packageName) {
  final String? packageVersion = dependencyVersions[packageName];
  if (packageVersion == null || packageVersion == _sdkPlaceholderVersion) {
    return packageName;
  }

  return '$packageName ($_packageVersionPrefix$packageVersion)';
}

/// Loads dependency attribution entries from [LicenseRegistry].
///
/// Combined package groups are split into per-package sections and texts are
/// deduplicated per package with normalized year-insensitive matching.
Future<List<_AttributionSection>> _loadAttributions() async {
  final Map<String, List<String>> groupedPackages = <String, List<String>>{};
  final Map<String, _AttributionTextGroup> groupedTexts = <String, _AttributionTextGroup>{};

  await for (final LicenseEntry licenseEntry in LicenseRegistry.licenses) {
    final List<String> packages = licenseEntry.packages.toList(growable: false)..sort();
    final List<String> dependencyPackages =
        packages
            .where((final String packageName) {
              final String? packageVersion = dependencyVersions[packageName];
              return packageVersion != null && packageVersion != _sdkPlaceholderVersion;
            })
            .toList(growable: false)
          ..sort();

    if (dependencyPackages.isEmpty) {
      continue;
    }

    final StringBuffer textBuffer = StringBuffer();
    for (final LicenseParagraph paragraph in licenseEntry.paragraphs) {
      if (textBuffer.isNotEmpty) {
        textBuffer.writeln();
      }
      textBuffer.write(paragraph.text);
    }

    final String paragraphText = textBuffer.toString().trim();
    if (paragraphText.isEmpty) {
      continue;
    }

    final String normalizedParagraphText = _normalizeAttributionText(paragraphText);

    for (final String packageName in dependencyPackages) {
      groupedPackages[packageName] = <String>[packageName];
      final _AttributionTextGroup textGroup = groupedTexts.putIfAbsent(
        packageName,
        _AttributionTextGroup.new,
      );

      if (textGroup.normalizedTexts.add(normalizedParagraphText)) {
        textGroup.displayTexts.add(paragraphText);
      }
    }
  }

  final List<_AttributionSection> attributions = <_AttributionSection>[];
  final List<String> sortedPackageKeys = groupedPackages.keys.toList(growable: false)..sort();
  for (final String packageKey in sortedPackageKeys) {
    final List<String>? packageList = groupedPackages[packageKey];
    final _AttributionTextGroup? textGroup = groupedTexts[packageKey];
    if (packageList == null || textGroup == null || textGroup.displayTexts.isEmpty) {
      continue;
    }

    attributions.add(
      _AttributionSection(
        packages: packageList,
        licenses: textGroup.displayTexts,
      ),
    );
  }

  return attributions;
}

/// Shows the Attribution dialog.
Future<void> showAttributionDialog(final BuildContext context) async {
  final List<_AttributionSection> attributions = await _loadAttributions();
  final Set<String> expandedPackageKeys = <String>{};

  if (!context.mounted) {
    return;
  }

  final String dialogTitle = '${context.l10n.flutterAttribution} (${attributions.length})';

  await showAppDialog<void>(
    context: context,
    builder: (final BuildContext dialogContext) {
      return StatefulBuilder(
        builder:
            (
              final BuildContext _,
              final void Function(void Function()) setState,
            ) {
              return AppDialog(
                title: dialogTitle,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Image.asset(
                      'assets/app_icon.png',
                      width: _attributionIconSize,
                      height: _attributionIconSize,
                    ),
                    const SizedBox(height: AppSpacing.large),
                    for (final _AttributionSection attribution in attributions) ...<Widget>[
                      () {
                        final String packageHeading = attribution.packages
                            .map(_formatPackageName)
                            .join(_packageDelimiter);
                        final bool isExpanded = expandedPackageKeys.contains(packageHeading);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                expandedPackageKeys.remove(packageHeading);
                              } else {
                                expandedPackageKeys.add(packageHeading);
                              }
                            });
                          },
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Text(
                              packageHeading,
                              style: AppTextStyle.bodyBold,
                            ),
                          ),
                        );
                      }(),
                      if (expandedPackageKeys.contains(
                        attribution.packages.map(_formatPackageName).join(_packageDelimiter),
                      )) ...<Widget>[
                        const SizedBox(height: AppSpacing.small),
                        for (
                          int licenseIndex = 0;
                          licenseIndex < attribution.licenses.length;
                          licenseIndex++
                        ) ...<Widget>[
                          Text(
                            attribution.licenses[licenseIndex],
                            style: AppTextStyle.label.copyWith(
                              color: AppColors.textSecondary.withValues(alpha: AppVisual.medium),
                            ),
                          ),
                          if (licenseIndex < attribution.licenses.length - 1) const SizedBox(height: AppSpacing.large),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.large),
                    ],
                  ],
                ),
                actions: <Widget>[
                  AppRowPrimaryButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    text: context.l10n.close,
                  ),
                ],
              );
            },
      );
    },
  );
}
