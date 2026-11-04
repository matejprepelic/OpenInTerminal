#!/bin/bash
# Build the full app for this Mac without an Apple Developer account.
# The signed export is separate from the Homebrew-installed upstream app.
set -euo pipefail

task_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_build_dir="$task_repo_dir/build/local"
task_export_dir="$task_repo_dir/export/local"
task_products_dir="$task_build_dir/Build/Products/Release"
task_output_app="$task_export_dir/OpenInTerminal Matej.app"
task_host_entitlements="$task_repo_dir/OpenInTerminal/OpenInTerminal.entitlements"
task_extension_entitlements="$task_repo_dir/OpenInTerminalFinderExtension/OpenInTerminalFinderExtension.entitlements"
task_helper_entitlements="$task_repo_dir/OpenInTerminalHelper/OpenInTerminalHelper.entitlements"

for task_entitlements in \
  "$task_host_entitlements" \
  "$task_extension_entitlements" \
  "$task_helper_entitlements"; do
  if [[ ! -f "$task_entitlements" ]]; then
    printf 'Missing entitlements: %s\n' "$task_entitlements" >&2
    exit 1
  fi
done

cd "$task_repo_dir"
printf 'Building the full OpenInTerminal app...\n'
xcodebuild \
  -workspace OpenInTerminal.xcworkspace \
  -scheme OpenInTerminal \
  -configuration Release \
  -derivedDataPath "$task_build_dir" \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  MACOSX_DEPLOYMENT_TARGET=12.0 \
  build

task_built_app="$task_products_dir/OpenInTerminal.app"
task_built_helper="$task_products_dir/OpenInTerminalHelper.app"
for task_product in "$task_built_app" "$task_built_helper"; do
  if [[ ! -d "$task_product" ]]; then
    printf 'Missing build product: %s\n' "$task_product" >&2
    exit 1
  fi
done

mkdir -p "$task_export_dir"
task_staging_dir="$(mktemp -d "$task_export_dir/.build-local.XXXXXX")"
trap 'rm -rf "$task_staging_dir"' EXIT
task_staged_app="$task_staging_dir/OpenInTerminal Matej.app"
ditto "$task_built_app" "$task_staged_app"

# Host and extension metadata select the externaldrive sidebar symbol on modern
# macOS. Keep matching ICNS templates as a fallback, with blue app artwork.
xcrun swift "$task_repo_dir/scripts/generate-sidebar-icon.swift" \
  "$task_staged_app/Contents/Resources/AppIcon.icns" \
  "$task_staged_app/Contents/Resources/OpenInTerminalWithSidebar.icns"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile OpenInTerminalWithSidebar' "$task_staged_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' "$task_staged_app/Contents/Info.plist"

# The project's helper copy phase runs only for deployment postprocessing.
task_embedded_helper="$task_staged_app/Contents/Library/LoginItems/OpenInTerminalHelper.app"
mkdir -p "$(dirname "$task_embedded_helper")"
rm -rf "$task_embedded_helper"
ditto "$task_built_helper" "$task_embedded_helper"

printf 'Signing nested components for local use...\n'
# Sign leaves before their containing bundles. Keep each sandbox's source
# entitlements, without enabling or changing any system security settings.
while IFS= read -r -d '' task_component; do
  codesign --force --sign - "$task_component"
done < <(find "$task_staged_app" -type f -name '*.dylib' -print0)

while IFS= read -r -d '' task_component; do
  codesign --force --sign - "$task_component"
done < <(find "$task_staged_app" -depth -type d -name '*.framework' -print0)

while IFS= read -r -d '' task_component; do
  codesign --force --sign - \
    --entitlements "$task_extension_entitlements" "$task_component"
done < <(find "$task_staged_app" -depth -type d -name '*.appex' -print0)

while IFS= read -r -d '' task_component; do
  codesign --force --sign - \
    --entitlements "$task_helper_entitlements" "$task_component"
done < <(find "$task_staged_app" -depth -mindepth 1 -type d -name '*.app' -print0)

codesign --force --sign - \
  --entitlements "$task_host_entitlements" "$task_staged_app"
codesign --verify --deep --strict --verbose=2 "$task_staged_app"

# Replace only this generated export after the complete staged app verifies.
rm -rf "$task_output_app"
mv "$task_staged_app" "$task_output_app"
printf 'Built and verified: %s\n' "$task_output_app"
