#!/bin/sh
# Runs your personal autostart entries (~/.config/autostart/*.desktop), the
# same ones KDE starts at login, honouring Hidden=, OnlyShowIn=/NotShowIn=
# and X-GNOME-Autostart-enabled=. System KDE components are not started:
# Twilight has its own equivalents.
dir="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
[ -d "$dir" ] || exit 0
for f in "$dir"/*.desktop; do
    [ -f "$f" ] || continue
    get() { sed -n "s/^$1=//p" "$f" | head -n1; }
    [ "$(get Hidden)" = "true" ] && continue
    [ "$(get X-GNOME-Autostart-enabled)" = "false" ] && continue
    only=$(get OnlyShowIn); not=$(get NotShowIn)
    [ -n "$only" ] && ! printf '%s' "$only" | grep -q 'Hyprland' && continue
    printf '%s' "$not" | grep -q 'Hyprland' && continue
    cmd=$(get Exec | sed 's/ %[fFuUdDnNickvm]//g')
    [ -n "$cmd" ] && setsid sh -c "$cmd" >/dev/null 2>&1 &
done
