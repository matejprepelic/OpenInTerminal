# OpenInTerminal Configurations

## This personal fork

For **OpenInTerminal Matej**, use the build and installation scripts in
[README-Matej.md](../README-Matej.md). The installed bundle is
`/Applications/OpenInTerminal Matej.app`; the original Homebrew app remains intact.
The fork has its own preferences and Finder extension identifiers.

## Installing Unsigned Apps

This section applies to downloaded unsigned bundles. A local build made with
`scripts/build-local.sh` is ad-hoc signed and normally has no download quarantine.

On first launch, macOS may refuse to open the app — for example `"OpenInTerminal" is damaged and can't be opened`, or `cannot be opened because Apple cannot check it for malicious software`.

1. Move the app (`OpenInTerminal.app`, `OpenInTerminal-Lite.app` or `OpenInEditor-Lite.app`) into `/Applications`.

2. Remove the quarantine flag macOS attaches to downloaded or copied apps (repeat for each app, changing the name):

   ```
   xattr -dr com.apple.quarantine /Applications/OpenInTerminal.app
   ```

   This step matters: besides clearing the "damaged" warning, it stops macOS from running the app from a random read-only location (*App Translocation*), which would otherwise prevent the Finder extension from registering.

3. Launch the app.

Prefer not to use the command line? Control-click (right-click) the app in Finder, choose `Open`, and confirm in the dialog. On macOS 15 (Sequoia) or later, open `System Settings` -> `Privacy & Security`, scroll to the **Security** section, and click `Open Anyway` after the first blocked launch.

## Finder Extension Configuration

To enable Finder Extension, right click on Finder toolbar, select `Customize Toolbar...` as shown below:

<div>
  <img src="https://github.com/user-attachments/assets/c834f0d1-2f9d-4200-984c-3f6330eaeb2d" width="400px">
</div>

Then drag the `OpenInTerminal` icon to the toolbar:

<div>
  <img src="https://github.com/user-attachments/assets/261eb747-27f0-4484-9654-40cab8a52008" width="400px">
</div>

### Finder Extension Not Showing Up in System Settings on macOS 15 and later

#### 1) Enable the Finder Extension in Settings (Tahoe)

Go to `System Settings` -> `General` -> `Login Items & Extensions` -> `OpenInTerminal Matej Extensions`, and enable `File Provider`.

#### 2) Manually Enable the Finder Extension (macOS 15)

If the Finder extension is absent from System Settings, inspect it with
`pluginkit`:

```
$ pluginkit -mAD -p com.apple.FinderSync -vvv
```

You should see output similar to the following:

```
com.matejprepelic.OpenInTerminal.OpenInTerminalFinderExtension(2.3.9)
           Path = /Applications/OpenInTerminal Matej.app/Contents/PlugIns/OpenInTerminalFinderExtension.appex
            SDK = com.apple.FinderSync
  Parent Bundle = /Applications/OpenInTerminal Matej.app
   Display Name = OpenInTerminal Matej Finder
     Short Name = OpenInTerminalFinderExtension
    Parent Name = OpenInTerminal Matej
       Platform = macOS
```

Enable only this fork's extension by its exact identifier:

```
$ pluginkit -e use -i com.matejprepelic.OpenInTerminal.OpenInTerminalFinderExtension
```

Use `-i`, not the older `-u UUID` recipe: `-u` is not supported by the current
macOS tool. To avoid duplicate menus, the local installer disables only the
original `wang.jianing.app.OpenInTerminal.OpenInTerminalFinderExtension` identifier.

#### 3) Use FinderSyncer

