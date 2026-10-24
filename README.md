# Speakeasy

A native macOS menu bar manager. Hide the icons you rarely need behind a glass, keep every icon reachable (even
ones that would vanish behind the notch), and rearrange them from a settings screen.

- **Hidden and always hidden sections**, revealed by click, hotkey (⌥⌘B, ⌥⌘⇧B) or hovering
- **Auto-hide** after a delay, when you click away, and while a menu is open
- **Notch warning** when icons don't fit
- **Layout screen** to move icons between Visible, Hidden and Always Hidden
- **Icon spacing** control for every app's menu bar icons
- No network access, no analytics

## Documentation

- **[User guide](docs/USAGE.md)**: install, usage, every setting, shortcuts, permissions and troubleshooting
  (also published as a web page, see below)
- [Manual testing and known limitations](docs/TESTING.md)
- [Project spec](Speakeasy%20%E2%80%94%20macOS%20Menu%20Bar%20Manager%20Spec.md)

`docs/USAGE.md` is the source. `docs/index.html` is generated from it (`python3 docs/build_html.py`), and the
`Docs` GitHub Actions workflow regenerates and publishes `docs/` to GitHub Pages on every push to `main` that touches it.
One-time setup: repository Settings → Pages → Source: **GitHub Actions**.

## Build and run

Requires macOS 14 or later.

```
swift test          # unit tests
./build.sh          # builds build/Speakeasy.app (ad-hoc signed)
open build/Speakeasy.app
```

Bundle ID: `com.harshshelar.speakeasy`. Because `build.sh` signs ad hoc, every rebuild looks like a new app to macOS and
drops its Accessibility grant; see [Troubleshooting](docs/USAGE.md#troubleshooting).

## Code layout

- `Sources/SpeakeasyKit/MenuBar/`: all `NSStatusItem` / AppKit menu bar code
- `Sources/SpeakeasyKit/Services/`: protocols plus real implementations (settings, login item, hotkeys, item discovery, mover)
- `Sources/SpeakeasyKit/UI/`: SwiftUI views (never touch status items)
- `Tests/SpeakeasyTests/`: fakes and unit tests

## License

[MIT](LICENSE)
