# Twilight — Hyprland desktop next to KDE Plasma

Twilight is a separate Hyprland session. KDE Plasma is untouched: no KDE file,
login-manager setting, PAM file, bootloader or kernel parameter was changed.

## Where everything lives

| Path | What |
|---|---|
| `~/.config/hypr/hyprland.lua` | Hyprland config (Lua, Hyprland ≥ 0.56) |
| `~/.config/hypr/monitors.lua` | Display layout saved by **nwg-displays** (created on first Apply) |
| `~/.config/hypr/hyprlock.conf`, `hypridle.conf` | Lock screen, idle/suspend policy |
| `~/.config/hypr/scripts/` | Screenshot, screen recording, session environment |
| `~/.config/hypr/dconf/` | Private dconf profile — GTK theme/dark mode for this session only |
| `~/.config/dconf/twilight` | The private dconf database (KDE uses `~/.config/dconf/user`) |
| `~/.config/hypr/kitty/` | Terminal theme used only in this session |
| `~/.config/quickshell/twilight/` | The shell: top bar, taskbar, Start menu, panels, notifications |
| `~/.local/share/twilight/wallpapers/` | Wallpapers (rocket painting, Denali photo, any you add) |
| `~/.config/twilight/settings.json` | Everything set in the Settings app |
| `~/.local/state/twilight/apps.json` | Your pins and recently launched apps |

## Logging in and out

* Plasma Login Manager auto-logs you into **Plasma** at boot (unchanged).
* To use Twilight: in Plasma choose *Log Out*, then pick **Hyprland** from the
  session menu on the login screen and sign in.
  (Use "Hyprland", not "Hyprland (uwsm-managed)".)
* To return to KDE: Start → power → *Sign out* (or `Super + X` → Sign out),
  then pick **Plasma (Wayland)** on the login screen.

## Settings app (no config editing needed)

Open **Settings** with `Super + I`, Start → Settings, or the cog in Quick
settings / the Start menu. Changes apply immediately:

| Page | What you can change |
|---|---|
| System | Device and software information |
| Personalisation | Colour theme (Launch = colours of the rocket painting, Twilight, Sky, Ember, Meadow), wallpaper (+ "Add a picture…"), CPU/RAM meters, 24-hour clock, dark mode for apps |
| Taskbar | Dodge maximised windows / always show / auto-hide; pinned apps |
| Windows | Title bars with dots, buttons left or right, gaps, corner radius, blur, animations |
| Display | Brightness, night light and its strength, display arrangement (projectors) |
| Sound | Volume, microphone, output device |
| Network & Bluetooth | Wi-Fi, Bluetooth, airplane mode, pairing |
| Touchpad & keyboard | Natural scrolling, tap to click, pointer speed, keyboard layout |
| Power & battery | Power mode; dim / lock / screen off / sleep timers |
| Notifications | Do not disturb, pop-up duration, clear history |
| Sign-in & fingerprint | Enrol, test or remove fingerprints |

