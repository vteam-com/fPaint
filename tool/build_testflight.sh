#!/bin/sh
# Builds the App Store Connect uploads for TestFlight:
#   build/ios/ipa/fPaint.ipa       (iPhone / iPad)
#   build/macos/export/fPaint.pkg  (Mac App Store)
# Upload them with Apple's Transporter app, or with
#   xcrun altool --upload-app -t ios|macos -f <file> --apiKey ... --apiIssuer ...
#
# Usage: tool/build_testflight.sh [build-number]
# The version comes from pubspec.yaml. Every upload of the same version needs
# a higher build number than the last one App Store Connect has seen.

set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXPORT_OPTIONS="$ROOT_DIR/tool/testflight/ExportOptions.plist"
MACOS_ARCHIVE="$ROOT_DIR/build/macos/Runner.xcarchive"
MACOS_EXPORT_DIR="$ROOT_DIR/build/macos/export"

cd "$ROOT_DIR"
rm -rf build/ios/ipa

BUILD_NUMBER_ARGS=""
if [ -n "$1" ]; then
	BUILD_NUMBER_ARGS="--build-number=$1"
fi

echo "--- iOS: archive + App Store IPA"
flutter build ipa --release $BUILD_NUMBER_ARGS --export-options-plist="$EXPORT_OPTIONS"
# flutter exits 0 even when the IPA export fails, so check for the file.
if ! ls build/ios/ipa/*.ipa >/dev/null 2>&1; then
	echo "iOS IPA export failed: see the exportArchive errors above."
	exit 1
fi

echo "--- macOS: Flutter release build (generates the build name/number config)"
flutter build macos --release $BUILD_NUMBER_ARGS

echo "--- macOS: archive"
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Release \
	-archivePath "$MACOS_ARCHIVE" -allowProvisioningUpdates archive

echo "--- macOS: App Store package"
rm -rf "$MACOS_EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$MACOS_ARCHIVE" -exportOptionsPlist "$EXPORT_OPTIONS" \
	-exportPath "$MACOS_EXPORT_DIR" -allowProvisioningUpdates

echo "--- Ready to upload"
ls -1 build/ios/ipa/*.ipa "$MACOS_EXPORT_DIR"/*.pkg
