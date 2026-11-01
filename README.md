# Twilight

A Windows 11-style desktop for Hyprland: top bar with a centred clock, CPU/RAM
rings, a calendar, quick settings and notifications; a centred taskbar that
moves out of the way of windows; a Start menu; a Settings app; a lock screen with
fingerprint unlock; a screenshot tool with an editor; Task View; display settings.
Built on [Quickshell](https://quickshell.org). It runs as its own Hyprland
session and can sit next to KDE Plasma or any other desktop.

## Requirements

* Hyprland 0.56 or newer (the config uses Hyprland's Lua format)
* Quickshell 0.3 or newer
* Arch / CachyOS packages:

```sh
sudo pacman -S --needed hyprland quickshell hyprlock hypridle hyprpolkitagent \
  grim slurp wl-clipboard imagemagick brightnessctl playerctl wireplumber nwg-displays \
  konsole dolphin python fish fprintd wf-recorder inter-font ttf-jetbrains-mono-nerd
```

* Optional: the **ColorFlow** icon theme from the KDE Store, installed to
  `~/.local/share/icons/ColorFlow.Agresive.Color`. With it, Dolphin and Discover
  icons are recoloured to match.

## Install

```sh
git clone <this repo> twilight-desktop
cd twilight-desktop
./install.sh
```

The installer only writes inside your home folder. It does not use sudo. If you
already have `~/.config/hypr` or `~/.config/quickshell/twilight`, it renames
them to `*.bak-<date>` first. Then log out, choose **Hyprland** on the login
screen and sign in. A "Get started" guide opens on the first login.

## Window buttons (optional)

The amber, green and red window buttons come from the official
[hyprbars](https://github.com/hyprwm/hyprland-plugins) plugin. Build it for
your Hyprland version:

```sh
git clone https://github.com/hyprwm/hyprland-plugins ~/.local/src/hyprland-plugins
cd ~/.local/src/hyprland-plugins
git checkout <tag or commit matching your Hyprland version>
git apply /path/to/twilight-desktop/extras/hyprbars-hover-icons.patch   # optional: icon only on the hovered button
make -C hyprbars all
install -Dm755 hyprbars/hyprbars.so ~/.local/lib/hyprland/hyprbars.so
```

Without the plugin, Twilight still works. Windows just have no title bar.

## Zen Browser theme (optional)

Copy `extras/zen/userChrome.css` and `userContent.css` into the `chrome/`
folder of your Zen profile, and `user.js` into the profile folder itself.

## Notes

* Laptop panels are assumed to be named `eDP-*`. Use Settings → Display (or
  `Super + P`) for external screens.
* Keyboard shortcuts, recovery steps and file locations are in
  `~/.config/hypr/README.md` after install.
* The default wallpaper is a public-domain photo of Denali (US National Park
  Service). Add your own in Settings → Personalisation.

## Uninstall

Delete `~/.config/hypr`, `~/.config/quickshell/twilight`, `~/.config/twilight`
and `~/.local/share/twilight`, then rename any `*.bak-<date>` folders back.

## For maintainers

`./export.sh` refreshes this repo from a live install. It leaves out personal
settings and replaces home paths with placeholders.

## Licence

MIT (see `LICENSE`). The hyprbars patch in `extras/` follows the hyprland-plugins licence (BSD-3-Clause). The Denali wallpaper is public domain.
