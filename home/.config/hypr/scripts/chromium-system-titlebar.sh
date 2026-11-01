#!/bin/sh
# Make Chromium-based browsers (Opera GX, Chrome) use the system title bar,
# i.e. the Twilight window bar, instead of drawing their own buttons — their
# own title bar doesn't drag or maximise reliably under Hyprland.
# Chromium rewrites Preferences on exit, so this only edits a browser that
# isn't running (it runs at login, before you open them).
for app in com.opera.opera-gx com.google.Chrome; do
    flatpak ps --columns=application 2>/dev/null | grep -qx "$app" && continue
    for prefs in "$HOME/.var/app/$app"/config/*/Default/Preferences; do
        [ -f "$prefs" ] || continue
        python3 -I - "$prefs" <<'EOF'
import json, os, sys
p = sys.argv[1]
d = json.load(open(p))
if d.setdefault("browser", {}).get("custom_chrome_frame") is not False:
    d["browser"]["custom_chrome_frame"] = False
    tmp = p + ".twilight-tmp"
    json.dump(d, open(tmp, "w"), separators=(",", ":"))
    os.replace(tmp, p)
EOF
    done
done
