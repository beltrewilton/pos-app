# Release and deployment runbook

This runbook publishes the **Tigoo POS** native client (`client/`) to GitHub
Releases. The application is built with Tauri v2. Its production wrapper reads
`server/.env-prod` and embeds `PHOENIX_SERVER_DNS` into the native application;
therefore a release must not be built with the development environment file.

## 1. Release preparation

1. Start from a clean, reviewed commit on the release branch.
2. Choose a SemVer version, for example `0.2.0`, and a matching tag,
   `v0.2.0`.
3. Update the version in all three files, keeping them identical:

   - `client/package.json`
   - `client/src-tauri/tauri.conf.json`
   - `client/src-tauri/Cargo.toml`

4. Create `server/.env-prod` from the production configuration and set the
   public TLS endpoint, for example:

   ```sh
   PHOENIX_SERVER_DNS=api.example.com
   ```

   Do not commit this file or any production secrets. Confirm that the DNS name
   and certificate are live before building.
5. From `client/`, install the pinned JavaScript dependencies and run the
   checks appropriate to the release:

   ```sh
   npm ci
   npm run tauri -- build --debug
   ```

   The debug build is a smoke test only. Build the distributable artifacts with
   the production commands below.

## 2. Signing material

Prepare signing before invoking a release build. Keep private keys in the OS
keychain or CI secrets; never add them to the repository or a GitHub Release.

- **Windows:** obtain an Authenticode code-signing certificate and configure
  the Tauri Windows signing environment for the Windows builder. Sign the MSI
  and/or NSIS setup executable after they are created if the signing provider
  is external.
- **macOS:** use an Apple Developer ID Application certificate and configure
  `APPLE_SIGNING_IDENTITY`. Set Apple notarization credentials in the builder
  environment (prefer App Store Connect API-key credentials). Notarize and
  staple the DMG before publication.
- **Android:** create and protect an upload keystore. Configure the generated
  Android app module to use it for `release` builds. In CI, restore the
  base64-encoded keystore to a temporary path and write
  `src-tauri/gen/android/keystore.properties` from secrets.
- **Linux:** packages normally do not require a code-signing certificate for a
  GitHub download. If publishing to a package repository, sign the repository
  metadata/package with its required GPG key.

## 3. Build Windows installer

Build on `windows-latest` (or a maintained Windows release machine). Native
Windows builds are preferred because MSI generation requires WiX on Windows.

```powershell
cd client
npm ci
npm run tauri -- prod --target x86_64-pc-windows-msvc
```

With the current `"targets": "all"` configuration, collect the signed files
from these directories:

```text
src-tauri/target/x86_64-pc-windows-msvc/release/bundle/msi/*.msi
src-tauri/target/x86_64-pc-windows-msvc/release/bundle/nsis/*-setup.exe
```

Ship the NSIS installer as the primary direct-download installer and include
the MSI when enterprise deployment requires it. Test installation, launch,
upgrade over the prior version, server connectivity, and receipt-printer
access on a clean Windows VM.

## 4. Build Ubuntu/Linux packages

Build on Ubuntu. Install the WebKitGTK and bundling dependencies before the
Tauri build:

```sh
sudo apt-get update
sudo apt-get install -y libwebkit2gtk-4.1-dev libappindicator3-dev \
  librsvg2-dev patchelf xdg-utils

cd client
npm ci
npm run tauri -- prod --target x86_64-unknown-linux-gnu
```

Collect the generated packages:

```text
src-tauri/target/x86_64-unknown-linux-gnu/release/bundle/appimage/*.AppImage
src-tauri/target/x86_64-unknown-linux-gnu/release/bundle/deb/*.deb
src-tauri/target/x86_64-unknown-linux-gnu/release/bundle/rpm/*.rpm
```

Publish the AppImage for portable downloads and the `.deb` for Ubuntu/Debian
users. Include the RPM only if it was built and tested. When building Linux
from macOS through Docker emulation, build and publish the `.deb` and `.rpm`
only: `linuxdeploy` AppImage packaging is not reliable under that emulation.
Build the AppImage on a native x86_64 Linux builder. Install each package in a
clean matching VM, launch it, and verify the production endpoint.

