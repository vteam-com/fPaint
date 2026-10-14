/// The application display name.
const String appName = 'fPaint';

/// Flutter package that bundles the app's images, icons and fonts.
const String appAssetsPackage = 'fpaint_assets';

/// Path of the app logo image inside [appAssetsPackage].
const String appLogoAssetPath = 'assets/app_icon.png';

/// Default font family used throughout the app.
///
/// Inter is an open-source sans-serif designed for screens, visually close to
/// Apple San Francisco. Licensed under the SIL Open Font License 1.1.
/// Bundle fonts by running `bash tool/download_fonts.sh` once.
const String appFontFamily = 'packages/$appAssetsPackage/Inter';

/// Barrier label used by [showGeneralDialog] overlays to dismiss on tap outside.
const String barrierLabelDismiss = 'Dismiss';

/// Non-user-facing key prefix for identifying SVG icons in widget tests.
const String appIconKeyPrefix = 'app_icon_';
