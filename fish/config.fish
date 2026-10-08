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
set -g fish_key_bindings fish_vi_key_bindings

function fish_user_key_bindings
    # Word deletion, like every other text field
    bind -M insert ctrl-backspace backward-kill-word
    bind -M insert alt-backspace backward-kill-word
    bind -M insert ctrl-delete kill-word
    bind -M insert alt-delete kill-word

    # Tab takes the grey autosuggestion when one is showing, otherwise completes.
    # Right arrow / ctrl-f still accept it too; ctrl-space opens the completion menu.
    bind -M insert tab 'if commandline --showing-suggestion; commandline -f accept-autosuggestion; else; commandline -f complete; end'
    bind -M insert ctrl-space complete
    bind -M insert ctrl-f accept-autosuggestion
    bind -M insert ctrl-e end-of-line

    # CachyOS binds ! and $ in the default map, which in vi mode is normal
    # mode and breaks the `$` end-of-line motion. Keep them in insert only.
    bind --erase ! '$'
    bind -M insert ! __history_previous_command
    bind -M insert '$' __history_previous_command_arguments

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

# Zen mode (hypr/scripts/zen.sh) only makes the kitty windows that were already
# open solid. A kitty opened while zen is on would come up at kitty.conf's 0.55
# opacity with no blur behind it, so it looks see-through; make it solid too.
if status is-interactive; and set -q KITTY_PID; and test -e "$XDG_RUNTIME_DIR/hypr-zen"
    kitty @ --to "unix:@kitty-$KITTY_PID" set-background-opacity --all 1 >/dev/null 2>&1
end
