#!/usr/bin/env bash
# Refresh this repo from the live Twilight install in $HOME.
# Personal data (settings, pins, avatar, display layout, generated files,
# the private rocket painting) is left out; paths become @HOME@ / @USER@.
set -euo pipefail
repo=$(cd "$(dirname "$0")" && pwd)
H=$HOME
rm -rf "$repo/home" "$repo/extras"
mkdir -p "$repo/home/.config/hypr/scripts" "$repo/home/.config/quickshell" \
         "$repo/home/.local/share/twilight/wallpapers" "$repo/home/.local/share/konsole" \
         "$repo/home/.local/share/applications" "$repo/home/.local/share/icons/hicolor/scalable/apps" \
         "$repo/extras/zen"

cp "$H/.config/hypr/"{hyprland.lua,hyprlock.conf,README.md} "$repo/home/.config/hypr/"
cp -r "$H/.config/hypr/"{kitty,dconf} "$repo/home/.config/hypr/"
for s in session-env.sh record.sh xdg-autostart.sh claude.sh chromium-system-titlebar.sh recolor-icons.py; do
    cp "$H/.config/hypr/scripts/$s" "$repo/home/.config/hypr/scripts/"
done
cp -r "$H/.config/quickshell/twilight" "$repo/home/.config/quickshell/"
cp "$H/.local/share/twilight/wallpapers/denali-wonder-lake.jpg" "$repo/home/.local/share/twilight/wallpapers/"
cp "$H/.local/share/konsole/"Twilight.{profile,colorscheme} "$repo/home/.local/share/konsole/"
cp "$H/.local/share/applications/"twilight-{settings,terminal,claude}.desktop "$repo/home/.local/share/applications/"
cp "$H/.local/share/icons/hicolor/scalable/apps/twilight-claude.svg" "$repo/home/.local/share/icons/hicolor/scalable/apps/"

zen=$(ls -d "$H"/.var/app/app.zen_browser.zen/.zen/*/chrome 2>/dev/null | head -1 || true)
[ -n "$zen" ] && cp "$zen/"{userChrome.css,userContent.css} "$zen/../user.js" "$repo/extras/zen/"
git -C "$H/.local/src/hyprland-plugins" diff > "$repo/extras/hyprbars-hover-icons.patch"

# Ship the public-domain photo as the default wallpaper.
sed -i 's#wallpapers/rocket-launch.jpg#wallpapers/denali-wonder-lake.jpg#' "$repo/home/.config/quickshell/twilight/Config.qml"
grep -rlI -e "$H" -e "icons/$USER\b" "$repo/home" | xargs -r sed -i -e "s#$H#@HOME@#g" -e "s#icons/$USER\$#icons/@USER@#"
if grep -rnI -e "$H" -e "$USER" "$repo/home" "$repo/extras"; then echo "personal data left above" >&2; exit 1; fi
echo "exported to $repo"
