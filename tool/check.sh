#!/bin/sh
echo --- Pub Get
flutter pub get > /dev/null || { echo "Pub get failed"; exit 1; }
echo --- Pub Outdated
flutter pub outdated

echo --- Analyze
flutter analyze lib test --no-pub | sed 's/^/    /'

echo --- Test
echo "    Running tests..."
flutter test --reporter=compact --no-pub

echo --- fCheck
# Install the pinned version into the isolated cache, then run it.
# Note: `dart pub cache exec` doesn't exist on all Dart SDK versions; `pub global run` does.
dart pub global activate fcheck 1.1.3 > /dev/null
dart pub global run fcheck --svg --fix --list full

echo --- Format sources
dart format . | sed 's/^/    /'
dart fix --apply | sed 's/^/    /'

