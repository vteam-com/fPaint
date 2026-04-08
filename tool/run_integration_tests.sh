#!/bin/bash

# fPaint Integration Test Runner
# This script runs both unit and integration tests with proper coverage reporting
# Designed to work in CI/CD environments

set -e  # Exit on any error

echo "🚀 fPaint Test Runner"
echo "===================="

# Check flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

echo "✅ Flutter found"

# Create coverage directory if it doesn't exist
mkdir -p coverage

# Run unit tests with coverage
echo "📊 Running unit tests with coverage..."
flutter test --coverage

# Move unit test coverage to specific file
if [ -f "coverage/lcov.info" ]; then
    mv coverage/lcov.info coverage/lcov_units.info
    echo "✅ Unit test coverage saved to coverage/lcov_units.info"
else
    echo "⚠️  No unit test coverage file generated"
fi

# Run integration tests with coverage
echo "🔧 Running integration tests with coverage..."

# Check available devices
echo "📱 Checking available devices..."
flutter devices

# Try to run integration tests on available device
# Priority: macOS (for local dev) -> Linux (for CI/CD) -> Chrome (fallback)
if flutter devices | grep -q "macOS"; then
    echo "🍎 Running integration tests on macOS..."
    flutter test integration_test/integration_test.dart --coverage -d macos
    flutter test integration_test/canvas_resize_test.dart --coverage -d macos
elif flutter devices | grep -q "linux"; then
    echo "🐧 Running integration tests on Linux..."
    flutter test integration_test/integration_test.dart --coverage -d linux
    flutter test integration_test/canvas_resize_test.dart --coverage -d linux
elif flutter devices | grep -q "chrome"; then
    echo "🌐 Running integration tests on Chrome..."
    flutter test integration_test/integration_test.dart --coverage -d chrome
    flutter test integration_test/canvas_resize_test.dart --coverage -d chrome
else
    echo "❌ No suitable device found for integration tests"
    echo "📱 Available devices:"
    flutter devices
    exit 1
fi

# Move integration test coverage to specific file
if [ -f "coverage/lcov.info" ]; then
    mv coverage/lcov.info coverage/lcov_integration.info
    echo "✅ Integration test coverage saved to coverage/lcov_integration.info"
else
    echo "⚠️  No integration test coverage file generated"
fi

# Merge coverage files
echo "🔀 Merging coverage files..."
if [ -f "coverage/lcov_units.info" ] && [ -f "coverage/lcov_integration.info" ]; then
    lcov --add-tracefile coverage/lcov_units.info \
         --add-tracefile coverage/lcov_integration.info \
         --output-file coverage/merged_lcov.info

    # Copy merged coverage to standard location for VSCode
    cp coverage/merged_lcov.info coverage/lcov.info

    echo "✅ Coverage files merged successfully"
elif [ -f "coverage/lcov_units.info" ]; then
    cp coverage/lcov_units.info coverage/lcov.info
    echo "⚠️  Only unit test coverage available"
elif [ -f "coverage/lcov_integration.info" ]; then
    cp coverage/lcov_integration.info coverage/lcov.info
    echo "⚠️  Only integration test coverage available"
else
    echo "❌ No coverage files generated"
    exit 1
fi

# Generate HTML coverage report
echo "📄 Generating HTML coverage report..."
genhtml coverage/merged_lcov.info \
       --output-directory coverage_report \
       --title "fPaint Combined Coverage Report" \
       --show-details --legend \
       --quiet

# Display coverage summary
echo "📊 Coverage Summary:"
lcov --summary coverage/merged_lcov.info

echo ""
echo "✅ All tests completed successfully!"
echo "📁 Coverage report available at: coverage_report/index.html"
echo "📄 Coverage files available in: coverage/"
