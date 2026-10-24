# Manual testing and known limitations

Run on a notched MacBook, with and without an external display, in light and dark mode.

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

## Known limitations

- No martini SF Symbol exists; the "Martini glass" icon option uses `wineglass`.
- Hotkey conflicts are detected against macOS system shortcuts only; other apps' global hotkeys can't be observed.
- Notch overflow detection reads status item window frames. If macOS removes overflowed items' windows entirely, they can't be detected.
