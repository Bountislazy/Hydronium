#!/usr/bin/env bash
# ==============================================================================
#  HYDRONIUM - Universal Arch Linux Setup & Restore Script
#  Compatible with Vanilla Arch Linux, CachyOS, EndeavourOS, Manjaro, etc.
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"
CURRENT_USER="$(id -un)"
CURRENT_HOME="$HOME"

# ------------------------------------------------------------------------------
# 1. Dynamic System & XDG Directory Resolution
# ------------------------------------------------------------------------------
XDG_CONFIG_DIR="${XDG_CONFIG_HOME:-$CURRENT_HOME/.config}"
XDG_DATA_DIR="${XDG_DATA_HOME:-$CURRENT_HOME/.local/share}"
XDG_PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$CURRENT_HOME/Pictures")"
WALLPAPER_DEST="$XDG_PICTURES_DIR/Wallpapers/Anime"
SHELL_DEST="$XDG_DATA_DIR/serpantinum"

# Distro Detection
DISTRO_NAME="Arch Linux"
DISTRO_ID="arch"
if [ -f /etc/os-release ]; then
    DISTRO_NAME="$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '\"' || echo "Arch Linux")"
    DISTRO_ID="$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '\"' || echo "arch")"
fi

# AUR Helper Detection
AUR_HELPER=""
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v pacman &>/dev/null; then
    AUR_HELPER="pacman"
fi

