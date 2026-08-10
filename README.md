# dotfiles

Shell configuration and a lightweight Arch Linux desktop built around i3.

## Installation on an existing system

```bash
git clone https://github.com/zielo-it/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The installer creates symbolic links. If a target file already exists, it is
preserved with a `.backup.YYYYMMDD-HHMMSS` suffix.

## Arch Linux packages

```bash
sudo pacman -S --needed - < packages/arch.txt
```

The list contains only packages from the official repositories.

## Random wallpapers

The i3 session uses `feh` to select a random image at login and every 30
minutes. `Mod+Shift+w` selects the next image immediately. The default
collection is [Rosé Pine Wallpapers](https://github.com/rose-pine/wallpapers),
using its matching illustrations, generative art, and Arch/Arch BTW variants.
The repository is CC0-1.0; its optional photography section documents its
separate CC BY-SA 4.0 attribution requirements upstream.

Download the collection once after installing the dotfiles:

```bash
~/.local/bin/wallpaper sync
~/.local/bin/wallpaper next
```

Images stay outside this repository in
`~/.local/share/wallpapers/rose-pine`. Change the repository, directory,
rotation interval, or fit mode in `wallpaper/config`. Setting
`WALLPAPER_INTERVAL=0` keeps random selection at login and through the
keyboard shortcut, but disables timed rotation. `~/.local/bin/wallpaper sync`
also performs a safe fast-forward update when the collection is already
present. The `WALLPAPER_SOURCES` list can opt additional folders such as
`anime`, `minecraft`, or `photography` into the rotation. Restart i3 with
`Mod+Shift+r` after changing rotation settings to replace the watcher at once.

## Keyboard layout

Set the Polish programmer's layout as the system default for both the Linux
console and Xorg:

```bash
sudo localectl set-keymap pl2
```

This also ensures that Xorg keeps the Polish layout when a keyboard is
reconnected or udev is reloaded. The i3 configuration reapplies the matching
XKB layout (`pl`) whenever i3 starts or reloads.

## Dark mode

The i3 session publishes a dark system preference through GSettings, the
desktop portal, and XSettings. GTK applications use Adwaita Dark with
Papirus Dark icons, while Qt applications inherit the same palette through
Qt's GTK platform theme.

Log out and back in once after the first installation so the whole session,
including Qt applications, receives the theme environment. Applications that
were already running may need to be restarted.

## Touchpad input

Install the Xorg input rules once:

```bash
sudo install -Dm644 system/xorg/90-natural-scrolling.conf /etc/X11/xorg.conf.d/90-natural-scrolling.conf
sudo install -Dm644 system/xorg/91-touchpad-tapping.conf /etc/X11/xorg.conf.d/91-touchpad-tapping.conf
```

They enable natural scrolling and tap-to-click. One-, two-, and three-finger
taps map to left, right, and middle click. The rules are loaded automatically
at the next login.

## Touchpad gestures

Touchégg handles multi-touch gestures in the X11 session. Enable its system
service once after installing the Arch Linux packages:

```bash
sudo systemctl enable --now touchegg.service
```

Log out and back in to start the Touchégg client through i3. The configured
gestures operate on the currently focused display:

- Three-finger swipe left: next workspace
- Three-finger swipe right: previous workspace

## Key i3 shortcuts

| Shortcut | Action |
| --- | --- |
| `Mod+Enter` | Alacritty terminal |
| `Mod+d` | Rofi launcher |
| `Mod+e` | Thunar file manager |
| `Mod+w` | Firefox |
| `Mod+Shift+w` | next random wallpaper |
| `Mod+Shift+x` | lock the screen |
| `Print` | interactive screenshot |
| `Mod+Shift+r` | restart i3 |
| `Mod+Shift+e` | end the session |

`Mod` refers to the Super/Windows key.
