# Packaging

How Beckon's desktop app becomes something a person can double-click. One workflow (`.github/workflows/package.yml`) runs these scripts; CI calls it for every change and the release workflow calls it for every tag, so what is tested is what ships. Signing is described in [docs/code-signing.md](../docs/code-signing.md).

| Folder | What it makes | Runs on |
| :--- | :--- | :--- |
| `windows/beckon.iss` | `beckon-<tag>-windows-x86_64-setup.exe`: an Inno Setup installer. Per user (no administrator), Start menu entry, an uninstaller in Settings → Apps, and an option to start at sign-in. | Windows (Inno Setup 6 is on GitHub's runners) |
| `macos/` | `Beckon.app` (`make-app.sh`), signed and notarized when Apple's credentials are present (`sign-and-notarize.sh`), in a disk image (`make-dmg.sh`) | `make-app.sh` anywhere; the others need a Mac |
| `linux/` | The Linux downloads. `build-packages.sh` makes a `.deb`, an `.rpm` and an Arch package from the one description in `nfpm.yaml` (they put Beckon in the applications menu and set up `/dev/uinput`: the udev rule and the module list). `package.sh` makes `beckon-<tag>-linux-x86_64.tar.gz`: the program, icons, a desktop entry and `install.sh`, which installs into `~/.local` and removes it again with `--uninstall`. `tests/` installs each package in real Debian, Ubuntu, Fedora and Arch (Docker) and tries the one-line installer against a stand-in for GitHub | Linux (nfpm, GNU tar, Docker for the tests) |
| `icons/` | The icon in the formats each system wants, made from `docs/brand/icon.svg` by `make-icons.sh` | |

**The one-line installer** (`curl -fsSL https://beckon.omsingh.me/install.sh | sh`) is `website/install.sh`: it finds the newest release with a Linux download (a stable one if there is one), picks the package for the system (apt, dnf or zypper, pacman, or the plain download in `~/.local`), checks the file against the release's `SHA256SUMS`, installs it, and can remove it again (`--uninstall`). It is served from the website, so a change to it goes live with the next website deploy.

The Windows program itself gets its icon and version information (the name shown in Task Manager's list of startup apps, and in SmartScreen) from `crates/beckon-tray/build.rs`.

## Building one by hand

```bash
cargo build --release --bin beckon

# Linux: the tarball, and the .deb, .rpm and Arch packages (needs nfpm: github.com/goreleaser/nfpm/releases)
packaging/linux/package.sh beckon-dev-linux-x86_64 target/release/beckon dist
packaging/linux/build-packages.sh v0.0.0-dev beckon-dev-linux-x86_64 target/release/beckon dist
packaging/linux/tests/run.sh dist 2.0.0                 # installs them in real distributions (needs Docker)
# macOS (the version is numbers only)
packaging/macos/make-app.sh 2.0.0 target/release/beckon dist/app
packaging/macos/sign-and-notarize.sh app dist/app/Beckon.app     # ad hoc without credentials
packaging/macos/make-dmg.sh beckon-dev-macos dist/app/Beckon.app dist
```

```powershell
# Windows: the installer, from the program that was just built
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" "/DVersion=2.0.0" "/DSource=$PWD\target\release\beckon.exe" "/DOutputDir=$PWD\dist" "/DOutputName=beckon-dev-setup" packaging\windows\beckon.iss
```

After changing `docs/brand/icon.svg`, run `packaging/make-icons.sh` (needs `rsvg-convert`, `optipng` and Python with Pillow) and commit the results: the Windows build embeds `icons/beckon.ico`, and no build machine has the tools to make it.

## What each package does for the person

- **Starting it again opens it.** Beckon has no window, so starting it from the Start menu, Spotlight or the applications menu while it runs opens the page with the QR code. `beckon --quit` asks the running copy to quit; the Windows installer and `install.sh` use it to update a running copy.
- **Start at login** is the program's own setting (tray menu → *Start at login*): a `HKCU\...\Run` value on Windows, a LaunchAgent on macOS, an `~/.config/autostart` entry on Linux. It starts with `--background`, which keeps the page from opening by itself.
- **Uninstalling** removes the program, the Start menu or applications-menu entry and the start-at-login entry. The paired phones and the PC's identity key stay in the config folder (`%APPDATA%\Beckon`, `~/Library/Application Support/Beckon`, `~/.config/beckon`), so a reinstall keeps working with the phones that were paired.

## Package managers

People who use one expect `install` and `update` to just work, so the manifests are here, ready. After each release, `scripts/update-package-manifests.sh <tag>` fills in the version, the addresses and the checksums from the release's `SHA256SUMS`. Submitting is yours to do, because each needs your own account:

| Where | Files | How |
| :--- | :--- | :--- |
| **Arch Linux (AUR)** `beckon-bin` | `arch/PKGBUILD` | Until you have an AUR account (registration there is closed from time to time), Arch users can build the same package from a clone of this repository: `cd packaging/arch && makepkg -si`; the README says so. When registration is open, make an account on aur.archlinux.org and add your SSH key. Then `git clone ssh://aur@aur.archlinux.org/beckon-bin.git`, copy `PKGBUILD` in, run `makepkg --printsrcinfo > .SRCINFO`, commit and push. It installs the program, the icon and entry, the licenses, and the udev rule and module list that make `/dev/uinput` work. Tried with `makepkg` against a built tarball. |
| **Windows: winget** | `winget/*.yaml` | Fork `microsoft/winget-pkgs`, put the three files in `manifests/o/omsingh02/Beckon/<version>/`, and open a pull request (or let `wingetcreate` do it). It is checked by a bot and a person; an unsigned installer may be asked about. |
| **Windows: Scoop** | `scoop/beckon.json` | Make a repository `scoop-beckon`, put the file in its `bucket/` folder, and people run `scoop bucket add beckon https://github.com/omsingh02/scoop-beckon`, then `scoop install beckon`. |
| **macOS: Homebrew** | `homebrew/beckon.rb` | Make a repository `homebrew-beckon`, put the file in `Casks/`, and people run `brew install --cask omsingh02/beckon/beckon`. The main Homebrew repository wants notarized apps, so a tap of your own is the way until then. |
| **Android: Obtainium** | none | Works now: people add the repository's address and Obtainium follows the releases. |
| **Android: IzzyOnDroid** | `../android/fastlane/` | Ask for the app in their issue tracker; it takes the APK from the GitHub release and the listing from `android/fastlane/metadata`. |
| **Android: F-Droid** | `../android/fastlane/` | A merge request to `fdroiddata` (their build recipe and a review). Beckon uses no Google services and only open source libraries; the one thing they may look at is `noise-java`, which comes from JitPack at a pinned commit. |

None of these changes what the apps do or say; they are other roads to the same files. The listing in `android/fastlane/metadata/android/en-US/` (title, descriptions, changelog named after the `versionCode`, icon and phone screenshots) is also what a store shows: update `changelogs/<versionCode>.txt` and the screenshots when a release changes what people see.