Alternatively, you could use a GUI tool called [FinderSyncer](https://zigz.ag/FinderSyncer/) to enable the extension.

### Checking Finder Extension Permissions on macOS 14 and Earlier

For macOS 14 and earlier, ensure the Finder Extension is enabled via System Preferences:

1. Open the OpenInTerminal Matej app.
2. Navigate to `System Preferences` -> `Extensions` -> `Finder Extensions`.
3. Check the checkbox next to `OpenInTerminalFinderExtension`, as shown below:

<div>
  <img src="https://user-images.githubusercontent.com/11001224/78590336-448f4180-7874-11ea-827c-ad3a7bffca5e.png" width="400px">
</div>

## Preferences on macOS 26 and later

This fork saves preferences in its own `com.matejprepelic.OpenInTerminal`
UserDefaults domain. It neither reads the original app's protected App Group nor
changes its existing preferences. The installer initializes an empty fork domain
with iTerm tabs when iTerm is installed, and preserves existing fork preferences
on later installations.

The host publishes Finder preferences as `shared-settings.plist` in
`~/Library/Application Scripts/com.matejprepelic.OpenInTerminal.OpenInTerminalFinderExtension/`.
The Finder extension reads that snapshot whenever it builds a menu. This uses the
same directory as its existing AppleScripts and works with ad-hoc signing; an App
Group provisioning profile or Full Disk Access is not required. Launch the host
once after installation to publish preferences and install its scripts.

To run the preference regression checks:

```sh
Tests/SharedPreferences/run.sh
```

`scripts/build-local.sh` passes `MACOSX_DEPLOYMENT_TARGET=12.0` for Xcode 27.
Older deployment targets are rejected by that toolchain. This local build setting
does not change the deployment targets stored in the project.

## Custom Configuration

### For Neovim Users

If you select Neovim as your editor in OpenInTerminal, the app will use Kitty as the default terminal. To switch to a different terminal (supported options: Alacritty, WezTerm, and Kitty), update the fork's preferences with the following command. Adjust the Neovim path (`/opt/homebrew/bin/nvim` in this example) to match your installation:

```
defaults write com.matejprepelic.OpenInTerminal NeovimCommand "open -na wezterm --args start /opt/homebrew/bin/nvim PATH"
```

Other terminal configurations:

```
// kitty:
"open -na kitty --args /opt/homebrew/bin/nvim PATH"
// WezTerm:
"open -na wezterm --args start /opt/homebrew/bin/nvim PATH"
// Alacritty:
"open -na Alacritty --args -e /opt/homebrew/bin/nvim PATH"
```

### For Kitty Users

The default launch behavior for kitty is to open a new instance for each command, like the following:

```
open -na kitty --args --single-instance --instance-group 1 --directory
```

To customize this behavior, write the command to the fork's preferences domain:

```
defaults write com.matejprepelic.OpenInTerminal KittyCommand "open -na kitty --args --single-instance --instance-group 1 --directory"
```

## FAQ ❓

<details><summary>Oops, hit <code>Don't Allow</code> button by mistake.</summary><br>
<p>The basic iTerm context-menu action does not require Finder Automation access. If you denied an AppleScript-driven terminal feature, reset the fork's Automation permissions and invoke that feature again.</p>
<br><code>tccutil reset AppleEvents com.matejprepelic.OpenInTerminal</code><br>
</details>

<details><summary>Special characters in the <code>path</code>.</summary><br>
<p>The general open action quotes each path argument separately, so spaces and apostrophes are supported.</p>
</details>

<details><summary>Open two Terminal windows on Mojave</summary><br>
<p>This problem usually occurs when you first start Terminal. Try using <code>⌘W</code> to close Terminal window, instead of using <code>⌘Q</code> to quit Terminal.</p>
</details>

<details><summary>OpenInTerminal doesn't work as I expected</summary><br>
<p>OpenInTerminal works as the following order:</p>
<ul>
<li>1. Open the file or folder you selected.</li>
<li>2. If nothing's selected, it opens the top Finder window.</li>
<li>3. If there's no Finder window, it opens the desktop.</li>
</ul>
</details>

<details><summary>My custom app doesn't work.</summary><br>
<p>If your custom application doesn't work with the following command, then it's not supported. For example, GitHub Desktop:</p>
<code>open -a GitHub\ Desktop ~/Desktop</code>
</details>
