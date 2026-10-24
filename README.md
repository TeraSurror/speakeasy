# Speakeasy

A native macOS menu bar manager. See `Speakeasy — macOS Menu Bar Manager Spec.md`.

Status: **Milestone 1 (MVP)** and **Milestone 2** (F8, F9, F10, F12) and F16 (icon spacing) from Milestone 3 implemented. F11 (search) and F13–F15 were deliberately skipped.

## Build and run

```
swift test          # unit tests
./build.sh          # builds build/Speakeasy.app (ad-hoc signed)
open build/Speakeasy.app
```

Requires macOS 14+. Bundle ID: `com.harshshelar.speakeasy`.

## Layout

- `Sources/SpeakeasyKit/MenuBar/` — all `NSStatusItem` / AppKit menu bar code
- `Sources/SpeakeasyKit/Services/` — protocols plus real implementations (settings, login item, hotkeys)
- `Sources/SpeakeasyKit/UI/` — SwiftUI views (never touch status items)
- `Tests/SpeakeasyTests/` — fakes (`FakeHost`, `FakeScheduler`, `FakeMenuBar`, ...) and unit tests

## M1 manual verification (notched MacBook, with/without external display, light and dark)

| Feature | Check |
| --- | --- |
| F1 | Launch. ⌘-drag an icon left of the `\|` divider. Click the glass: the icon vanishes/reappears without flicker. Quit and relaunch: the hidden state is restored. The divider is visible only while revealed. ⌘-drag the glass itself left of the divider, then try to hide: nothing hides. |
| F2 | First launch shows the welcome window with the ⌘-drag animation (also under right-click → Welcome Guide). Quit/relaunch: Speakeasy's items stay in the same positions. |
| F3 | Reveal, wait the configured delay (Settings → General): it hides. Reveal, click in another app's window or switch apps: it hides. Reveal, open a revealed item's menu and wait past the delay: it stays until the menu closes. Set the delay to Off: no timer rehide. |
| F4 | ⌥⌘B toggles. Settings → Hotkeys: record ⌘Space; a conflict warning appears. |
| F5 | On a notched Mac, fill the menu bar until items reach the notch: a red dot appears on the glass. Click the glass: an explanation popover lists the apps. Right-click menu has "Items Hidden by the Notch…". On a non-notched display nothing appears. |
| F6 | Settings → General → Launch at login is off by default; toggling it appears in System Settings → General → Login Items; the toggle reflects changes made there. |
| F7 | Right-click the glass → Settings… opens General / Appearance / Hotkeys / About; right-click → Quit quits. About → Copy Diagnostics puts a report on the clipboard. |

## M2 manual verification

| Feature | Check |
| --- | --- |
| F10 | Settings → Layout shows an explainer until Accessibility is granted (nothing is requested at launch). After granting, drag an item between the Visible / Hidden / Always Hidden columns (or right-click → Move to…): the section slides open, the item is ⌘-dragged in the real bar, and the pointer returns. A wrong landing is retried once, then an error shows. "Move overflow from notch" moves notch-covered items to Hidden; an item completely behind the notch can't be grabbed and reports an error. |

## F16 manual verification

| Check |
| --- |
| Settings → Appearance → Icon spacing. Move the slider and release: the "Log out, or restart the menu bar" notice appears and `defaults -currentHost read -g NSStatusItemSpacing` (and `NSStatusItemSelectionPadding`) show the value. |
| Click "Restart menu bar": the bar blinks, icons come back closer together, the notice disappears. Check Speakeasy's toggle and separators are still in place. |
| "Reset to default": both keys are gone from `defaults -currentHost read -g`, the slider returns to Default, and another restart restores the original spacing. |

## Notes on item discovery (macOS 26)

On macOS 26 every status item window is owned by Control Center, so the window list alone can't say which app an item
belongs to. With Accessibility granted, Speakeasy reads each app's `AXExtrasMenuBar` for ownership, labels and
positions (including items pushed off-screen) and matches them to windows by position. Without it, only on-screen items
appear, all attributed to Control Center. Because `build.sh` signs ad hoc, **every rebuild changes the app's identity and
macOS drops the Accessibility grant**: remove and re-add Speakeasy in System Settings → Privacy & Security → Accessibility
after rebuilding.

## Known limitations (M1)

- No martini SF Symbol exists; the "Martini glass" icon option uses `wineglass`.
- Hotkey conflicts are detected against macOS system shortcuts only; other apps' global hotkeys can't be observed.
- Notch overflow detection reads status item window frames. If macOS removes overflowed items' windows entirely, they can't be detected.
