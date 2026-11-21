# Omarchy Theme Toggler

A sun/moon widget for the Omarchy bar that switches between a light theme and
a dark theme.

- **Left-click** the bar icon to flip between your light and dark themes.
- **Right-click** it to choose the theme and background for each side, and to
  edit your own pre/post hooks.

The plugin does not invent light or dark themes. It remembers which Omarchy
theme to use for each side and applies it with `omarchy theme set`, so the rest
of your desktop changes exactly the way it does from the command line.

## What you can configure

| Setting | Meaning |
| --- | --- |
| Light theme | Omarchy theme used when switching to light mode. |
| Dark theme | Omarchy theme used when switching to dark mode. |
| Light background | Optional image/video used after applying the light theme. Empty means the theme's own default background. |
| Dark background | The same, for dark mode. |
| Mode | The last side you switched to. Used only while the current theme matches neither of your two choices. |

Light and dark are independent. You can use `Catppuccin Latte` and
`Catppuccin`, `Flexoki Light` and `Flexoki`, `White` and `Tokyo Night`, or any
themes you have installed.

The first time the plugin runs it proposes `Catppuccin Latte` for light and
`Catppuccin` for dark when those themes exist. Change either one from the
right-click panel.

## Requirements

- Omarchy with the Quickshell bar (the version that supports `omarchy plugin`).
- `bash`, `jq`, and `timeout` (already present on Omarchy).
- At least two installed themes for a meaningful toggle. See `omarchy theme
  list`.

## Install

The normal install is through Omarchy's plugin command:

```bash
omarchy plugin add https://github.com/lay-z/omarchy-theme-toggler.git --enable
```

`--enable` puts the widget on the bar. If you omit it, enable the widget
afterwards:

```bash
omarchy plugin enable io.github.lay-z.theme-toggler --section right
```

If you want it somewhere specific in the bar:

```bash
omarchy bar move io.github.lay-z.theme-toggler --section right --before layz.power
```

The plugin id is `io.github.lay-z.theme-toggler`. It is also the IPC target.

> **A note on trust:** Omarchy shell plugins run as unsandboxed code inside the
> long-lived `omarchy-shell` process. Install plugins you have reviewed, the
> same way you would install any other package.

## Use

1. Click the new sun/moon icon on the bar.
2. The first click switches to the other side. For example, if you are on the
   dark theme, it switches to the light theme.
3. Right-click the icon to open the settings panel.

The panel has two sections, **Light mode** and **Dark mode**. Pick a theme in
each one. The background dropdown lists the backgrounds available for the
selected theme:

- `~/.config/omarchy/backgrounds/<theme>/`
- the theme's own `backgrounds/` directory
- for an overlay theme, the stock theme's `backgrounds/` directory

`Theme default` means "let `omarchy theme set` pick a background", exactly as
it does when you change themes manually. You can also type any image or video
path in the field below the dropdown.

Settings are saved in the widget's entry in `~/.config/omarchy/shell.json`.
That file hot-reloads, so edits made by hand apply immediately too.

Example entry:

```json
{
  "bar": {
    "layout": {
      "right": [
        {
          "id": "io.github.lay-z.theme-toggler",
          "lightTheme": "catppuccin-latte",
          "darkTheme": "catppuccin",
          "lightBackground": "/home/you/Pictures/wall-light.png",
          "darkBackground": "/usr/share/omarchy/themes/catppuccin/backgrounds/1-totoro.webp",
          "mode": "dark"
        }
      ]
    }
  }
}
```

### How the current side is detected

After every switch the plugin records the side it applied. On startup it also
reads `~/.local/state/omarchy/current/theme.name`:

1. If the current theme equals your light theme, the icon shows the light side.
2. If it equals your dark theme, it shows the dark side.
3. Otherwise it uses the last recorded side, falling back to dark.

That means changing themes outside the plugin, or installing a theme that is
neither side, never makes the widget unusable. Select the new theme in the
panel and it becomes one of the two sides.

## Pre/post hooks

Two scripts let you run your own code around a switch. They are created for you
on first load:

```text
~/.config/omarchy/theme-toggler/pre-toggle.sh
~/.config/omarchy/theme-toggler/post-toggle.sh
```

Both are ordinary bash scripts, so they can be as long as you need and can call
any command you like. The **Edit pre-toggle hook** and **Edit post-toggle hook**
buttons in the panel open them in your configured editor.

- The **pre** hook runs before `omarchy theme set`. If it exits non-zero, the
  switch is cancelled and the theme is left alone.
