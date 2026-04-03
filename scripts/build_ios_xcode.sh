#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio
#
# Patches the Godot-generated Xcode project to fix the SwiftUICore linker error
# (Xcode 16+/26) and builds the .ipa.
#
# Usage:
#   ./scripts/build_ios_xcode.sh <path-to-generated-xcode-project-dir> [output.ipa]
#
# Example:
#   ./scripts/build_ios_xcode.sh /tmp/ios_export/MyGame /tmp/ios_export/MyGame.ipa
#
# The <path> should be the directory containing the .xcodeproj that Godot exported
# (with export_project_only=true in the iOS preset).

set -euo pipefail

XCODE_PROJECT_DIR="${1:?Usage: $0 <xcode-project-dir> [output.ipa]}"
OUTPUT_IPA="${2:-${XCODE_PROJECT_DIR}.ipa}"

# Find the .xcodeproj — either as a sibling (Godot export_project_only layout)
# or inside the directory
if [ -d "${XCODE_PROJECT_DIR}.xcodeproj" ]; then
    XCODEPROJ="${XCODE_PROJECT_DIR}.xcodeproj"
else
    XCODEPROJ=$(find "$XCODE_PROJECT_DIR" -maxdepth 1 -name "*.xcodeproj" -type d | head -1)
fi
if [ -z "$XCODEPROJ" ]; then
    echo "ERROR: No .xcodeproj found at ${XCODE_PROJECT_DIR}.xcodeproj or inside $XCODE_PROJECT_DIR"
    exit 1
fi

PBXPROJ="$XCODEPROJ/project.pbxproj"
if [ ! -f "$PBXPROJ" ]; then
    echo "ERROR: project.pbxproj not found at $PBXPROJ"
    exit 1
fi

PROJECT_NAME=$(basename "$XCODEPROJ" .xcodeproj)
echo "=== Patching Xcode project: $PROJECT_NAME ==="

# Patch: add LD_CLASSIC entries for Xcode 26.x
# Godot 4.6's libgodot.a uses SwiftUI, and Xcode 26 blocks linking SwiftUICore
# (private framework). The classic linker (-ld_classic) bypasses this check.
# Godot already has LD_CLASSIC_15xx for Xcode 15; we add Xcode 26 entries.
if grep -q "LD_CLASSIC_2620" "$PBXPROJ"; then
    echo "  Already patched (LD_CLASSIC_2620 present)"
else
    sed -i '' 's/"LD_CLASSIC_1510" = "-ld_classic";/"LD_CLASSIC_1510" = "-ld_classic";\
				"LD_CLASSIC_2600" = "-ld_classic";\
				"LD_CLASSIC_2610" = "-ld_classic";\
				"LD_CLASSIC_2620" = "-ld_classic";/g' "$PBXPROJ"
    echo "  Patched: added LD_CLASSIC entries for Xcode 26.x"
fi

# Build
echo "=== Building iOS archive ==="
ARCHIVE_PATH="/tmp/godot_ios_archive.xcarchive"
rm -rf "$ARCHIVE_PATH"

xcodebuild archive \
    -project "$XCODEPROJ" \
    -scheme "$PROJECT_NAME" \
    -sdk iphoneos \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet || {
        echo "ERROR: xcodebuild archive failed. Check signing settings or open the project in Xcode."
        echo "  Project: $XCODEPROJ"
        exit 1
    }

echo "=== Exporting .ipa ==="
# Create a minimal exportOptions plist
EXPORT_OPTIONS="/tmp/godot_ios_exportOptions.plist"
cat > "$EXPORT_OPTIONS" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$(dirname "$OUTPUT_IPA")" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -quiet || {
        echo "WARNING: IPA export failed (signing issue?). Archive available at: $ARCHIVE_PATH"
        echo "  Open in Xcode: open $XCODEPROJ"
        exit 0
    }

echo "=== Done ==="
echo "  IPA: $OUTPUT_IPA"
echo "  Archive: $ARCHIVE_PATH"
