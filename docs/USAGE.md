# Speakeasy: User Guide

Speakeasy is a macOS menu bar manager. It hides the status icons you rarely need behind a glass icon, keeps every icon reachable (even ones that would disappear behind the notch), and lets you rearrange them without leaving the keyboard.

- **Requires:** macOS 14 Sonoma or later (developed on macOS 26)
- **Runs as:** a menu bar only app (no Dock icon)
- **Privacy:** no network access, no analytics. Everything stays on your Mac.

## Contents

1. [Install and first launch](#install-and-first-launch)
2. [The basics](#the-basics)
3. [Arranging your icons](#arranging-your-icons)
4. [The always hidden section](#the-always-hidden-section)
5. [Showing and hiding automatically](#showing-and-hiding-automatically)
6. [The notch warning](#the-notch-warning)
7. [The Layout screen](#the-layout-screen)
8. [Settings reference](#settings-reference)
9. [Keyboard shortcuts](#keyboard-shortcuts)
10. [Permissions](#permissions)
11. [Troubleshooting](#troubleshooting)
12. [What is not included](#what-is-not-included)

## Install and first launch

Speakeasy is built from source and is not on the Mac App Store (sandboxing blocks the APIs it needs).

```sh
git clone git@github.com:TeraSurror/speakeasy.git
cd speakeasy
swift test        # optional: run the unit tests
./build.sh        # builds build/Speakeasy.app, ad-hoc signed
open build/Speakeasy.app
```

On first launch a **Welcome** window shows how to ⌘-drag icons. You can reopen it any time from the glass icon's right-click menu (**Welcome Guide…**).

To start Speakeasy automatically, turn on **Settings → General → Launch at login**.

## The basics

Speakeasy adds three small items to your menu bar:

| Item | What it is |
| --- | --- |
| **Glass icon** (rightmost) | The toggle. Click it to show or hide the hidden section. |
| **Thin divider** `\|` | The separator. Icons to its **left** are hidden; icons to its right stay visible. |
| **Second divider** (further left) | The always hidden separator (see [below](#the-always-hidden-section)). |

When the hidden section is collapsed, the dividers are invisible and the icons to their left are pushed off screen. Click the glass to slide them back in.

**Right-click the glass** for the menu: Show or Hide Items, Show or Hide Always-Hidden Items, Settings…, Welcome Guide…, and Quit Speakeasy.

## Arranging your icons

macOS lets you rearrange menu bar icons by holding **⌘** and dragging them. Speakeasy uses this:

1. Hold **⌘** and drag an icon to the **left** of the divider. It becomes hidden.
2. To make a hidden icon visible again, reveal the hidden section, then ⌘-drag the icon to the **right** of the divider.

Speakeasy's own items remember their positions between launches. You can also move icons from the [Layout screen](#the-layout-screen) without dragging in the menu bar yourself.

> **Tip:** Don't drag the glass icon to the left of a divider. If you do, Speakeasy refuses to hide anything, so the glass can never disappear.

## The always hidden section

Anything to the left of the **second divider** is *always hidden*: it stays hidden even when you show the normal hidden section. Use it for icons you almost never need.

- **⌥-click** the glass, or press **⌥⌘⇧B**, to reveal everything, including the always hidden section.
- Do the same again to collapse only the always hidden section; the normal hidden section stays open.
- The same auto-hide rules apply (below).

## Showing and hiding automatically

### Auto-hide

After you reveal the hidden section, it collapses by itself after a delay (default **10 s**, adjustable from 2 to 60 s, or off).

- The timer **pauses while a menu from a revealed icon is open**, then starts again when the menu closes.
- With **Hide when I click away** on (default), the section also collapses when you click outside the menu bar or switch to another app.

### Show on hover (optional)

Turn on **Settings → General → Show on hover** and rest the pointer on empty menu bar space for about 0.3 seconds to reveal the hidden section.

- It never triggers over an app's menu titles, over the notch, or over your icons and the glass.
- On notched displays the trigger zone is the empty area right of the notch. On other displays it is the right half of the bar.

## The notch warning

On Macs with a notch, icons that don't fit can end up behind it. When Speakeasy detects this, a **red dot** appears on the glass.

- Click the glass: a popover lists the affected apps and suggests moving them into the hidden section.
- The right-click menu also has **Items Hidden by the Notch…**.
- On displays without a notch nothing appears.

## The Layout screen

**Settings → Layout** lists every menu bar icon in three columns: **Visible**, **Hidden**, and **Always Hidden**.

- **Drag** an item to another column, or **right-click** it and choose **Move to…**. VoiceOver users get the same choices as actions.
- Speakeasy does the move in the real menu bar for you: it opens the sections, ⌘-drags the icon, checks that it landed (retrying once if not), puts the pointer back where it was, and restores the previous hidden state.
- **Move overflow from notch** moves icons covered by the notch into Hidden. An icon completely behind the notch cannot be grabbed and reports an error; move another icon out of the way first.
- A warning triangle marks items hidden by the notch.
- Items that Control Center owns appear with their real names (Battery, Wi‑Fi, Clock…).

The Layout screen needs [Accessibility access](#permissions). Until it's granted, the screen explains why and offers a **Grant Access…** button.

## Settings reference

Open Settings from the glass icon's right-click menu.

### General

| Setting | Meaning |
| --- | --- |
| Hide automatically | Collapse the hidden section after a delay. |
| Delay | 2–60 seconds. |
| Hide when I click away | Collapse when you click outside the menu bar or switch apps. |
| Show on hover | Reveal the hidden section by resting the pointer on empty bar space. |
| Launch at login | Starts Speakeasy at login. Reflects the real system state, even if you change it in System Settings → General → Login Items. |
| Welcome guide | Shows the ⌘-drag tutorial again. |

### Layout

See [The Layout screen](#the-layout-screen).

### Appearance

| Setting | Meaning |
| --- | --- |
| Toggle icon | Martini glass (default), chevron, or dot. |
| Slide animation | Icons glide in and out. Automatically off when **Reduce Motion** is on. |
| Divider | Show a thin line between hidden and visible items while revealed. |
| Icon spacing | Space between menu bar icons for **every** app (2–16 pt). Smaller values fit more icons. |

**Icon spacing** changes macOS settings (`NSStatusItemSpacing` and `NSStatusItemSelectionPadding`), so it only takes effect after the menu bar restarts:

1. Move the slider and release.
2. Click **Restart menu bar** (the bar blinks briefly) or log out and back in.
3. **Reset to default** removes the overrides; restart the menu bar again to see the original spacing.

### Hotkeys

Click a recorder and press the shortcut you want. If it clashes with a macOS system shortcut, a warning appears. Clashes with other apps' global shortcuts can't be detected.

### About

Shows the version and a Quit button. **Copy Diagnostics** puts a report on the clipboard that you can paste into a bug report.

## Keyboard shortcuts

| Shortcut | Action | Customizable |
| --- | --- | --- |
| **⌥⌘B** | Show or hide the hidden section | Yes (Hotkeys) |
| **⌥⌘⇧B** | Show or hide the always hidden section | Yes (Hotkeys) |
| **⌥-click** the glass | Show or hide the always hidden section | No |
| **Right-click** or **⌃-click** the glass | Open the menu | No |
| **⌘-drag** an icon | Rearrange it (built into macOS) | No |
| **⌘W** / **⌘Q** | Close the settings window / quit | No |

## Permissions

Speakeasy never asks for a permission at launch. It asks only when you use a feature that needs it, and explains why first.

| Permission | Needed for | If you decline |
| --- | --- | --- |
| **Accessibility** | The Layout screen (moving icons, and reading which app owns each icon) | Everything else works. You can still ⌘-drag icons yourself. Without it, the Layout screen can't list hidden items, and on macOS 26 icons appear as "Control Center". |

To grant it: **Layout → Grant Access…**, then switch Speakeasy on in **System Settings → Privacy & Security → Accessibility**.

## Troubleshooting

**The Layout screen shows only "Control Center", or hidden items are missing.**
Accessibility access is off or out of date. On macOS 26 every menu bar icon belongs to Control Center as far as the window list is concerned; Speakeasy reads the real owners through Accessibility.

**I rebuilt Speakeasy and Accessibility stopped working.**
`build.sh` signs the app ad hoc, so every rebuild looks like a new app to macOS. In **System Settings → Privacy & Security → Accessibility**, select Speakeasy and click **−**, then add the new build (or use **Grant Access…** again). If the old entry lingers:

```sh
tccutil reset Accessibility com.harshshelar.speakeasy
```

**An icon won't move from the Layout screen.**
Speakeasy retries once, then shows an error. Try again, or ⌘-drag it yourself. Icons completely behind the notch can't be grabbed.

**Icons I hid are gone and I can't find the glass.**
Quit and relaunch Speakeasy. On launch it always collapses the dividers to their normal size before restoring your hidden state, so nothing is left stranded off screen.

**Icon spacing didn't change.**
Click **Restart menu bar**, or log out and back in. The spacing is read by macOS only when the menu bar starts.

**The glass shows a red dot but I see no problem.**
Items overlap the notch area. Click the glass to see which apps, then hide some of them.

**Reporting a bug.**
Open **Settings → About → Copy Diagnostics** and paste the report into your issue. For live logs:

```sh
/usr/bin/log stream --level info --predicate 'subsystem == "com.harshshelar.speakeasy"'
```

Use `/usr/bin/log` explicitly: in zsh, plain `log` is a shell builtin.

## What is not included

Some features in the original plan were deliberately left out: **search** (a hotkey that lists and clicks any icon), **rules** (show icons on conditions such as battery or Wi‑Fi), **profiles** (named layouts), and **presentation mode**. See the project spec in the repository for details.