Behind the scenes it writes `~/.config/twilight/settings.json`,
`~/.config/hypr/twilight.lua` and `~/.config/hypr/hypridle.conf` (marked
"generated" - don't edit those by hand).

## Everyday use

| Action | Mouse | Keyboard |
|---|---|---|
| Start menu | Start button (taskbar) or logo (top-left) | tap `Super` |
| Search apps/settings/files | Start → type, or taskbar search | tap `Super`, type, `Enter` |
| Notifications | bell (top-right) | `Super + N` |
| Quick settings | status icons (top-right) | `Super + A` |
| Power menu | power icon (top-right) | `Super + X` |
| Lock | Start → lock | `Super + L` |
| Terminal / Files / Browser | taskbar | `Super + T` / `Super + E` / `Super + B` |
| Copy / paste in the terminal | right-click → Copy / Paste, or the toolbar buttons | `Ctrl + Shift + C` / `Ctrl + Shift + V` |
| Minimise | amber dot on the window, or click the app's taskbar icon while it's focused | `Super + ↓` |
| Restore a minimised window | click its taskbar icon (dim dot = minimised) | |
| Maximise (taskbar hides) | green dot, or double-click the window's title bar | `Super + ↑` |
| Fullscreen | | `Super + F` |
| Float / tile window | | `Super + V` |
| Move / resize window | `Super` + left / right drag; drag window borders | |
| Close window | red dot on the window | `Super + Q` or `Alt + F4` |
| Switch windows | taskbar | `Alt + Tab` |
| Workspaces | click 1-2-3-4 in the top bar, 3-finger swipe | `Super + 1…9`, `Super + Shift + 1…9` moves window |
| Screenshot (area) | Quick settings → Screenshot | `Super + Shift + S` (full screen: `Print`) |
| Screen recording | Quick settings → Record screen | `Super + Shift + R` (again to stop) |
| Restart the shell | | `Super + Ctrl + R` |

Taskbar: hover an app for live window previews (click one to switch, ✕ to
close); right-click to pin/unpin or close; middle-click opens a new window.

Top bar centre: memory ring · date · time · CPU ring. Click the date or time
for a calendar (days / months / years). Click a ring for a
compact monitor (usage, temperature/frequency or memory breakdown, a 2-minute
graph, top 3 apps) with a button that opens `btop`. The focused window's icon
and title sit next to the workspaces.

Start search also works as a calculator: type `12*4.5+3` and press Enter to
copy the result. In the Start menu, right-click an app to pin it to Start or the taskbar.

When a window is maximised or fullscreen the taskbar gets out of the way; rest
the pointer on the bottom screen edge to bring it back.

## Mouse-first extras (for Windows users)

* **Right-click the desktop:** Task View, Show desktop, Open Files, Open
  Terminal, Personalise, Display settings, Settings, Get started.
* **Right-click empty taskbar space:** Task Manager, Task View, Show desktop,
  Taskbar settings.
* **Right-click the Start button:** Windows-style power-user menu (Apps,
  Power, System, Network, Task Manager, Settings, File Explorer, Search,
  Terminal, Get started, Shut down or sign out → the top-bar power menu).
* **Task View:** every window as a live preview plus your desktops; click to go,
  "+ New" adds a desktop. `Win + Tab`.
* **Show desktop:** minimises everything on the current desktop, again to bring
  it back. `Win + D`.
* **Get started guide:** opens on the first login; `Win + F1` or the right-click
  menus any time.
* Task Manager `Ctrl + Shift + Esc` (KDE System Monitor), emoji `Win + .`.

## Window buttons (amber / green / red dots)

Most windows get a slim Twilight title bar with minimise, maximise and close
dots at the top-right (or left — Settings → Windows). This uses the official Hyprland **hyprbars** plugin, built
from source in your home folder (no system package):

```sh
make -C ~/.local/src/hyprland-plugins/hyprbars all
install -Dm755 ~/.local/src/hyprland-plugins/hyprbars/hyprbars.so ~/.local/lib/hyprland/hyprbars.so
```

Then sign out of Hyprland and back in.

* Apps that draw their own buttons (Zen, Firefox, Discord, Chrome, Steam) keep
  theirs and get no extra bar; Zen's are restyled as the same dots.
* Maximised windows keep their bar; true fullscreen hides it.
* **After a Hyprland update** the plugin must match the new version. If it
  doesn't, Hyprland shows a notice and runs without bars (it does not crash).
  Rebuild: `cd ~/.local/src/hyprland-plugins && git fetch && git checkout <tag or
  commit matching your Hyprland>` and run the two commands above.
* Disable: delete `~/.local/lib/hyprland/hyprbars.so`.

## Zen Browser theme

`~/.var/app/app.zen_browser.zen/.zen/karphuv3.Default (release)/chrome/userChrome.css`
(+ `userContent.css`, `user.js`) give Zen the Twilight colours in dark mode and
dot-style window buttons. This is Zen's own profile, so it also applies when
you use Zen in KDE. Remove those three files to return to Zen's default look.

## Windows, terminal, logins

* Windows float and overlap like on Windows; drag the title bar to move, edges
  to resize; they snap to screen edges. A window whose title bar ends up under
  the top bar is moved back down automatically. `Super + V` tiles a window.
* The terminal is Konsole with a Twilight profile (`~/.local/share/konsole/Twilight.*`);
  your KDE Konsole profile is unchanged.
* KWallet is unlocked at login (as in KDE), so saved logins work — e.g.
  GitPilot / git pushes through Git Credential Manager.

## Installing and updating software

* **Discover** (Start → Discover) installs, removes and updates **Flatpak** apps
  from Flathub, and firmware via fwupd. Its update notifier runs in this session.
* Discover does **not** manage pacman packages here (PackageKit is deliberately
  not installed — on Arch it risks partial upgrades). For system packages use
  **Cachy-Update** (Start → search "update") or `sudo pacman -Syu` in a terminal.
* The AUR is not available through Discover.

## Projectors and external displays

* Plug the display in: it is enabled automatically and extends to the right.
* Arrange, mirror, change resolution/refresh/scale: Quick settings → monitor icon
  (or search "Display settings") → **nwg-displays** → *Apply*. It asks to keep
  the change and reverts automatically if you don't confirm.
  * Mirror: select the external display → *Mirror* → `eDP-1`.
  * External only: untick *Active* for `eDP-1`.
* Saved layouts go to `~/.config/hypr/monitors.lua`.
* Safety rules built into `hyprland.lua`:
  * the laptop panel is switched off **only** while the lid is closed **and**
    another display is active;
  * when the external display is unplugged, the laptop panel is always
    re-enabled, even if a saved layout disabled it.
* Lid closed without an external display → suspend (systemd default). With an
  external display connected, logind ignores the lid and the laptop panel turns off.
* If a saved layout ever leaves you with a wrong picture: delete
  `~/.config/hypr/monitors.lua` (from a TTY if necessary) and log in again.

## Fingerprint

* Sensor: ELAN `04f3:0903`, supported by libfprint's `elan` driver.
* Enrol: Settings → Sign-in & fingerprint → Set up (touch the sensor each time
  it asks), then Test. Terminal alternative: `fprintd-enroll`, `fprintd-verify`.
* Twilight's lock screen (hyprlock) accepts the fingerprint **or** your password.
  It talks to fprintd directly; no PAM file was edited.
* Note: `/etc/pam.d/sudo` already contained `pam_fprintd` (added by CachyOS), so
  after enrolling, `sudo` will also offer the fingerprint; KDE's lock screen
  may offer it too. Both still accept the password.
* The login screen itself (Plasma Login Manager) still uses the password.
* Diagnose: `fprintd-list $USER`, `journalctl -b -u fprintd`, and
  `hyprlock` messages in `journalctl --user -b | grep -i fprint`.

## Recovering from problems

* **Shell (bars/menus) frozen or gone:** `Super + Ctrl + R`.
* **Hyprland session unusable:** press `Ctrl + Alt + F3`, log in on the text
  console, then either
  * `mv ~/.config/hypr/monitors.lua ~/monitors.lua.bak` (bad display layout), or
  * restore a backup (below),

  then run `loginctl terminate-user $USER` (ends the broken session and this
  console login) and press `Ctrl + Alt + F1` or `F2` for the login screen,
  where you can pick Plasma or Hyprland.
* **KDE is never affected:** choosing Plasma at the login screen always gives
  you your normal desktop, even if the Hyprland files are broken or deleted.
* **Remove Twilight entirely:** `rm -r ~/.config/hypr ~/.config/quickshell/twilight ~/.config/dconf/twilight ~/.local/share/twilight ~/.local/state/twilight`
  and optionally `sudo pacman -Rns hyprland quickshell hyprlock hypridle hyprpolkitagent hyprsunset xdg-desktop-portal-hyprland nwg-displays`
  (review the list pacman prints before confirming).

## Backups

Create: `tar -C ~ -czf ~/.local/share/twilight/backups/twilight-$(date +%Y%m%d-%H%M).tar.gz .config/hypr .config/quickshell/twilight .config/dconf/twilight .local/state/twilight`

Restore: `tar -C ~ -xzf ~/.local/share/twilight/backups/<file>.tar.gz`