# ------------------------------------------------------------------------------
# Banner
# ------------------------------------------------------------------------------
echo -e "\033[1;35m"
cat << "EOF"
  _    _           _                 _                 
 | |  | |         | |               (_)                
 | |__| |_   _  __| |_ __ ___  _ __  _ _   _ _ __ ___  
 |  __  | | | |/ _` | '__/ _ \| '_ \| | | | | '_ ` _ \ 
 | |  | | |_| | (_| | | | (_) | | | | | |_| | | | | | |
 |_|  |_|\__, |\__,_|_|  \___/|_| |_|_|\__,_|_| |_| |_|
          __/ |                                        
         |___/      Universal Desktop Environment & Shell
EOF
echo -e "\033[0m"

echo -e "\033[1;34m[ℹ] Detected OS:\033[0m \033[1;32m$DISTRO_NAME ($DISTRO_ID)\033[0m"
echo -e "\033[1;34m[ℹ] Active User:\033[0m \033[1;32m$CURRENT_USER\033[0m ($CURRENT_HOME)"
echo -e "\033[1;34m[ℹ] Pictures Dir:\033[0m \033[1;32m$XDG_PICTURES_DIR\033[0m"
echo -e "\033[1;34m[ℹ] Package Helper:\033[0m \033[1;32m${AUR_HELPER:-None detected}\033[0m\n"

# ------------------------------------------------------------------------------
# 2. Dependency Verification & Optional Installation
# ------------------------------------------------------------------------------
DEPENDENCIES=(
    "quickshell"
    "niri"
    "alacritty"
    "cava"
    "fastfetch"
    "fish"
    "brightnessctl"
    "playerctl"
)

MISSING_DEPS=()
for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "\033[0;33m[!] The following packages appear missing from your system:\033[0m"
    echo -e "    ${MISSING_DEPS[*]}"
    if [ -n "$AUR_HELPER" ]; then
        read -rp "    Would you like to install them now using $AUR_HELPER? [y/N]: " install_deps
        if [[ "$install_deps" =~ ^[Yy]$ ]]; then
            echo -e "\033[1;34m[*] Installing missing dependencies...\033[0m"
            if [ "$AUR_HELPER" = "pacman" ]; then
                sudo pacman -S --needed "${MISSING_DEPS[@]}"
            else
                "$AUR_HELPER" -S --needed "${MISSING_DEPS[@]}"
            fi
        fi
    else
        echo -e "\033[0;33m[-] Please ensure these dependencies are installed for full functionality.\033[0m"
    fi
else
    echo -e "\033[0;32m[✓] All core dependencies are installed.\033[0m"
fi

# ------------------------------------------------------------------------------
# 3. Ensure Target Directories & Backup Existing Configs
# ------------------------------------------------------------------------------
echo -e "\n\033[1;36m[1/5] Preparing directories and backing up existing configs...\033[0m"
mkdir -p "$XDG_CONFIG_DIR"
mkdir -p "$XDG_DATA_DIR"
mkdir -p "$WALLPAPER_DEST"
mkdir -p "$SHELL_DEST"
mkdir -p "$CURRENT_HOME/.local/bin"

backup_target() {
    local target="$1"
    if [ -e "$target" ]; then
        echo -e "    -> Backing up $(basename "$target") to $(basename "$target").bak_${TIMESTAMP}"
        cp -r "$target" "${target}.bak_${TIMESTAMP}"
    fi
}

backup_target "$XDG_CONFIG_DIR/serpantinum"
backup_target "$XDG_CONFIG_DIR/niri"
backup_target "$SHELL_DEST/src"

# ------------------------------------------------------------------------------
# 4. Deploy Shell Source & Fix Permissions
# ------------------------------------------------------------------------------
echo -e "\n\033[1;36m[2/5] Deploying Hydronium / Serpantinum Shell...\033[0m"
if [ -d "$SCRIPT_DIR/shell/src" ]; then
    cp -r "$SCRIPT_DIR/shell/src" "$SHELL_DEST/"
    find "$SHELL_DEST/src/scripts" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
    chmod +x "$SHELL_DEST/src/scripts/updater.py" 2>/dev/null || true
    echo -e "\033[0;32m[✓] Shell source files deployed to $SHELL_DEST/src\033[0m"
fi

# ------------------------------------------------------------------------------
# 5. Deploy Dotfiles & Automatically Adapt Paths for Any Arch User
# ------------------------------------------------------------------------------
echo -e "\n\033[1;36m[3/5] Restoring Configurations & Adapting Universal Paths...\033[0m"
for config_dir in "$SCRIPT_DIR/config"/*; do
    if [ -d "$config_dir" ]; then
        cfg_name="$(basename "$config_dir")"
        echo -e "    -> Deploying $XDG_CONFIG_DIR/$cfg_name"
        rm -rf "$XDG_CONFIG_DIR/$cfg_name"
        cp -r "$config_dir" "$XDG_CONFIG_DIR/"
    fi
done

# Patch settings.json to adapt to any username and any XDG Pictures locale
SETTINGS_FILE="$XDG_CONFIG_DIR/serpantinum/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    echo -e "    -> Patching $SETTINGS_FILE for user '$CURRENT_USER'..."
    # Replace any hardcoded wallpaper / avatar path with the active user's actual Pictures dir
    sed -i -E "s|\"[^\"]*/Gambar/Wallpapers/Anime/dandadan.jpg\"|\"$WALLPAPER_DEST/dandadan.jpg\"|g" "$SETTINGS_FILE"
    sed -i -E "s|\"[^\"]*/Pictures/Wallpapers/Anime/dandadan.jpg\"|\"$WALLPAPER_DEST/dandadan.jpg\"|g" "$SETTINGS_FILE"
    sed -i -E "s|\"[^\"]*/Gambar/Wallpapers\"|\"$XDG_PICTURES_DIR/Wallpapers\"|g" "$SETTINGS_FILE"
    sed -i -E "s|\"[^\"]*/Pictures/Wallpapers\"|\"$XDG_PICTURES_DIR/Wallpapers\"|g" "$SETTINGS_FILE"
    sed -i -E "s|/home/[^/\"]+|$CURRENT_HOME|g" "$SETTINGS_FILE"
fi

# Patch fish config if present
if [ -f "$XDG_CONFIG_DIR/fish/config.fish" ]; then
    sed -i -E "s|/home/[^/\"]+|$CURRENT_HOME|g" "$XDG_CONFIG_DIR/fish/config.fish"
fi

echo -e "\033[0;32m[✓] Configuration deployed and paths adapted to $CURRENT_HOME.\033[0m"

# ------------------------------------------------------------------------------
# 6. Deploy Wallpapers & Assets
# ------------------------------------------------------------------------------
echo -e "\n\033[1;36m[4/5] Deploying Wallpapers & Assets...\033[0m"
if [ -d "$SCRIPT_DIR/wallpapers" ]; then
    cp -r "$SCRIPT_DIR/wallpapers"/* "$WALLPAPER_DEST/" 2>/dev/null || true
    echo -e "\033[0;32m[✓] Wallpapers deployed to $WALLPAPER_DEST\033[0m"
fi

# ------------------------------------------------------------------------------
# 7. Reload or Instructions
# ------------------------------------------------------------------------------
echo -e "\n\033[1;36m[5/5] Finalizing setup...\033[0m"
if pgrep -x "quickshell" > /dev/null; then
    if [ -f "$SHELL_DEST/src/scripts/reload.sh" ]; then
        echo -e "\033[0;32m[✓] Reloading Quickshell daemon...\033[0m"
        bash "$SHELL_DEST/src/scripts/reload.sh" || true
    fi
else
    echo -e "\033[0;33m[-] Quickshell is not currently active.\033[0m"
    echo -e "    You can start it with: quickshell -p $SHELL_DEST/src/quickshell/Shell.qml"
fi

echo -e "\n\033[1;32m======================================================================\033[0m"
echo -e "\033[1;32m  🎉 Hydronium Universal Setup Completed Successfully!\033[0m"
echo -e "\033[1;32m======================================================================\033[0m\n"
