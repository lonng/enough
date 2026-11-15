# Enough

Automatic responses for macOS file and app-data permission popups.

<a href="https://github.com/jtc268/enough/releases/download/v0.1.0/Enough-0.1.0-universal.dmg"><img src="Assets/download.svg" alt="Download Enough for Mac" width="360" height="88"></a>

**Open the download. Drag Enough into Applications. Open Enough and grant Accessibility access.**

**[Buy me a coffee](https://buymeacoffee.com/refresh1)** · [Compatibility](Docs/compatibility.md) · [MIT license](LICENSE)

![Enough. A stack of Allow dialogs becomes a single green check.](Assets/banner.png)

A small menu bar app for the hundredth time Python asks for access. Free, open source, and written in Swift.

Early release. Signed by Adore LLC and notarized by Apple. macOS 13 or later. The download is 532 KB.

## Use

These instructions describe current source builds. The v0.1.0 download uses the earlier menu and automatic Allow behavior.

1. Move Enough to Applications and open it.
2. Give Enough **Accessibility** access in System Settings.
3. Choose **Allow**, **Deny**, or **Ignore** for each permission type. Every type starts at Ignore. Changes are saved locally and take effect immediately.
4. Leave it running. Click the menu bar icon to open the main panel. The Configuration tab contains rules, pause, and Launch at Login; the Activity tab shows recent responses and opens the log. Quit from the power button at the top.

The interface follows your system appearance and preferred language: English, Simplified Chinese, or Traditional Chinese. Other languages fall back to English. Permission dialog matching currently supports English system prompts.

macOS may show its normal download confirmation on the first open. Enough itself requests only Accessibility. Test fixtures are not included in the app.

Rules apply to supported requests from **any app**. **Allow** clicks Allow and grants real access to your files or app data. **Deny** clicks Don't Allow. **Ignore** leaves the dialog for you to handle. Unsupported requests are always left alone.

## Scope

- Documents, Desktop, and Downloads folder requests.
- Removable volume requests (source builds; not included in the v0.1.0 download).
- Requests to access data from other apps: experimental, not yet verified in a live approval test.
- English system dialogs with the exact supported wording and buttons.

It leaves other dialogs alone, including passwords, Touch ID, installers, camera, microphone, screen recording, and network requests. One initial Accessibility grant is required. macOS 13 or later; Intel and Apple Silicon builds. See the [tested versions and limitations](Docs/compatibility.md).

## Small by design

Native Accessibility events wake the observer. No screenshots, OCR, models, or dialog polling loop. A temporary permission check runs while the setup window is open and stops after access is granted.

The app checks Apple's dialog process signature, reads the request, then checks the same window and your current rule before pressing the selected button. Recent actions stay on your Mac. No account, analytics, or network requests. The GitHub button opens your browser when clicked.

## Build

Requires Apple's Command Line Tools or Xcode. No package dependencies.

```sh
make check
make run
```

`make run` builds the universal app, quits any running Enough instance, and opens the new main panel. Run `make` or `make help` to list the commands.

| Command | Action |
| --- | --- |
| `make check` / `make test` | Run permission matching and policy checks |
| `make build` | Build `dist/Enough.app` for Intel and Apple Silicon |
| `make open` | Restart the existing build and show its panel |
| `make fixtures` | Build disposable test apps in `dist/fixtures` |
| `make release` | Sign, notarize, and package a release |
| `make verify-release` | Verify the signed app and DMG for the current `VERSION` |
| `make clean` | Remove the default `.build` and `dist` directories |

The targets use the existing scripts and their environment variables. For example, `make run ENOUGH_OUTPUT_DIR=/tmp/enough-dist` builds and opens the app in a different output directory.

Local builds use an ad hoc signature. `make release` uses the [release script](Scripts/release.sh), which requires a Developer ID identity and notarization credentials through environment variables. Rebuilding an ad hoc app can require granting Accessibility again.

`Sources/` is the app. `Tests/` checks request matching. `Scripts/` builds and packages it. `Assets/` holds the icon source metadata and banner.

[Report a missing dialog](https://github.com/jtc268/enough/issues). Include your macOS version, language, and the request's wording. Remove private names and paths first.
