# Enough

Automatic approval for macOS file and app-data permission popups.

**[Buy me a coffee](https://buymeacoffee.com/refresh1)** · [Compatibility](Docs/compatibility.md) · [MIT license](LICENSE)

![Enough. A stack of Allow dialogs becomes a single green check.](Assets/banner.png)

A small menu bar app for the hundredth time Python asks for access. Free, open source, and written in Swift.

The first signed release is being prepared. Source builds work now.

## Use

1. Move Enough to Applications and open it.
2. Give Enough **Accessibility** access in System Settings.
3. Leave it running. Pause or quit from the menu bar.

Enough clicks **Allow** for supported requests from **any app**. This grants real access to your files and app data. Turn it on only when that is what you want.

## Scope

- Documents, Desktop, and Downloads folder requests.
- Requests to access data from other apps.
- English system dialogs with the exact supported wording and buttons.

It leaves other dialogs alone, including passwords, Touch ID, installers, camera, microphone, screen recording, and network requests. One initial Accessibility grant is required. macOS 13 or later; Intel and Apple Silicon builds. See the [tested versions and limitations](Docs/compatibility.md).

## Small by design

Native Accessibility events wake the observer. No screenshots, OCR, models, or dialog polling loop. A temporary permission check runs while the setup window is open and stops after access is granted.

The app checks Apple's dialog process signature, reads the request, then checks the same window again before pressing Allow. Recent actions stay on your Mac. No account, analytics, or network requests. The GitHub and coffee buttons open your browser when clicked.

## Build

Requires Apple's Command Line Tools or Xcode. No package dependencies.

```sh
Scripts/check.sh
Scripts/build.sh
open dist/Enough.app
```

Local builds use an ad hoc signature. The [release script](Scripts/release.sh) accepts a Developer ID identity and notarization credentials through environment variables. Rebuilding an ad hoc app can require granting Accessibility again.

`Sources/` is the app. `Tests/` checks request matching. `Scripts/` builds and packages it. `Assets/` holds the icon source metadata and banner.

[Report a missing dialog](https://github.com/jtc268/enough/issues). Include your macOS version, language, and the request's wording. Remove private names and paths first.
