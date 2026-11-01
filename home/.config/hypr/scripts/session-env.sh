#!/bin/sh
# Shares the Hyprland session's environment with D-Bus/systemd-activated
# services (portals, polkit agent) and removes it again on exit, so nothing
# Hyprland-specific is left behind for a later KDE login.
#
#   session-env.sh import   - called once when Hyprland starts
#   session-env.sh clear    - called when Hyprland shuts down

VARS="WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP HYPRLAND_INSTANCE_SIGNATURE DCONF_PROFILE"

case "$1" in
import)
    dbus-update-activation-environment --systemd $VARS
    ;;
clear)
    systemctl --user stop --no-block hyprpolkitagent.service xdg-desktop-portal-hyprland.service 2>/dev/null
    # shellcheck disable=SC2086
    systemctl --user unset-environment $VARS
    # The D-Bus activation environment cannot unset, only overwrite: point
    # DCONF_PROFILE at a profile identical to dconf's built-in default.
    dbus-update-activation-environment DCONF_PROFILE="$HOME/.config/hypr/dconf/default-profile"
    ;;
*)
    echo "usage: $0 import|clear" >&2
    exit 2
    ;;
esac
