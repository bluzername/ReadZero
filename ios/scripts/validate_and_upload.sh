#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# validate_and_upload.sh
# Archives, exports, validates against ASC, then uploads.
# Catches the same issues that produce rejection emails — instantly.
#
# Usage:
#   ASC_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" ./ios/scripts/validate_and_upload.sh
# ─────────────────────────────────────────────────────────────

APPLE_ID="evyafb@hotmail.com"
APP_PASSWORD="${ASC_APP_PASSWORD:?Set ASC_APP_PASSWORD env var (app-specific password)}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   ReadZero — Build, Validate & Upload to ASC    ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Project: $PROJECT_ROOT"
echo ""

# ─── Step 1: Flutter build ───────────────────────────────────
echo "=== Step 1: Flutter build (iOS release) ==="
cd "$PROJECT_ROOT"
flutter build ios --release --no-codesign 2>&1 | tail -5
echo "Flutter build: OK"
echo ""

# ─── Step 2: Archive ─────────────────────────────────────────
echo "=== Step 2: Xcode Archive ==="
cd "$PROJECT_ROOT/ios"
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath build/Runner.xcarchive \
  archive 2>&1 | tail -5
echo "Archive: OK"
echo ""

# ─── Step 3: Export IPA ──────────────────────────────────────
echo "=== Step 3: Export IPA ==="
rm -rf build/ipa
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist 2>&1 | tail -5
echo "Export: OK"

# Find the IPA
IPA_FILE=$(find build/ipa -name "*.ipa" -print -quit)
if [ -z "$IPA_FILE" ]; then
  echo "ERROR: No IPA file found in build/ipa/"
  exit 1
fi
echo "IPA: $IPA_FILE"
echo ""

# ─── Step 4: Validate ────────────────────────────────────────
echo "=== Step 4: VALIDATE against App Store Connect ==="
echo "(This catches the same issues that produce rejection emails)"
echo ""
xcrun altool --validate-app \
  -f "$IPA_FILE" -t ios \
  -u "$APPLE_ID" -p "$APP_PASSWORD"

echo ""
echo "Validation: PASSED"
echo ""

# ─── Step 5: Upload ──────────────────────────────────────────
echo "=== Step 5: UPLOAD to App Store Connect ==="
xcrun altool --upload-app \
  -f "$IPA_FILE" -t ios \
  -u "$APPLE_ID" -p "$APP_PASSWORD"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   SUCCESS — Build validated and uploaded!        ║"
echo "║   Check ASC in 15-30 min for processing.        ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
