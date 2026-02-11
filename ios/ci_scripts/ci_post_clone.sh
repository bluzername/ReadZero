#!/bin/sh
set -e

echo "=== ci_post_clone.sh starting ==="
echo "CI_PRIMARY_REPOSITORY_PATH: $CI_PRIMARY_REPOSITORY_PATH"
echo "CI_WORKSPACE: $CI_WORKSPACE"
echo "PWD: $(pwd)"

# Navigate to project root
cd "$CI_PRIMARY_REPOSITORY_PATH"
echo "=== Changed to project root: $(pwd) ==="

# Install Flutter (pinned to the version used locally)
echo "=== Installing Flutter 3.27.3 ==="
git clone https://github.com/flutter/flutter.git --depth 1 -b 3.27.3 "$HOME/flutter"
export PATH="$HOME/flutter/bin:$HOME/flutter/bin/cache/dart-sdk/bin:$PATH"

echo "=== Flutter version ==="
flutter --version

# Disable analytics in CI
flutter config --no-analytics 2>/dev/null || true
dart --disable-analytics 2>/dev/null || true

# Precache iOS artifacts
echo "=== Precaching iOS build tools ==="
flutter precache --ios

# Get Flutter dependencies and generate files (including Generated.xcconfig)
echo "=== Running flutter pub get ==="
flutter pub get

# Verify Generated.xcconfig was created
if [ -f "ios/Flutter/Generated.xcconfig" ]; then
  echo "=== Generated.xcconfig created successfully ==="
  cat ios/Flutter/Generated.xcconfig
else
  echo "ERROR: Generated.xcconfig was NOT created"
  exit 1
fi

# Install CocoaPods dependencies
echo "=== Running pod install ==="
cd ios
pod install

echo "=== ci_post_clone.sh completed successfully ==="