## 5. Build macOS packages

Build each architecture on macOS. Do not relabel an Arm artifact as Intel, or
the reverse. Use a universal binary only after explicitly configuring and
testing that approach.

```sh
cd client
npm ci

# Apple Silicon
npm run tauri -- prod --target aarch64-apple-darwin

# Intel (run on an Intel builder or a CI runner that supports this target)
npm run tauri -- prod --target x86_64-apple-darwin
```

For each target, collect the signed and notarized disk image:

```text
src-tauri/target/<target>/release/bundle/dmg/*.dmg
```

If Tauri also creates an `.app` bundle, retain it as an internal validation
artifact; publish the stapled DMG as the primary GitHub Release download.
Validate the DMG on a clean Mac of the matching architecture: mount, drag to
Applications, launch, and confirm Gatekeeper accepts the signed/notarized app.

## 6. Build Android packages

The Android project is not currently checked into this repository. Initialize
it once on a machine with Android Studio, an Android SDK, Java, Rust, and the
required Android Rust targets installed:

```sh
cd client
npm ci
npm run tauri -- android init
```

Review and commit the generated `client/src-tauri/gen/android/` project files,
but do not commit `keystore.properties` or the keystore. Configure the Android
package identifier, icon, signing configuration, and required permissions
before the first release.

Create both a Play Store upload bundle and a directly installable test APK:

```sh
cd client
npm run tauri -- android prod --aab
npm run tauri -- android prod --apk
```

Collect and verify:

```text
src-tauri/gen/android/app/build/outputs/bundle/universalRelease/*.aab
src-tauri/gen/android/app/build/outputs/apk/universal/release/*.apk
```

Upload the signed `.aab` to Google Play Console (the first upload must be made
there manually). Attach the signed APK to GitHub Releases only when it is
intended for sideloading; otherwise retain it as a QA artifact. Install it on
a physical Android device and test launch, login, connectivity, and any mobile
printer workflows before publishing.

## 7. Stage artifacts and generate checksums

Use one staging directory with clear, versioned filenames. Run this after
copying only the release-ready, signed/notarized artifacts into `release/`:

```sh
mkdir -p release
# Copy and rename each approved artifact, for example:
# Tigoo-POS_0.2.0_windows_x64-setup.exe
# Tigoo-POS_0.2.0_linux_amd64.AppImage
# Tigoo-POS_0.2.0_macos_arm64.dmg
# Tigoo-POS_0.2.0_android_universal.apk

cd release
shasum -a 256 * > SHA256SUMS.txt
```

Check that the staged files contain no unsigned macOS or Windows binaries and
that `SHA256SUMS.txt` lists every artifact exactly once.

## 8. Publish the GitHub Release

Create an annotated tag from the verified release commit, push it, and publish
the staged artifacts. The GitHub CLI requires a token with repository contents
write permission.

```sh
git tag -a v0.2.0 -m "Tigoo POS v0.2.0"
git push origin v0.2.0

gh release create v0.2.0 release/* \
  --title "Tigoo POS v0.2.0" \
  --generate-notes
```

For a release candidate, add `--prerelease`. Review the draft/release page
before publishing: tag, notes, asset names, architectures, file sizes, and
checksums must all match the tested artifacts.

## 9. Post-publication verification

1. Download each public artifact from the GitHub Release, not from the build
   workspace.
2. Verify its checksum against `SHA256SUMS.txt`.
3. Repeat a clean-machine install and launch for Windows, Ubuntu, and both
   macOS architectures; install the Android APK only if it was published.
4. Confirm the client reaches the production Phoenix endpoint and complete the
   release record with the GitHub Release URL, tag SHA, and test evidence.

## CI recommendation

Automate sections 3–8 with a GitHub Actions matrix triggered by `v*` tags:
Windows x64, Ubuntu x64, macOS Arm64, and macOS x64. Keep signing and
notarization credentials in GitHub Actions secrets, upload all jobs’ artifacts
to one release job, generate `SHA256SUMS.txt` there, and create the GitHub
Release only after every platform build and smoke test succeeds.
