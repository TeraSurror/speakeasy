# Speakeasy — macOS Menu Bar Manager Spec

Oct 23, 2026 · @Harsh Shelar

## Overview

**Speakeasy** is a native macOS menu bar manager: it hides, reveals, and organizes other apps' status items so nothing gets lost behind the notch. Like the bar it's named after, the good stuff is behind a hidden door.

This spec is written for a coding agent. Build milestone by milestone; each feature has acceptance criteria that define "done."

**Goals**

- Keep the visible menu bar short: only the items the user checks often.
- Make every running status item reachable, including those that would overflow behind the notch.
- Be keyboard-friendly: hotkeys and search for everything.
- Feel native: SwiftUI settings, system animations, light and dark mode, near-zero idle CPU.

**Non-goals**

- Mac App Store distribution (sandboxing blocks the required APIs). Run locally, unsigned or ad-hoc signed.
- Supporting macOS versions older than macOS 14 Sonoma.
- Replacing Control Center or system menu extras' own settings.

**Platform and stack**

| Item | Choice |
| --- | --- |
| Language | Swift 5.10+ (Swift 6 strict concurrency where practical) |
| UI | SwiftUI for settings and panels; AppKit (`NSStatusItem`, `NSPanel`) for menu bar plumbing |
| Min OS | macOS 14 Sonoma; primary target is the current macOS release |
| Hardware | Apple Silicon MacBook with a notch is the primary test machine |
| App type | Agent app: `LSUIElement = YES`, no Dock icon |
| Dependencies | Prefer none. Allowed: KeyboardShortcuts (sindresorhus) for hotkeys |

## Core concept and architecture

Speakeasy can't move or hide other apps' status items directly, so it controls the space around them. It owns a separator status item: setting the separator's `length` to a large value (e.g. 10,000 pt) pushes every item to its left off-screen, and shrinking it back reveals them. The open-source apps Hidden Bar and Ice use this technique and are good references.

&#91;embedded content: Speakeasy architecture · 3 layers\]

Each core service is a Swift protocol with one real implementation and one fake for tests; the UI never calls a macOS API directly.

**Data model**

| Type | Fields |
| --- | --- |
| `MenuBarItem` | id (bundle ID + title + index), appName, pid, windowID, frame, section |
| `Section` | `.visible`, `.hidden`, `.alwaysHidden` |
| `Rule` | id, trigger, targetItemID, action, gracePeriod, enabled |
| `Profile` | id, name, assignments (itemID → Section), auto-switch triggers |
| `Settings` | rehideDelay, rehideOnClickOutside, hotkeys, toggleIcon, showOnHover, schemaVersion |

## Milestone 1: MVP

M1 delivers a usable daily driver: one hidden section, toggle, auto-rehide, hotkey, notch warning, and settings. No Accessibility or Screen Recording permission is needed in M1.

**F1. Hidden section (separator)**

