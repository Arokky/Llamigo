#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="Llamigo"
BUILD_ROOT="$REPO_ROOT/build"
APP_BUNDLE="$BUILD_ROOT/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SDK_PATH="$(xcrun --show-sdk-path --sdk macosx)"
MIN_VERSION="15.0"
EXECUTABLE_PATH="$MACOS_DIR/$APP_NAME"
ENTITLEMENTS_PATH="$BUILD_ROOT/entitlements.plist"
APP_ICONSET_DIR="$REPO_ROOT/LlamaBarn/Assets.xcassets/AppIcon.appiconset"
MENU_ICON_PATH="$REPO_ROOT/LlamaBarn/Assets.xcassets/MenuIcon.imageset/MenuIcon.pdf"

log() {
  echo "[build-local-app] $*"
}

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

SWIFT_SOURCES=()
while IFS= read -r -d '' file; do
  SWIFT_SOURCES+=("$file")
done < <(find "$REPO_ROOT/LlamaBarn" -name '*.swift' -print0 | sort -z)

plutil -convert xml1 "$REPO_ROOT/LlamaBarn/Info.plist" -o "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $APP_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string app.llamigo.Llamigo" "$CONTENTS_DIR/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier app.llamigo.Llamigo" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string 0.0.0-local" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string local" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $APP_NAME" "$CONTENTS_DIR/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile $APP_NAME" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool YES" "$CONTENTS_DIR/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :LSUIElement YES" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string public.app-category.utilities" "$CONTENTS_DIR/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :LSApplicationCategoryType public.app-category.utilities" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUEnableAutomaticChecks" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUScheduledCheckInterval" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true

log "Compiling app bundle executable"
swiftc \
  -sdk "$SDK_PATH" \
  -target "arm64-apple-macos$MIN_VERSION" \
  -O \
  -module-name "$APP_NAME" \
  -o "$EXECUTABLE_PATH" \
  "${SWIFT_SOURCES[@]}"

cp -R "$REPO_ROOT/llama-cpp" "$MACOS_DIR/llama-cpp"
cp "$REPO_ROOT/llama-cpp/version.txt" "$RESOURCES_DIR/version.txt"
cp "$REPO_ROOT/LlamaBarn/LlamaBarn.sdef" "$RESOURCES_DIR/Llamigo.sdef"
/usr/libexec/PlistBuddy -c "Set :OSAScriptingDefinition Llamigo.sdef" "$CONTENTS_DIR/Info.plist"

if [[ -d "$APP_ICONSET_DIR" ]] && command -v iconutil >/dev/null 2>&1; then
  TMP_ICONSET="$BUILD_ROOT/$APP_NAME.iconset"
  rm -rf "$TMP_ICONSET"
  mkdir -p "$TMP_ICONSET"
  cp "$APP_ICONSET_DIR"/*.png "$TMP_ICONSET/"
  iconutil -c icns "$TMP_ICONSET" -o "$RESOURCES_DIR/$APP_NAME.icns"
  rm -rf "$TMP_ICONSET"
fi

if [[ -f "$MENU_ICON_PATH" ]]; then
  cp "$MENU_ICON_PATH" "$RESOURCES_DIR/MenuIcon.pdf"
fi

cat > "$ENTITLEMENTS_PATH" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  log "Applying ad-hoc code signature"
  codesign --force --deep --sign - --entitlements "$ENTITLEMENTS_PATH" "$APP_BUNDLE"
fi

log "Built app: $APP_BUNDLE"