- The **post** hook runs after the theme and background are applied. If it
  fails, the switch stays and you get a notification; it cannot roll the theme
  back.
- Each hook gets 120 seconds by default. Override with
  `OMARCHY_THEME_TOGGLER_HOOK_TIMEOUT` (seconds) if you need longer.
- Hooks run with `bash` from your home directory.
- Output from hooks, `omarchy theme set`, and `omarchy theme bg set` goes to
  `~/.local/state/omarchy/theme-toggler.log`.

### Arguments

```text
$1  target mode: light or dark
$2  target theme slug, for example catppuccin
$3  target background path, or empty for the theme's default
$4  previous theme slug
```

### Environment

```text
OMARCHY_THEME_TOGGLER_MODE
OMARCHY_THEME_TOGGLER_THEME
OMARCHY_THEME_TOGGLER_BACKGROUND
OMARCHY_THEME_TOGGLER_PREVIOUS_THEME
OMARCHY_THEME_TOGGLER_PLUGIN_DIR
```

### Example post hook

Replace the placeholder command with the reload step your application provides:

```bash
#!/usr/bin/env bash
set -euo pipefail

if command -v my-app >/dev/null 2>&1; then
  my-app reload-theme 2>/dev/null || true
fi
```

### Example pre hook

A pre hook can use the target mode to do different work for each side:

```bash
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  light)
    # Runs only when switching to the light theme.
    ;;
  dark)
    # Runs only when switching to the dark theme.
    ;;
esac
```

A pre hook that exits non-zero cancels the switch:

```bash
if some-check-that-must-pass; then
  exit 0
fi
echo "Not switching right now" >&2
exit 1
```

If you want no hooks, leave the files as generated (they contain only comments)
or delete them.

## Keybinding and IPC

The widget has an IPC target, so you can bind the toggle to a key without
clicking the bar. Add this to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + T", "Toggle light/dark theme",
  "omarchy-shell io.github.lay-z.theme-toggler toggle")
```

Other IPC methods:

```bash
omarchy-shell io.github.lay-z.theme-toggler toggle        # switch sides
omarchy-shell io.github.lay-z.theme-toggler open          # open settings panel
omarchy-shell io.github.lay-z.theme-toggler refresh       # reload themes and state
omarchy-shell io.github.lay-z.theme-toggler state         # JSON: mode, theme, background
```

`togglePanel` opens the panel as well; `toggle` always means "toggle the
theme".

## Troubleshooting

**The widget does not appear**

```bash
omarchy plugin list | grep theme-toggler
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.lay-z.theme-toggler --section right
```

**A theme does not change**

Check that the slug exists and try it manually:

```bash
omarchy theme list
omarchy theme current
omarchy theme set catppuccin-latte
```

Then look at the plugin log:

```bash
tail -50 ~/.local/state/omarchy/theme-toggler.log
```

Shell errors are in the journal:

```bash
journalctl --user -t omarchy-shell -n 100 --no-pager | grep -i theme-toggler
```

**The background does not change**

The theme is applied first, then `omarchy theme bg set <path>`. Confirm the file
exists and is one of the formats Omarchy accepts (jpg, jpeg, png, gif, bmp,
webp, mp4, m4v, mov, webm, mkv, avi). A missing file leaves the theme's own
background in place and writes a notification.

**I want to start over**

Remove the plugin's settings from its `shell.json` entry, leaving just `id`, or
delete the entry. The panel writes the settings again as you use it. Hooks are
plain files under `~/.config/omarchy/theme-toggler/`.

## Uninstall

```bash
omarchy plugin remove io.github.lay-z.theme-toggler --yes
rm -rf ~/.config/omarchy/theme-toggler   # optional: remove your hooks
rm -f ~/.local/state/omarchy/theme-toggler.log
```

## Development

```bash
git clone https://github.com/lay-z/omarchy-theme-toggler.git \
  ~/Code/omarchy/omarchy-theme-toggler

cd ~/Code/omarchy/omarchy-theme-toggler
node --test tests/Model.test.js
omarchy plugin validate .
```

To run the working tree inside the shell, link it into the plugin directory:

```bash
ln -s ~/Code/omarchy/omarchy-theme-toggler \
  ~/.config/omarchy/plugins/io.github.lay-z.theme-toggler
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.lay-z.theme-toggler --section right
```

If a QML change is not picked up, restart the shell (`omarchy restart shell`);
Quickshell caches components by URL.

## License

MIT. See [LICENSE](LICENSE).
