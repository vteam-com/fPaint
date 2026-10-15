#!/bin/sh
# Generates the App Store / Google Play screenshots in fastlane's layout:
#   store/app_store/screenshots/<locale>/{iphone69,ipad13}_NN_<name>.png   (deliver)
#   store/google_play/<locale>/images/phoneScreenshots/NN_<name>.png       (supply)
#   store/google_play/<locale>/images/tenInchScreenshots/NN_<name>.png     (supply)
#
# Opens the showcase artwork (test/output/final.ora, produced by
# test/painting_scenario_test.dart) in the real app and captures every
# device size x locale. Extra arguments are passed to `flutter test`, e.g.
#   tool/store_screenshots.sh --dart-define=STORE_DEVICE=ios_ipad_13
#   tool/store_screenshots.sh --dart-define=STORE_LOCALE=fr-FR
# A full run (no arguments) first removes previously generated PNGs; a subset
# run only overwrites its own. Listing text is left alone.
set -e
cd "$(dirname "$0")/.."

if [ ! -f test/output/final.ora ]; then
  echo "test/output/final.ora is missing: run test/painting_scenario_test.dart first." >&2
  exit 1
fi

echo --- Store screenshots
if [ "$#" -eq 0 ]; then
  rm -f store/app_store/screenshots/*/iphone69_*.png store/app_store/screenshots/*/ipad13_*.png
  rm -f store/google_play/*/images/phoneScreenshots/*.png store/google_play/*/images/tenInchScreenshots/*.png
fi
flutter test tool/store_screenshots/store_screenshots_test.dart "$@"
find store/app_store/screenshots store/google_play -name '*.png' | sort
