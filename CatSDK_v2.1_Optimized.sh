#!/bin/zsh
# ══════════════════════════════════════════════════════════════════════════════
# 🐱 CATSDK v2.1 OPTIMIZED - 1930s→2025 Compiler Collection
# macOS Tahoe (15.x/26.x+) | By Flames/Team Flames/Samsoft
# ══════════════════════════════════════════════════════════════════════════════
# Usage: ./CatSDK_v2.1_Optimized.sh [-y] [-q] [-n64-only]
#   -y         Auto-yes to all prompts
#   -q         Quiet mode (minimal output)
#   -n64-only  Only install N64 toolchain
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════
# CONFIG & FLAGS
# ═══════════════════════════════════════════════════════════════════════
VERSION="2.1.0"
ARCH=$(uname -m)
JOBS=$(sysctl -n hw.ncpu)
AUTO_YES=false; QUIET=false; N64_ONLY=false

for arg in "$@"; do
  case $arg in
    -y|--yes) AUTO_YES=true ;;
    -q|--quiet) QUIET=true ;;
    -n64-only|--n64-only) N64_ONLY=true ;;
  esac
done

# Colors (disabled in quiet mode)
if $QUIET; then
  R=''; G=''; Y=''; B=''; C=''; M=''; N=''
else
  R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
  B='\033[0;34m'; C='\033[0;36m'; M='\033[0;35m'; N='\033[0m'
fi

# ═══════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════
log()  { $QUIET || echo "${G}[✓]${N} $1"; }
info() { $QUIET || echo "${B}  →${N} $1"; }
warn() { echo "${Y}[!]${N} $1"; }
err()  { echo "${R}[✗]${N} $1"; }
cat_say() { $QUIET || echo "${M}[=^.^=]${N} $1"; }

confirm() {
  $AUTO_YES && return 0
  read -q "?    $1 [y/N]: " && echo && return 0
  echo; return 1
}

