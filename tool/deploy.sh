#!/bin/bash

# deploy.sh - Build and deploy Flutter web app to Firebase
# This script performs a clean build of the Flutter web app and deploys it to Firebase Hosting

set -e  # Exit on any error

echo "🚀 Starting Flutter Web Deployment to Firebase"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    print_error "Firebase CLI is not installed!"
    print_status "Please install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH!"
    exit 1
fi

# Verify we're in the correct directory (should have pubspec.yaml)
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found! Please run this script from the Flutter project root."
    exit 1
fi

print_status "Checking Flutter doctor..."
flutter doctor --version

print_status "Getting Flutter dependencies..."
flutter pub get

print_status "Running Flutter analyze..."
flutter analyze
if [ $? -ne 0 ]; then
    print_warning "Flutter analyze found issues. Continuing anyway..."
fi

print_status "Cleaning previous build..."
flutter clean

print_status "Getting dependencies again after clean..."
flutter pub get

print_status "Building Flutter web app for production..."
flutter build web --release

# Check if build was successful
if [ ! -d "build/web" ]; then
    print_error "Build failed! build/web directory not found."
    exit 1
fi

print_success "Flutter web build completed successfully!"

# Update Firebase configuration to point to build/web
print_status "Updating Firebase hosting configuration..."

# Create a temporary firebase.json for deployment
cat > firebase.json.tmp << EOF
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "/downloads/**",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=3600"
          }
        ]
      },
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=31536000"
          }
        ]
      }
    ],
    "frameworksBackend": {
      "region": "us-central1"
    }
  }
}
EOF

# Backup original firebase.json
if [ -f "firebase.json" ]; then
    cp firebase.json firebase.json.backup
    print_status "Backed up original firebase.json to firebase.json.backup"
fi

# Use the temporary configuration
mv firebase.json.tmp firebase.json

print_status "Deploying to Firebase Hosting..."
firebase deploy --only hosting

# Check deployment status
if [ $? -eq 0 ]; then
    print_success "🎉 Deployment completed successfully!"
    print_status "Your app should be available at your Firebase Hosting URL"
    
    # Try to get the hosting URL
    HOSTING_URL=$(firebase hosting:channel:list 2>/dev/null | grep -o 'https://[^[:space:]]*' | head -1)
    if [ ! -z "$HOSTING_URL" ]; then
        print_success "🌐 App URL: $HOSTING_URL"
    fi
else
    print_error "❌ Deployment failed!"
    
    # Restore original firebase.json if deployment failed
    if [ -f "firebase.json.backup" ]; then
        mv firebase.json.backup firebase.json
        print_status "Restored original firebase.json"
    fi
    exit 1
fi

# Restore original firebase.json after successful deployment
if [ -f "firebase.json.backup" ]; then
    mv firebase.json.backup firebase.json
    print_status "Restored original firebase.json"
fi

print_success "✅ Deployment process completed!"
echo ""
echo "📝 Summary:"
echo "  - Flutter web app built successfully"
echo "  - Deployed to Firebase Hosting"
echo "  - Original firebase.json configuration restored"
echo ""
echo "🔧 Next steps:"
echo "  - Test your deployed app"
echo "  - Check Firebase Console for deployment details"
echo "  - Monitor performance and usage"
