# Compatibility

Enough v0.1.0 is an early release. Building for an OS version is different from testing it on that version.

## Unreleased source changes

Source builds also recognize English removable-volume requests: `“App” would like to access files on a removable volume.` The `wants` variant is supported too, with or without a final period. These requests use the same signed system-host, headline, and Allow/Don't Allow button checks as folder requests. Activity is recorded as `Removable volumes`.

Source builds also cover the Music, Movies, and Pictures folder requests that use the same folder template: `“App” would like to access files in your Music folder.` Live approval of these dialogs has not yet been verified.

The menu bar icon opens a compact popover panel. Each supported permission type is a card with an Allow, Deny, or Ignore rule, saved locally and applied immediately. Missing or invalid rules default to Ignore, including on upgrade from v0.1.0. Ignore leaves the request for manual handling. Changing a rule rechecks pending requests without clicking an already handled dialog again. Pausing stops both automatic Allow and automatic Don't Allow actions.

Rules appear as cards and the five latest responses appear below them. The panel inherits the system's light or dark appearance and selects English, Simplified Chinese, or Traditional Chinese from the system language preferences, with English as the fallback. This localization covers the interface; the supported system permission titles are still English.

Matching, rejection, and policy persistence are covered by 70 automated checks. Live approval of a removable-volume dialog and automatic denial have not yet been verified. These changes are not included in the v0.1.0 download.

## Tested on September 7, 2026

macOS 27.0 beta, build 26A5425a, Apple Silicon.

| Check | Result |
| --- | --- |
| Real Documents permission request | Approved through Apple's system dialog; the requesting fixture then read the folder successfully |
| Desktop and Downloads requests | The development app clicked Allow and recorded closure; each requesting fixture read its folder successfully |
| Access to another app's data | Experimental. The local fixture returned a permission error without a recorded approval. Not proven |
| Intel and Apple Silicon release compilation | Passed |
| Installed app's first window | Visually checked |
| Request matching | 28 checks, including an app-supplied purpose string that imitates a supported title |
| Signed installer | Apple notarization, stapling, signatures, universal architecture, and Gatekeeper checks passed on the build runner and this Mac |

The macOS 14.8.9 runner allowed the fixtures to read without showing permission dialogs. That run is inconclusive for automatic approval. The downloadable v0.1.0 binary was built from commit `9a57333ab6479f306b4f6bf18200e3f59deed72e`.

The development app handled three folder requests launched together. This is not a test of hundreds of queued windows. Later repeat runs included manual interaction and are not counted as automatic approval evidence. The packaged release uses a stricter headline check than the first GUI integration run.

Only English prompt titles hosted by Apple's signed `com.apple.UserNotificationCenter` process are eligible. A different host, wording, unreadable headline, extra action button, or incomplete Accessibility tree causes the app to leave the request alone. Some protected dialogs may not expose a usable button action.

The observer disconnects while paused, asleep, locked, or in an inactive user session. It reconnects on session and app events. Lock, sleep, Spaces, multiple displays, Intel hardware, and older macOS versions still need live coverage.

## How much access does it grant?

Allow has the same effect as clicking the button yourself. Enough does not distinguish trusted and untrusted requesting apps. It does not edit the TCC database, disable SIP, grant itself Accessibility, or pre-grant every macOS permission.

For some app-container requests, macOS permission lasts only until the requesting app exits. Enough handles eligible prompts when they recur. Full Disk Access for the correct responsible app can avoid this class of request. [Apple's explanation](https://developer.apple.com/videos/play/wwdc2023/10053/?time=1066).

## Resource use

The early observer prototype used about 10.7 MiB peak resident memory in a 30-second idle run, with CPU time rounded to 0.00 seconds by the timing tool. This is a short prototype measurement, not a finished-app battery benchmark.

Dialog detection uses events. There are bounded delays for coalescing events and verifying closure, plus a temporary Accessibility setup check while the setup window is visible. There is no continuous screen or dialog scan.

## Local activity

The last 500 events are saved in `~/Library/Application Support/Enough/activity.json`. Each includes a timestamp, requesting app name, permission category, and action result. File paths and dialog body text are not recorded.

`Clicked Allow` and `Clicked Don't Allow` mean the corresponding Accessibility action succeeded. `Dialog closed` means the original window disappeared. These do not by themselves prove that an arbitrary requesting app completed its operation. Integration tests separately check the requesting fixture's result.

## Integration fixtures

`Scripts/Fixtures/build.sh OUTPUT_DIRECTORY` builds disposable folder, sandbox-owner, and reader apps. They report only operation success and directory entry counts. The owner writes one test file in its own container; launch it with `--cleanup` to remove that file.

The owner must be Developer ID signed to exercise cross-developer app-container protection reliably. An ad hoc owner and reader can access the fixture without showing a permission dialog, which is not a successful approval test.

The `Enough --probe --requester-prefix "Enough Fixture" --seconds 30` test mode runs the same engine for a bounded interval with all supported types set to Allow, independently of saved app settings. Use `--action deny` or `--action ignore` to exercise those policies. `--observe-only` records matches without clicking regardless of the policy. It still needs Accessibility trust. Reset only the disposable fixture's permission when repeating a test, never all app permissions.
