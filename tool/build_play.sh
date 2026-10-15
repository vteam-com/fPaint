#!/bin/sh
# Builds the Google Play upload:
#   build/app/outputs/bundle/release/app-release.aab
# Upload it in Play Console (Test and release > a track > Create new release),
# or with fastlane supply (see store/README.md).
#
# Usage: tool/build_play.sh [build-number]
# The version comes from pubspec.yaml. Every upload needs a higher build number
# (versionCode) than any bundle Play has seen, on any track.
#
# Needs android/key.properties pointing at the upload keystore; without it the
# bundle would be signed with the debug key, which Play rejects.

set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
KEY_PROPERTIES="$ROOT_DIR/android/key.properties"
BUNDLE="$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab"
SYMBOLS_DIR="$ROOT_DIR/build/app/outputs/symbols"

cd "$ROOT_DIR"

if [ ! -f "$KEY_PROPERTIES" ]; then
	echo "Missing android/key.properties: create the upload key first (store/README.md)."
	exit 1
fi

BUILD_NUMBER_ARGS=""
if [ -n "$1" ]; then
	BUILD_NUMBER_ARGS="--build-number=$1"
fi

echo "--- Android: release App Bundle"
flutter build appbundle --release $BUILD_NUMBER_ARGS --split-debug-info="$SYMBOLS_DIR"

echo "--- Signature"
jarsigner -verify -certs "$BUNDLE" | tail -1

echo "--- Ready to upload"
ls -1 "$BUNDLE"
