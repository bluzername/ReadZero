#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# validate_and_upload.sh
# Archives, exports, and uploads to App Store Connect.
#
# If ExportOptions.plist has destination=upload (default), the
# export step uploads directly to ASC — no separate altool step.
#
# If you want local validation first, change ExportOptions.plist
# destination to "export", then this script will validate via
# altool before uploading.
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

# ─── Step 1: Archive ─────────────────────────────────────────
# xcodebuild archive runs Flutter's build phases automatically,
# so a separate `flutter build ios` is not needed.
echo "=== Step 1: Xcode Archive ==="
cd "$PROJECT_ROOT/ios"
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath build/Runner.xcarchive \
  archive 2>&1 | tail -5
echo "Archive: OK"
echo ""

# ─── Step 2: Export (+ upload if destination=upload) ─────────
echo "=== Step 2: Export IPA ==="
rm -rf build/ipa
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates 2>&1 | tail -10
echo "Export: OK"
echo ""

# Check if there's a local IPA (only exists if destination=export)
IPA_FILE=$(find build/ipa -name "*.ipa" -print -quit 2>/dev/null || true)

if [ -n "$IPA_FILE" ]; then
  # Local IPA exists — validate then upload via altool
  echo "IPA: $IPA_FILE"
  echo ""

  echo "=== Step 3: VALIDATE against App Store Connect ==="
  echo "(Catches the same issues that produce rejection emails)"
  echo ""
  xcrun altool --validate-app \
    -f "$IPA_FILE" -t ios \
    -u "$APPLE_ID" -p "$APP_PASSWORD"
  echo ""
  echo "Validation: PASSED"
  echo ""

  echo "=== Step 4: UPLOAD to App Store Connect ==="
  xcrun altool --upload-app \
    -f "$IPA_FILE" -t ios \
    -u "$APPLE_ID" -p "$APP_PASSWORD"
else
  # No local IPA — export already uploaded directly to ASC
  echo "(ExportOptions destination=upload — build was uploaded during export)"
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   SUCCESS — Build uploaded to App Store Connect  ║"
echo "║   Check ASC in 15-30 min for processing.        ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
