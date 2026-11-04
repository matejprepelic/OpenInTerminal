# OpenInTerminal Matej

Personal fork of [Ji4n1ng/OpenInTerminal](https://github.com/Ji4n1ng/OpenInTerminal).
It installs alongside the upstream Homebrew app as **OpenInTerminal Matej**.

## Changes

- Declares the neutral `externaldrive` sidebar symbol in both the host and Finder
  extension metadata. Matching monochrome ICNS representations remain as a
  fallback. Finder no longer uses the blue application artwork for monitored
  volume sidebar entries; ordinary app-icon representations remain blue.
- Keeps individual mounted-volume scopes, including newly mounted volumes, so
  context menus remain available at volume roots and in their subdirectories.
- Uses an independent `com.matejprepelic.OpenInTerminal` preferences domain and a
  private Application Scripts snapshot for the sandboxed Finder extension.
- Removes the redundant Finder activation from the general open script. Context
  menu paths come from Finder Sync, and launching iTerm requires no Finder
  Automation permission.
- Keeps the original bundle and preferences available for rollback. Homebrew
  updates to the original app do not replace this custom build.

The sidebar workaround intentionally supplies the same neutral `externaldrive`
symbol for monitored volume roots. It restores a disk-shaped sidebar icon rather
than each volume's individual custom artwork. Finder can still omit third-party
context menus inside iCloud/File Provider folders.

## Build and install

Requirements: Xcode 27 with its command-line tools and Swift Package Manager
network access. The full app's ShortcutRecorder dependency is resolved by Xcode.

```sh
./scripts/build-local.sh
./scripts/install-local.sh --reload-finder
```

Build output: `export/local/OpenInTerminal Matej.app`.
Installed app: `/Applications/OpenInTerminal Matej.app`.
The local build is ad-hoc signed, and its nested framework, helper and extension
signatures are verified before installation. No system security settings are
disabled.

On the first installation, the installer selects iTerm tabs when iTerm is
installed. Later installations preserve the fork's preferences. Reopen the app
to change them.

## Checks

```sh
./Tests/SharedPreferences/run.sh
bash -n scripts/build-local.sh scripts/install-local.sh
codesign --verify --deep --strict '/Applications/OpenInTerminal Matej.app'
```

Runtime acceptance checks include the sidebar icons, local background and
folder-item menus, a path containing spaces and an apostrophe, a mounted-volume
root, and a subdirectory on that volume.

## Restore the upstream extension

```sh
pluginkit -e ignore -i com.matejprepelic.OpenInTerminal.OpenInTerminalFinderExtension
pluginkit -e use -i wang.jianing.app.OpenInTerminal.OpenInTerminalFinderExtension
open /Applications/OpenInTerminal.app
killall Finder
```

Use `pluginkit -mAD -p com.apple.FinderSync` to check the selected extensions.
Use `-i` to select a specific identifier; the current macOS `pluginkit` does not
support the `-u UUID` recipe found in some older upstream instructions.

## Attribution

The preferences snapshot work is based on Yuehao Wang's upstream
[PR #293](https://github.com/Ji4n1ng/OpenInTerminal/pull/293), adapted to the fork's
independent identity without reading the original app's protected group data.
The original MIT license remains in [LICENSE](LICENSE).
