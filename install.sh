#!/usr/bin/env bash
# Install the Twilight Hyprland desktop into your home folder.
# User files only: no sudo, no system files, no display-manager, PAM or boot changes.
set -euo pipefail
repo=$(cd "$(dirname "$0")" && pwd)
stamp=$(date +%Y%m%d-%H%M%S)

need=(Hyprland qs hyprlock hypridle grim slurp wl-copy magick brightnessctl
      playerctl wpctl busctl nwg-displays konsole dolphin python3 fish)
missing=()
for c in "${need[@]}"; do command -v "$c" >/dev/null || missing+=("$c"); done
if ((${#missing[@]})); then
    echo "Missing programs: ${missing[*]}"
    echo "Arch/CachyOS: sudo pacman -S --needed hyprland quickshell hyprlock hypridle hyprpolkitagent \\"
    echo "  grim slurp wl-clipboard imagemagick brightnessctl playerctl wireplumber nwg-displays \\"
    echo "  konsole dolphin python fish fprintd wf-recorder inter-font ttf-jetbrains-mono-nerd"
    read -rp "Install Twilight anyway? [y/N] " a; [[ $a == [yY] ]] || exit 1
fi
v=$(Hyprland --version 2>/dev/null | grep -oE '^Hyprland [0-9]+\.[0-9]+' | cut -d' ' -f2 || true)
if [[ -n $v ]] && (( ${v#*.} < 56 && ${v%%.*} == 0 )); then
    echo "Hyprland $v found; Twilight needs 0.56 or newer (Lua config)."; exit 1
fi

# Existing configs are moved aside, never deleted.
for d in .config/hypr .config/quickshell/twilight; do
    if [[ -e $HOME/$d ]]; then
        mv "$HOME/$d" "$HOME/$d.bak-$stamp"
        echo "Moved your old ~/$d to ~/$d.bak-$stamp"
    fi
done

cp -r "$repo/home/." "$HOME/"
grep -rlI -e @HOME@ -e @USER@ "$HOME/.config/hypr" "$HOME/.local/share/applications" \
    | xargs -r sed -i -e "s#@HOME@#$HOME#g" -e "s#@USER@#$USER#g"
command -v claude >/dev/null || rm -f "$HOME/.local/share/applications/twilight-claude.desktop"
chmod +x "$HOME"/.config/hypr/scripts/*.sh
ln -sfn "$HOME/.local/share/twilight/wallpapers/denali-wonder-lake.jpg" "$HOME/.local/share/twilight/wallpaper.jpg"

# Dolphin/Discover icons in the Twilight colours (needs the ColorFlow icon theme).
if [[ -d $HOME/.local/share/icons/ColorFlow.Agresive.Color ]]; then
    python3 -I "$HOME/.config/hypr/scripts/recolor-icons.py"
else
    echo "Optional: install the 'ColorFlow' icon theme from the KDE Store for the matching icons."
fi

cat <<MSG

Twilight installed. Log out, choose "Hyprland" on the login screen and sign in.
Window buttons (dots) need the hyprbars plugin: see README.md, section "Window buttons".
To remove: delete ~/.config/hypr and ~/.config/quickshell/twilight, then rename the .bak-$stamp folders back.
MSG
