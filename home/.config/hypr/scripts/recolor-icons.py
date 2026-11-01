#!/usr/bin/env python3
"""Build the small "ColorFlow-Twilight" icon theme.

It contains only the icons listed in ICONS, recoloured to the Twilight
"Launch" palette's warm accent (ember / amber), and inherits every other
icon from your KDE theme unchanged. The source theme is never modified.

    recolor-icons.py [SOURCE_THEME_DIR] [DEST_THEME_DIR]
"""
import colorsys
import os
import re
import shutil
import sys

HOME = os.path.expanduser("~")
SRC = os.path.join(HOME, ".local/share/icons/ColorFlow.Agresive.Color")
DST = os.path.join(HOME, ".local/share/icons/ColorFlow-Twilight")

# Real icon file -> icon names that point at it (Dolphin, Discover).
ICONS = {
    "apps/scalable/file-manager.svg": ["org.kde.dolphin", "system-file-manager"],
    "apps/scalable/gnome-software.svg": ["org.kde.discover", "plasmadiscover"],
}

WARM_HUES = [15, 37]   # ember, amber (degrees)
MIN_SAT = 0.22         # below this a colour counts as grey

HEX = re.compile(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b')


def hue_dist(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def recolor_hex(m):
    v = m.group(1)
    if len(v) == 3:
        v = ''.join(c * 2 for c in v)
    r, g, b = (int(v[i:i + 2], 16) / 255 for i in (0, 2, 4))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if l < 0.06 or l > 0.96:
        return m.group(0)                          # black / white untouched
    if s < MIN_SAT:
        if not 0.2 <= l <= 0.8:
            return m.group(0)                      # very dark/light greys stay
        # grey body -> warm, lifted so dark greys don't turn brown
        h, s, l = 25 / 360, 0.65, 0.35 + l * 0.5
    else:
        h = min(WARM_HUES, key=lambda t: hue_dist(h * 360, t)) / 360
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return '#%02x%02x%02x' % (round(r * 255), round(g * 255), round(b * 255))


def recolor_svg(text):
    return HEX.sub(recolor_hex, text)


INDEX = """[Icon Theme]
Name=ColorFlow Twilight
Comment=Your ColorFlow icons, with Dolphin and Discover in the Twilight colours
Inherits={src},breeze-dark,breeze
Directories=apps/scalable

[apps/scalable]
Size=48
MinSize=8
MaxSize=512
Type=Scalable
Context=Applications
"""


def build(src, dst):
    if os.path.abspath(src) == os.path.abspath(dst):
        sys.exit("refusing to overwrite the source theme")
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    for rel, names in ICONS.items():
        with open(os.path.join(src, rel), encoding='utf-8', errors='surrogateescape') as fh:
            text = recolor_svg(fh.read())
        out = os.path.join(dst, rel)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, 'w', encoding='utf-8', errors='surrogateescape') as fh:
            fh.write(text)
        for n in names:
            os.symlink(os.path.basename(rel), os.path.join(os.path.dirname(out), n + '.svg'))
    with open(os.path.join(dst, 'index.theme'), 'w', encoding='utf-8') as fh:
        fh.write(INDEX.format(src=os.path.basename(src)))


if __name__ == '__main__':
    # Self-check: black/white stay; a saturated blue becomes a warm hue.
    assert recolor_svg('#000000') == '#000000' and recolor_svg('#ffffff') == '#ffffff'
    h = colorsys.rgb_to_hls(*(int(recolor_svg('#3daee9')[i:i + 2], 16) / 255 for i in (1, 3, 5)))[0] * 360
    assert min(hue_dist(h, t) for t in WARM_HUES) < 2, h
    build(sys.argv[1] if len(sys.argv) > 1 else SRC, sys.argv[2] if len(sys.argv) > 2 else DST)