Add two status items: a **toggle** (chevron, rightmost of Speakeasy's items) and a **separator** to its left. Items the user places left of the separator are hidden by expanding the separator's `length` to push them off-screen.

- [ ] Clicking the toggle shows or hides the hidden section with no visible flicker.
- [ ] Hidden state survives app restart.
- [ ] Separator renders as a thin, subtle divider when expanded; invisible when collapsed.
- [ ] Never hides Speakeasy's own toggle.

**F2. Arrange by ⌘-drag**

Users move items across the separator using macOS's built-in ⌘-drag. Speakeasy does not move items itself in M1.

- [ ] First-run onboarding explains ⌘-drag with a short animation or image.
- [ ] Speakeasy's items have stable autosave names so macOS remembers their positions.

**F3. Auto-rehide**

- [ ] When shown, the hidden section collapses after a configurable delay (default 10 s, range 2–60 s, or Off).
- [ ] Also collapses when the user clicks outside the menu bar or switches apps (setting, default on).
- [ ] The timer pauses while any menu from a revealed item is open.

**F4. Global hotkey**

- [ ] A user-configurable hotkey toggles the hidden section (default ⌥⌘B).
- [ ] Hotkey conflicts are detected and shown in settings.

**F5. Notch awareness**

Detect when items overflow into the notch area using `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` and status item window frames.

- [ ] When any item's frame intersects the notch, Speakeasy's toggle shows a badge dot.
- [ ] Clicking the badge explains which items are affected and suggests moving them into the hidden section.
- [ ] Works correctly on displays without a notch (feature silently inactive).

**F6. Launch at login**

- [ ] Toggle in settings using `SMAppService.mainApp`.
- [ ] Default off; reflects the real system state on open.

**F7. Settings window**

SwiftUI `Settings` scene with tabs: General, Appearance, Hotkeys, About.

- [ ] General: auto-rehide delay, rehide on click outside, launch at login.
- [ ] Appearance: toggle icon style (chevron, dot, martini glass), separator visibility.
- [ ] Hotkeys: recorder for each shortcut.
- [ ] Opens from the toggle's right-click menu, which also has Quit.

## Milestone 2: Feels like Bartender

M2 adds the always-hidden section, item discovery, search, and a managed layout screen. It introduces the Accessibility permission, requested only when a feature needing it is first enabled.

**F8. Always-hidden section**

A second separator left of the first. Items beyond it stay hidden even when the normal hidden section is shown.

- [ ] Revealed only by ⌥-clicking the toggle or a dedicated hotkey (default ⌥⌘⇧B).
- [ ] Follows the same auto-rehide rules as F3.

**F9. Item discovery**

A `MenuBarItemService` enumerates all status items via `CGWindowListCopyWindowInfo`, filtered to the status bar window layer.

- [ ] Returns, per item: owning app name, bundle ID, PID, window ID, frame, and section (visible, hidden, always-hidden).
- [ ] Refreshes on app launch/quit notifications and display changes, not by constant polling.
- [ ] Items are identified by bundle ID plus title or index so identity survives restarts.

**F10. Layout screen**

A settings tab listing every discovered item in three columns: Visible, Hidden, Always Hidden. Dragging an item between columns moves it in the real menu bar.

- [ ] Moves are performed by synthesizing a ⌘-drag with `CGEvent` (requires Accessibility).
- [ ] After each move, Speakeasy re-reads positions and confirms the item landed; retries once, then shows an error.
- [ ] The cursor returns to its original position after the move.
- [ ] A "Move overflow from notch" button moves notch-obscured items into Hidden.

**F11. Search**

A hotkey (default ⌥⌘Space) opens a floating search panel listing all items with icon and app name.

- [ ] Typing filters by app name with fuzzy matching.
- [ ] Enter activates the item: reveals its section if needed, then clicks it so its menu opens.
- [ ] Arrow keys navigate; Esc closes; the panel never steals focus from fullscreen apps permanently.

**F12. Show on hover**

- [ ] Setting (default off): hovering over empty menu bar space for 300 ms reveals the hidden section.
- [ ] Does not trigger while the cursor is over another app's menu titles.

## Milestone 3: Triggers, profiles, presentation mode

M3 makes the bar context-aware: items appear when they matter, layouts switch with context, and one hotkey cleans the bar for screen sharing.

**F13. Conditional visibility rules**

A rule = trigger + target item + action (show temporarily, show while true, hide while true). Rules are evaluated by a `RuleEngine` driven by system notifications.

| Trigger | Source | Example |
| --- | --- | --- |
| Battery below N% or unplugged | IOKit power source notifications | Show battery item below 20% |
| Wi-Fi network (SSID) | CoreWLAN | Show VPN item when not on home Wi-Fi |
| App running | `NSWorkspace` notifications | Show Docker item only while Docker runs |
| Item icon changed | Periodic hash of item image (Screen Recording) | Show Dropbox while its icon is animating or badged |
| Time of day | Timer | Hide Slack after 7 pm |

- [ ] Rules are created and edited in a Rules settings tab.
- [ ] A temporarily shown item rehides after its condition clears plus a grace period (default 5 s).
- [ ] Rule evaluation is event-driven; the icon-change trigger samples no faster than once every 2 s.

**F14. Profiles**

A profile = a saved assignment of every item to a section.

- [ ] Users can save the current layout as a named profile (e.g. Work, Home).
- [ ] Switch by hotkey, menu, Wi-Fi network, or external display connected.
- [ ] Switching applies moves via F10's mover and reports any items that failed to move.

**F15. Presentation mode**

- [ ] One hotkey (default ⌥⌘P) hides every item except the clock and Speakeasy's toggle.
- [ ] Optional auto-enable when screen sharing starts or a projector/AirPlay display connects.
- [ ] Turning it off restores the exact previous layout.

**F16. Icon spacing**

- [ ] Settings slider adjusts menu bar item spacing and padding via the `NSStatusItemSpacing` and `NSStatusItemSelectionPadding` user defaults.
- [ ] Explains that a logout or menu bar restart is required, and offers a "Restart menu bar" button.
- [ ] "Reset to default" deletes the overrides.

## Stretch goals

Build these only after M3 is stable; each is independent.

- **S1. Secondary bar.** Show hidden items in a floating panel under the menu bar instead of expanding inline, for when the bar has no room. Requires capturing item images (Screen Recording) and forwarding clicks to the real items. Treat as its own milestone.
- **S2. Notch integration.** Hovering the notch expands a panel containing the hidden items, sharing code with the notch HUD app.
- **S3. Menu bar styling.** Tint, rounded "island" background, or border behind the bar, drawn by a transparent overlay window.
- **S4. Per-display layouts.** Different profiles for the built-in display and external monitors.
- **S5. Usage stats.** Count clicks per item locally and suggest hiding items unused for 14 days.
- **S6. CLI / URL scheme.** `speakeasy://toggle`, `speakeasy://profile/Work`, so scripts and Shortcuts can drive it.

## Non-functional requirements

| Area | Requirement |
| --- | --- |
| Performance | Under 0.5% CPU when idle; under 60 MB memory. No polling loops faster than 2 s; prefer notifications. |
| Responsiveness | Toggle show/hide completes in under 100 ms. |
| Permissions | Request Accessibility, Screen Recording, and Location (needed to read Wi-Fi SSID) only when a feature needing them is turned on. Each request is preceded by an in-app screen explaining why. Features degrade gracefully when denied. |
| Privacy | No network access at all. No analytics. Usage stats (S5) stay on device. |
| Persistence | Settings, rules, and profiles stored as JSON in Application Support, versioned with a schema number and migrations. |
| Resilience | If Speakeasy crashes, the separator's expanded length must not leave items stranded off-screen: collapse to default on launch before restoring state. |
| Multi-display | Correct behavior when the menu bar is on an external display or displays change while running. |
| Accessibility | All settings usable with VoiceOver and keyboard only. |
| Logging | `os.Logger` with categories (discovery, mover, rules); a "Copy diagnostics" button in About. |

## Technical notes, risks, and agent instructions

**Known risks**

| Risk | Why | Mitigation |
| --- | --- | --- |
| Synthesized ⌘-drags are flaky | Timing-sensitive; menu bar may not register fast drags | Step the drag in small increments with short delays; verify position after; retry once |
| macOS updates break the separator trick | Relies on undocumented status bar layout behavior | Keep the hiding logic behind one `SectionController` so it can be swapped; test on each new macOS beta |
| Item identity is ambiguous | Some apps own several items with no titles | Identify by bundle ID + window title + left-to-right order within that app |
| Built-in OS menu bar controls overlap | Recent macOS versions add native options to hide some items | Check what the OS already offers; don't fight system settings |
| Notch overflow detection | Overflowed items may report frames behind the notch or no window at all | Treat "window exists but frame outside visible areas" as overflow |

**Testing**

- Unit tests for the rule engine, profile diffing (current vs. target layout → list of moves), and persistence migrations.
- A `FakeMenuBar` implementing the same protocol as `MenuBarItemService` so section logic and the mover planner are testable without real windows.
- Manual test checklist per milestone run on a notched MacBook, with and without an external display, in light and dark mode.

**Instructions for the coding agent**

1. Build one milestone at a time, in order. Do not start M2 until every M1 acceptance box is met.
2. Before writing code for a milestone, propose the file list and protocols and wait for approval.
3. Keep AppKit menu bar code isolated in `MenuBar/`; SwiftUI views must not touch `NSStatusItem` directly.
4. Put every system API behind a protocol (status items, window list, events, power, Wi-Fi) so it can be faked in tests.
5. Never request a permission at launch. Request it from the feature that needs it.
6. After each feature, list how to manually verify it, mapped to its acceptance criteria.
7. Ask before adding any third-party dependency other than KeyboardShortcuts.
8. Use `Speakeasy` as the product name, bundle ID `com.<yourname>.speakeasy`, and the martini glass SF Symbol as the default toggle icon option.