# Batch brew install - fast, parallel where possible
brew_batch() {
  local missing=()
  for p in "$@"; do
    brew list "$p" &>/dev/null || missing+=("$p")
  done
  [[ ${#missing[@]} -eq 0 ]] && return 0
  info "Installing: ${missing[*]}"
  brew install --quiet "${missing[@]}" 2>/dev/null || true
}

brew_cask_batch() {
  local missing=()
  for p in "$@"; do
    brew list --cask "$p" &>/dev/null || missing+=("$p")
  done
  [[ ${#missing[@]} -eq 0 ]] && return 0
  brew install --quiet --cask "${missing[@]}" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════════════════════════════
$QUIET || cat << 'EOF'

   ╔═══════════════════════════════════════════════════════════╗
   ║  🐱 CATSDK v2.1 OPTIMIZED - Mega Compiler Installer      ║
   ║     1930s → 2025 | macOS Tahoe | Flames/Samsoft          ║
   ║     /\_/\                                                 ║
   ║    ( o.o )  Fast. Clean. Purrfect.                       ║
   ║     > ^ <                                                 ║
   ╚═══════════════════════════════════════════════════════════╝

EOF

# ═══════════════════════════════════════════════════════════════════════
# SYSTEM CHECKS
# ═══════════════════════════════════════════════════════════════════════
log "System: macOS $(sw_vers -productVersion) | $ARCH | $JOBS cores"

# Xcode CLT
xcode-select -p &>/dev/null || { xcode-select --install; exit 1; }

# Homebrew
if ! command -v brew &>/dev/null; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [[ "$ARCH" == "arm64" ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
fi
BREW_PREFIX=$(brew --prefix)

# ═══════════════════════════════════════════════════════════════════════
# N64-ONLY MODE
# ═══════════════════════════════════════════════════════════════════════
install_n64() {
  log "Installing N64 libdragon toolchain..."
  
  local LIBDRAGON=/opt/libdragon
  local URL="https://github.com/DragonMinded/libdragon/releases/download/toolchain-continuous"
  [[ "$ARCH" == "arm64" ]] && URL+="/gcc-toolchain-mips64-aarch64-apple-darwin.tar.gz" \
                           || URL+="/gcc-toolchain-mips64-x86_64-apple-darwin.tar.gz"
  
  # Skip if already installed
  [[ -x "$LIBDRAGON/bin/mips64-elf-gcc" ]] && {
    log "libdragon already installed"
    info "$($LIBDRAGON/bin/mips64-elf-gcc --version | head -1)"
    return 0
  }
  
  # Clean failed attempts
  [[ -d "$LIBDRAGON" ]] && sudo rm -rf "$LIBDRAGON"
  rm -rf ~/n64-toolchain-build 2>/dev/null || true
  
  # Download & extract
  log "Downloading prebuilt toolchain..."
  cd /tmp && rm -f ld.tar.gz
  curl -fSL --progress-bar -o ld.tar.gz "$URL" || { err "Download failed"; return 1; }
  
  log "Extracting..."
  sudo mkdir -p "$LIBDRAGON"
  sudo tar -xzf ld.tar.gz -C "$LIBDRAGON" --strip-components=1 2>/dev/null \
    || sudo tar -xzf ld.tar.gz -C "$LIBDRAGON"
  rm -f /tmp/ld.tar.gz
  
  # Verify
  [[ -x "$LIBDRAGON/bin/mips64-elf-gcc" ]] || { err "Install failed"; return 1; }
  log "Installed: $($LIBDRAGON/bin/mips64-elf-gcc --version | head -1)"
  
  # n64-build helper
  sudo tee /usr/local/bin/n64-build >/dev/null << 'SCRIPT'
#!/bin/zsh
[[ -z "$1" || -z "$2" ]] && { echo "Usage: n64-build src.c out.z64"; exit 1; }
export PATH="/opt/libdragon/bin:$PATH"
mips64-elf-gcc -march=vr4300 -mtune=vr4300 -O2 -G0 \
  -I/opt/libdragon/mips64-elf/include -L/opt/libdragon/mips64-elf/lib \
  "$1" -ldragon -lc -ldragonsys -o /tmp/n64.elf || exit 1
command -v n64tool &>/dev/null && n64tool -l 2M -o "$2" /tmp/n64.elf \
  || mv /tmp/n64.elf "${2%.z64}.elf"
rm -f /tmp/n64.elf; echo "✅ Built: $2"
SCRIPT
  sudo chmod +x /usr/local/bin/n64-build
  
  # Sample project
  [[ -d ~/n64-sample ]] || {
    mkdir -p ~/n64-sample
    cat > ~/n64-sample/main.c << 'SRC'
#include <stdio.h>
#include <libdragon.h>
int main(void) {
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, FILTERS_RESAMPLE);
    console_init(); console_set_render_mode(RENDER_MANUAL); controller_init();
    printf("\n\n  Hello N64! - CatSDK\n  Press START to exit\n");
    while(1) { console_render(); controller_scan();
      if(get_keys_down().c[0].start) break; }
    return 0;
}
SRC
    cat > ~/n64-sample/Makefile << 'MK'
N64_INST ?= /opt/libdragon
include $(N64_INST)/include/n64.mk
all: main.z64
main.z64: main.c
	$(N64_CC) $(N64_CFLAGS) -o main.elf $<
	$(N64_OBJCOPY) -O binary main.elf main.bin
	$(N64_TOOL) -l 2M -t "Hello" -o $@ main.bin
	@rm -f main.elf main.bin
clean: ; rm -f *.z64 *.elf *.bin
MK
    info "Sample: ~/n64-sample (run 'make')"
  }
  cat_say "N64 ready! 🐲"
}

$N64_ONLY && { install_n64; exit 0; }

# ═══════════════════════════════════════════════════════════════════════
# FULL INSTALL
# ═══════════════════════════════════════════════════════════════════════

log "Updating Homebrew..."
brew update -q 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────
# BUILD ESSENTIALS
# ─────────────────────────────────────────────────────────────────────────
log "Installing build essentials..."
brew_batch wget curl cmake make autoconf automake bison flex \
           gmp mpfr libmpc texinfo xz pkg-config libtool coreutils

# ─────────────────────────────────────────────────────────────────────────
# HISTORICAL (1930s-1970s)
# ─────────────────────────────────────────────────────────────────────────
log "Installing historical simulators..."
brew_batch open-simh hercules spim haskell-stack
pip3 install -q --break-system-packages turing-machine 2>/dev/null || true
cat_say "Mainframes online! 🖥️"

# ─────────────────────────────────────────────────────────────────────────
# RETRO 8-BIT (1970s-1980s)
# ─────────────────────────────────────────────────────────────────────────
log "Installing 8-bit toolchains..."
brew_batch cc65 rgbds acme dasm xa
# These may not exist in Homebrew
brew list z88dk &>/dev/null || brew install z88dk 2>/dev/null || true
brew list wla-dx &>/dev/null || brew install wla-dx 2>/dev/null || true
cat_say "8-bit dreams! 💾"

# ─────────────────────────────────────────────────────────────────────────
# DEVKITPRO (GBA → Switch)
# ─────────────────────────────────────────────────────────────────────────
log "Installing devkitPro..."
if ! command -v dkp-pacman &>/dev/null; then
  cd /tmp
  curl -fsSLO "https://github.com/devkitPro/pacman/releases/latest/download/devkitpro-pacman-installer.pkg" 2>/dev/null && {
    sudo installer -pkg devkitpro-pacman-installer.pkg -target / 2>/dev/null
    rm -f devkitpro-pacman-installer.pkg
  } || warn "devkitPro download failed"
fi

if command -v dkp-pacman &>/dev/null; then
  sudo dkp-pacman -Syu --noconfirm 2>/dev/null || true
  for pkg in gba-dev nds-dev 3ds-dev switch-dev wii-dev gamecube-dev; do
    sudo dkp-pacman -S --noconfirm --needed $pkg 2>/dev/null || true
  done
fi
cat_say "Nintendo conquered! 👑"

# ─────────────────────────────────────────────────────────────────────────
# N64 (LIBDRAGON)
# ─────────────────────────────────────────────────────────────────────────
install_n64

# ─────────────────────────────────────────────────────────────────────────
# MODERN COMPILERS
# ─────────────────────────────────────────────────────────────────────────
log "Installing modern compilers..."
brew_batch gcc llvm rust go zig nasm yasm node python@3.12 openjdk
brew_batch emscripten wasm-pack binaryen
brew_batch fpc 2>/dev/null || true
brew_batch mono dotnet 2>/dev/null || true
sudo ln -sfn "$BREW_PREFIX/opt/openjdk/libexec/openjdk.jdk" \
  /Library/Java/JavaVirtualMachines/openjdk.jdk 2>/dev/null || true

# ─────────────────────────────────────────────────────────────────────────
# EMULATORS (OPTIONAL)
# ─────────────────────────────────────────────────────────────────────────
confirm "Install emulators (OpenEmu, RetroArch, MAME)?" && {
  log "Installing emulators..."
  brew_cask_batch openemu retroarch
  brew_batch mame mednafen
}

# ─────────────────────────────────────────────────────────────────────────
# SHELL CONFIG
# ─────────────────────────────────────────────────────────────────────────
log "Configuring shell..."
RC="$HOME/.zshrc"

# Clean old entries
grep -v -E "(CATSDK|libdragon|DEVKITPRO|N64_INST)" "$RC" > "$RC.tmp" 2>/dev/null && mv "$RC.tmp" "$RC"

cat >> "$RC" << 'ENV'

# ══ CATSDK v2.1 ══
export DEVKITPRO=/opt/devkitpro DEVKITARM=$DEVKITPRO/devkitARM
export DEVKITPPC=$DEVKITPRO/devkitPPC DEVKITA64=$DEVKITPRO/devkitA64
export N64_INST=/opt/libdragon LIBDRAGON=/opt/libdragon
export PS2DEV=/usr/local/ps2dev PS2SDK=$PS2DEV/ps2sdk
[ -d "$DEVKITPRO" ] && PATH=$DEVKITPRO/tools/bin:$PATH
[ -d "$LIBDRAGON/bin" ] && PATH=$LIBDRAGON/bin:$PATH
[ -d "/opt/gbdk/bin" ] && PATH=/opt/gbdk/bin:$PATH
ENV

# ─────────────────────────────────────────────────────────────────────────
# VERIFY
# ─────────────────────────────────────────────────────────────────────────
log "Verifying installation..."
echo ""
for cmd in cc65 rgbasm mips64-elf-gcc rustc go zig nasm node; do
  command -v $cmd &>/dev/null && echo "${G}✓${N} $cmd" || echo "${Y}○${N} $cmd (not in PATH)"
done
[[ -d /opt/devkitpro/devkitARM ]] && echo "${G}✓${N} devkitARM" || echo "${Y}○${N} devkitARM"
[[ -x /opt/libdragon/bin/mips64-elf-gcc ]] && echo "${G}✓${N} libdragon" || echo "${Y}○${N} libdragon"

# ─────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────
$QUIET || cat << EOF

${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}
${C}/\\_/\\${N}   ${Y}🎮 CatSDK v$VERSION installed!${N}
${C}( o.o )${N}  Run: ${G}source ~/.zshrc${N}
${C} > ^ <${N}   N64: ${G}cd ~/n64-sample && make${N}
${G}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}

EOF
