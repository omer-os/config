source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
set -gx WEBKIT_DISABLE_DMABUF_RENDERER 1

set -gx ANDROID_HOME $HOME/Android/Sdk

set -gx NDK_HOME $ANDROID_HOME/ndk/30.0.14904198
set -gx PATH $ANDROID_HOME/platform-tools $PATH
set -gx JAVA_HOME /usr/lib/jvm/java-21-openjdk
