#!/bin/bash

# fPaint Integration Test Runner
# This script helps run integration tests on mobile platforms

echo "🚀 fPaint Integration Test Runner"
echo "=================================="

# Check flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

echo "✅ Flutter found"
flutter test integration_test/app_integration_test.dart -d macos
