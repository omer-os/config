source /usr/share/cachyos-fish-config/cachyos-config.fish

# Overwrite the CachyOS greeting, which runs fastfetch on every new shell.
function fish_greeting
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
set -gx WEBKIT_DISABLE_DMABUF_RENDERER 1

set -g fish_cursor_default block
set -g fish_cursor_insert line
set -g fish_cursor_visual block
set -g fish_cursor_replace_one underscore
function fish_user_key_bindings
    fish_vi_key_bindings
    bind -M insert ctrl-v fish_clipboard_paste
    bind -M default p fish_clipboard_paste
    bind -M default P fish_clipboard_paste
    bind -M default y fish_clipboard_copy
    bind -M visual y 'fish_clipboard_copy; commandline -f end-selection repeat-jump-reverse force-repaint'
end
set -gx ANDROID_HOME $HOME/Android/Sdk

set -gx NDK_HOME $ANDROID_HOME/ndk/30.0.14904198
set -gx PATH $ANDROID_HOME/platform-tools $PATH
set -gx JAVA_HOME /usr/lib/jvm/java-21-openjdk

# Flutter web: chrome is packaged as google-chrome-stable here
set -gx CHROME_EXECUTABLE /usr/bin/google-chrome-stable

# Reattach the Waydroid emulator to adb. Android Studio restarts the adb server
# often enough that the network device drops off; this puts it back.
abbr -a wda '~/.config/hypr/scripts/waydroid.sh adb'
fish_vi_key_bindings
