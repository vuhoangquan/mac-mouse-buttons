# mac-mouse-buttons

A tiny native macOS helper that turns your mouse's two side buttons into **Mission Control / Launchpad** buttons, with **hold-and-move gestures**, like Logi Options+ "Window navigation", but without any third-party app.

- Pure Swift, one file, no dependencies
- Runs in the background as a LaunchAgent (starts at login)
- Settings live in a JSON file; change them without rebuilding

## What it does

Quick click = click action. Hold a side button, move the mouse past the threshold, release = gesture (the cursor snaps back to where it started).

Default mapping (`config.json`):

| | Back button (3) | Forward button (4) |
|---|---|---|
| Click | Mission Control | Launchpad |
| Hold + ↑ | Mission Control | Mission Control |
| Hold + ↓ | App Exposé | Show Desktop |
| Hold + ← | Desktop to the left | Desktop to the left |
| Hold + → | Desktop to the right | Desktop to the right |

On macOS 26 Tahoe, where Launchpad was replaced, `launchpad` opens the new Apps launcher.

## Install

Requires Xcode or the Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/vuhoangquan/mac-mouse-buttons.git ~/.local/share/mouse-buttons
bash ~/.local/share/mouse-buttons/install.sh
```

Then grant permission: **System Settings → Privacy & Security → Accessibility** → add `~/Applications/MouseButtons.app` and switch it on. It starts working within ~10 seconds.

> The installer signs the app with your Apple Development / Developer ID certificate if you have one, so rebuilds keep the Accessibility permission. With ad-hoc signing, each rebuild needs the permission re-granted (remove the old entry with **–**, add it again with **+**).

The scripts expect to live in `~/.local/share/mouse-buttons`.

## Customize

Edit `config.json`, then run:

```bash
bash ~/.local/share/mouse-buttons/reload.sh
```

Available actions:

| Action | Does |
|---|---|
| `missionControl` | Mission Control |
| `appExpose` | All windows of the current app |
| `showDesktop` | Show Desktop |
| `launchpad` | Launchpad (Apps on macOS 26) |
| `desktopLeft` / `desktopRight` | Switch Space (sends ⌃← / ⌃→) |
| `shell:<command>` | Run any shell command, e.g. `"shell:open -a Safari"` |
| `none` | Do nothing |

`threshold` is how far (in pixels) you must move before a hold counts as a gesture. Button numbers are as macOS reports them: `3` = back, `4` = forward.

## Troubleshooting

- **Log:** `~/.local/share/mouse-buttons/mousebuttons.log` records every click/gesture with the distance measured.
- **Desktop switching does nothing:** you need at least two desktops, and "Move left/right a space" enabled under System Settings → Keyboard → Keyboard Shortcuts → Mission Control.
- **Logi Options+ (or similar):** leave the side buttons on their default Back/Forward. If the vendor app remaps them, this helper never sees the buttons.

## Uninstall

```bash
bash ~/.local/share/mouse-buttons/uninstall.sh
```
