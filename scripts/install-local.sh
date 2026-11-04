#!/bin/bash
# Install the local fork alongside the intact Homebrew/upstream application.
set -euo pipefail

task_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_source_app="$task_repo_dir/export/local/OpenInTerminal Matej.app"
task_target_app="/Applications/OpenInTerminal Matej.app"
task_host_id="com.matejprepelic.OpenInTerminal"
task_extension_id="$task_host_id.OpenInTerminalFinderExtension"
task_original_extension_id="wang.jianing.app.OpenInTerminal.OpenInTerminalFinderExtension"
task_reload_finder=false

case "${1:-}" in
  '') ;;
  --reload-finder) task_reload_finder=true ;;
  *) printf 'Usage: %s [--reload-finder]\n' "$0" >&2; exit 1 ;;
esac
if [[ $# -gt 1 ]]; then
  printf 'Usage: %s [--reload-finder]\n' "$0" >&2
  exit 1
fi

if [[ ! -d "$task_source_app" ]]; then
  printf 'Build first: %s/scripts/build-local.sh\n' "$task_repo_dir" >&2
  exit 1
fi
codesign --verify --deep --strict "$task_source_app"
task_source_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$task_source_app/Contents/Info.plist")"
task_source_extension_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$task_source_app/Contents/PlugIns/OpenInTerminalFinderExtension.appex/Contents/Info.plist")"
if [[ "$task_source_id" != "$task_host_id" || "$task_source_extension_id" != "$task_extension_id" ]]; then
  printf 'Refusing to install a bundle with unexpected identifiers.\n' >&2
  exit 1
fi
if [[ -e "$task_target_app" ]]; then
  task_existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$task_target_app/Contents/Info.plist")"
  if [[ "$task_existing_id" != "$task_host_id" ]]; then
    printf 'Refusing to replace an unrelated app at %s\n' "$task_target_app" >&2
    exit 1
  fi
fi

# Stage and verify before changing the active installation. The original
# /Applications/OpenInTerminal.app and all preference domains remain intact.
task_staging_dir="$(mktemp -d /Applications/.openinterminal-matej.XXXXXX)"
trap 'rm -rf "$task_staging_dir"' EXIT
task_staged_app="$task_staging_dir/OpenInTerminal Matej.app"
ditto "$task_source_app" "$task_staged_app"
codesign --verify --deep --strict "$task_staged_app"

# Always select plugins by identifier. An unsupported selection flag can apply
# an election to unrelated Finder extensions. Disable the fork before stopping
# its process so Finder does not relaunch it during replacement.
for task_plugin_id in "$task_original_extension_id" "$task_extension_id"; do
  task_registered="$(pluginkit -mAD -i "$task_plugin_id")"
  if [[ "$task_registered" == *"$task_plugin_id("* ]]; then
    pluginkit -e ignore -i "$task_plugin_id"
  fi
done

# Match complete executable paths, rather than every process whose name contains
# OpenInTerminal. Stop only this installed fork's host and Finder extension.
task_host_executable="$task_target_app/Contents/MacOS/OpenInTerminal"
task_extension_executable="$task_target_app/Contents/PlugIns/OpenInTerminalFinderExtension.appex/Contents/MacOS/OpenInTerminalFinderExtension"
while read -r task_pid task_command; do
  if [[ "$task_command" == "$task_host_executable" || "$task_command" == "$task_extension_executable" ]]; then
    kill -TERM "$task_pid" 2>/dev/null || true
    task_attempt=0
    while [[ "$(ps -p "$task_pid" -o comm= 2>/dev/null || true)" == "$task_command" ]]; do
      if [[ "$task_attempt" -ge 50 ]]; then
        printf 'An installed fork process did not quit; installation stopped.\n' >&2
        exit 1
      fi
      sleep 0.1
      task_attempt=$((task_attempt + 1))
    done
  fi
done < <(ps -axo pid=,comm=)

if [[ -e "$task_target_app" ]]; then
  mv "$task_target_app" "$task_staging_dir/previous.app"
fi
if ! mv "$task_staged_app" "$task_target_app"; then
  if [[ -d "$task_staging_dir/previous.app" ]]; then
    mv "$task_staging_dir/previous.app" "$task_target_app"
  fi
  exit 1
fi
codesign --verify --deep --strict "$task_target_app"

# Bootstrap only a genuinely empty custom domain. Reinstalling must preserve
# the user's editor, terminal, shortcuts, and menu choices.
task_preferences="$(defaults read "$task_host_id" 2>/dev/null || true)"
task_preferences="${task_preferences//[[:space:]]/}"
task_preferences_initialized=false
if [[ -z "$task_preferences" || "$task_preferences" == '{}' ]]; then
  task_terminal=Terminal
  if [[ -d /Applications/iTerm.app ]]; then
    task_terminal=iTerm
    defaults write com.googlecode.iterm2 OpenFileInNewWindows -bool false
  fi
  defaults write "$task_host_id" DefaultTerminal -string "$task_terminal"
  defaults write "$task_host_id" DefaultEditor -string TextEdit
  defaults write "$task_host_id" iTermNewOption -string tab
  defaults write "$task_host_id" TerminalNewOption -string window
  defaults write "$task_host_id" FirstSetup -bool true
  defaults write "$task_host_id" LegacyPreferencesMigrated -bool true
  defaults write "$task_host_id" LaunchAtLogin -bool false
  defaults write "$task_host_id" QuickToggle -bool false
  defaults write "$task_host_id" QuickToggleType -string openWithDefaultTerminal
  defaults write "$task_host_id" HideStatusItem -bool false
  defaults write "$task_host_id" HideContextMenuItems -bool false
  defaults write "$task_host_id" ContextMenuUseSubmenu -bool false
  defaults write "$task_host_id" CustomMenuApplyToToolbar -bool false
  defaults write "$task_host_id" CustomMenuApplyToContext -bool false
  defaults write "$task_host_id" CustomMenuIconOption -string no
  defaults write "$task_host_id" PathEscapeOption -bool true
  task_preferences_initialized=true
fi

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$task_target_app"
pluginkit -a "$task_target_app/Contents/PlugIns/OpenInTerminalFinderExtension.appex"
pluginkit -e use -i "$task_extension_id"
open "$task_target_app"
if "$task_reload_finder"; then
  killall Finder
fi

printf 'Installed and enabled: %s\n' "$task_target_app"
if "$task_preferences_initialized"; then
  printf 'Initial preferences: %s, new iTerm tabs, TextEdit.\n' "$task_terminal"
else
  printf 'Existing preferences preserved.\n'
fi
