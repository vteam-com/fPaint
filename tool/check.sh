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

# fcheck --fix can touch dependency declarations; refresh package resolution
# before formatter/analyzer reads analysis_options includes.
echo --- Pub Get post-fcheck
flutter pub get > /dev/null || { echo "Pub get failed"; exit 1; }

echo --- Format sources
dart format lib test integration_test tool | sed 's/^/    /'
dart fix --apply | sed 's/^/    /'

