#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  🚀 ADB Device Manager — Linux Desktop Integration Installer
#  Designed by: Shrey113 & Antigravity
#  GitHub: https://github.com/Shrey113/Adb-Device-Manager-2
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
CYN='\033[0;36m'
BLD='\033[1m'
NC='\033[0m'

ok()    { echo -e "${GRN}  [OK]${NC}   $*"; }
warn()  { echo -e "${YLW}  [WARN]${NC} $*"; }
err()   { echo -e "${RED}  [MISS]${NC} $*"; }
info()  { echo -e "${CYN}  [INFO]${NC} $*"; }
title() { echo -e "\n${BLD}$*${NC}"; }

title "ADB Device Manager — Linux Desktop Integration"

# Get absolute path of this script directory
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define possible paths for the launcher script
LAUNCHER_PATH="$DIR/run_adb_devices.sh"

# Define possible paths for the icon
ICON_PATH=""
if [ -f "$DIR/assets/_my_app/app_png.png" ]; then
    ICON_PATH="$DIR/assets/_my_app/app_png.png"
elif [ -f "$DIR/data/flutter_assets/assets/_my_app/app_png.png" ]; then
    ICON_PATH="$DIR/data/flutter_assets/assets/_my_app/app_png.png"
fi

# Verification checks
if [ ! -f "$LAUNCHER_PATH" ]; then
    err "Launcher script 'run_adb_devices.sh' not found in $DIR."
    exit 1
fi

if [ -z "$ICON_PATH" ]; then
    err "App icon (app_png.png) not found in assets."
    exit 1
fi

# Ensure launcher is executable
chmod +x "$LAUNCHER_PATH"

# Create application directory if it doesn't exist
APPS_DIR="$HOME/.local/share/applications"
mkdir -p "$APPS_DIR"

DESKTOP_FILE="$APPS_DIR/com.example.adb_devices.desktop"

# Write the .desktop file
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=ADB Device Manager
Comment=Manage ADB Devices, Screen Mirroring, and Audio
Exec=$LAUNCHER_PATH
Icon=$ICON_PATH
Terminal=false
Categories=Utility;Development;
StartupWMClass=com.example.adb_devices
EOF

# Make the desktop shortcut executable
chmod +x "$DESKTOP_FILE"

# Refresh desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APPS_DIR" 2>/dev/null
fi

ok "Successfully created desktop shortcut!"
info "Shortcut path: $DESKTOP_FILE"
info "You should now see 'ADB Device Manager' in your application menu with the app icon!"
echo
