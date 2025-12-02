#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

log "Prüfe grundlegende Build-Tools..."

if ! command -v git >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y git || sudo dnf install -y git || sudo pacman -S --noconfirm git || sudo zypper in -y git
fi

if ! command -v node >/dev/null 2>&1 || [ "$(node -v | cut -d. -f1 | sed 's/v//')" -lt 20 ]; then
    log "Installiere Node.js >=20 (via nodesource oder nvm-fallback)"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs || true
    fi

    if ! command -v node >/dev/null 2>&1; then
        warn "nodesource hat nicht geklappt, nutze nvm als Fallback"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install 20
    fi
fi

if ! command -v pnpm >/dev/null 2>&1; then
    log "Installiere pnpm"
    curl -fsSL https://get.pnpm.io/install.sh | sh -

    export PNPM_HOME="$HOME/.local/share/pnpm"
    export PATH="$PNPM_HOME:$PATH"
fi

log "Installiere Systemabhängigkeiten für libvesktop..."

if command -v apt-get >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y build-essential python3 curl pkg-config libglib2.0-dev libwebkit2gtk-4.1-dev
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y @c-development @development-tools python3 curl pkgconf-pkg-config glib2-devel webkit2gtk4.1-devel
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm base-devel python curl pkgconf glib2 webkit2gtk-4.1
elif command -v zypper >/dev/null 2>&1; then
    sudo zypper in -y --no-recommends gcc-c++ python3 curl pkg-config glib2-devel webkit2gtk4-devel
else
    error "Unbekannter Paketmanager – bitte manuell libglib2.0-dev, webkit2gtk und build-essential installieren"
fi

log "Klone Vesktop-Repository..."
if [ -d "Vesktop" ]; then
    warn "Ordner Vesktop existiert schon → pull neueste Änderungen"
    cd Vesktop
    git pull
    cd ..
else
    git clone https://github.com/Vencord/Vesktop.git
fi
cd Vesktop

log "Installiere Node-Abhängigkeiten (das kann 1-2 Minuten dauern)..."
pnpm i

log "Baue libvesktop (native Linux-Erweiterung)..."
pnpm buildLibVesktop

log "Packe Vesktop für dein System..."

if command -v pacman >/dev/null 2>&1; then
    log "Arch Linux erkannt → baue Pacman-Paket"
    pnpm package --linux pacman
elif command -v dnf >/dev/null 2>&1; then
    log "Fedora/openSUSE erkannt → baue RPM"
    pnpm package --linux rpm
elif command -v apt >/dev/null 2>&1; then
    log "Debian/Ubuntu erkannt → baue DEB"
    pnpm package --linux deb
else
    log "Kein bekannter Paketmanager → baue AppImage (portabel)"
    pnpm package --linux appimage
fi

log "Fertig! 🎉"
echo
echo "Deine fertige Vesktop-Datei liegt hier:"
echo "   $(pwd)/dist/"
echo
echo "Beispiele:"
echo "   - .deb → sudo dpkg -i dist/vesktop_*.deb"
echo "   - .rpm → sudo rpm -i dist/vesktop-*.rpm"
echo "   - AppImage → chmod +x dist/Vesktop-*.AppImage && ./dist/Vesktop-*.AppImage"
echo
echo "Viel Spaß mit Vesktop 🚀"

exit 0
