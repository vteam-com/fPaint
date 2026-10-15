/// Shares the main suite's test configuration (bundled Inter font loading) with
/// the store-screenshot harness.
///
/// `flutter test` only applies a `flutter_test_config.dart` found in the test
/// file's own directory tree, so without this re-export every label in the
/// store screenshots would render as the test harness's block font.
library;

export '../../test/flutter_test_config.dart' show testExecutable;
