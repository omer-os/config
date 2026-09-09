# config

Personal `~/.config` dotfiles.

## Included

| Config | What |
| --- | --- |
| `waybar` | Status bar (terminal green, Hyprland workspaces, privacy indicator) |
| `hypr` | Hyprland window manager, lock screen (`hyprlock`), blue-light filter (`hyprsunset`) |
| `swaync` | Notification centre |
| `wlogout` | Power menu (Lock wired to `hyprlock`) |
| `swayosd` | On-screen volume / brightness / caps-lock indicator |
| `kitty` | Terminal |
| `cava` | Audio visualizer |
| `btop` | System monitor |
| `gtk-3.0` | GTK theme settings |
| `nwg-displays` | Display configuration |
| `fish` | Fish shell |
| `nvim` | Neovim |
| `zed` | Zed editor |
| `micro` | Micro editor |
| `lazygit` | Lazygit |

## Install

Clone into `~/.config` (or symlink the folders you want):

```sh
git clone git@github.com:omer-os/config.git ~/.config-repo
# then copy/symlink the dirs you want, e.g.:
ln -s ~/.config-repo/waybar ~/.config/waybar
```

Only the configs listed above are tracked — see `.gitignore` for the whitelist.
