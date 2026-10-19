source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end


# Added by Antigravity CLI installer
set -gx PATH "/home/bountis/.local/bin" $PATH
set -gx PATH "$HOME/.cargo/bin" $PATH

# Android SDK Environment
set -gx ANDROID_HOME "$HOME/Android/Sdk"
set -gx ANDROID_SDK_ROOT "$HOME/Android/Sdk"
set -gx NDK_HOME "$ANDROID_HOME/ndk/27.2.12479018"
set -gx ANDROID_NDK_HOME "$NDK_HOME"
set -gx PATH "$ANDROID_HOME/cmdline-tools/latest/bin" "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/emulator" $PATH

# Flatpak exports for desktop entries and icons
set -q XDG_DATA_DIRS; or set -gx XDG_DATA_DIRS "$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$HOME/.local/share:/usr/local/share:/usr/share"
if not string match -q "*flatpak/exports/share*" "$XDG_DATA_DIRS"
    set -gx XDG_DATA_DIRS "$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:$XDG_DATA_DIRS"
end
set -gx PATH "$HOME/.local/go/bin" $PATH
