#!/bin/zsh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LIBDRAGON INSTALLER (NO GIT / NO DOCKER)
# For macOS ARM64 (M1–M4) & Intel
# By Flames / Team Flames
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${YELLOW} LIBDRAGON INSTALLER (NO GIT / NO DOCKER)${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Detect architecture
ARCH=$(uname -m)
INSTALL_DIR="/opt/libdragon"

if [[ "$ARCH" == "arm64" ]]; then
    echo "${GREEN}✓${NC} Detected: Apple Silicon (M1/M2/M3/M4)"
    TOOLCHAIN_URL="https://github.com/DragonMinded/libdragon/releases/download/toolchain-9.3.0/libdragon-toolchain-9.3.0-darwin-arm64.tar.gz"
else
    echo "${GREEN}✓${NC} Detected: Intel Mac (x86_64)"
    TOOLCHAIN_URL="https://github.com/DragonMinded/libdragon/releases/download/toolchain-9.3.0/libdragon-toolchain-9.3.0-darwin-x86_64.tar.gz"
fi

echo ""

# Check if already installed
if [[ -f "$INSTALL_DIR/bin/mips64-elf-gcc" ]]; then
    echo "${YELLOW}!${NC} libdragon already installed at $INSTALL_DIR"
    echo ""
    read -p "    Reinstall? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting."
        exit 0
    fi
    echo "${YELLOW}→${NC} Removing old installation..."
    sudo rm -rf "$INSTALL_DIR"
fi

# Download toolchain
echo "${CYAN}→${NC} Downloading libdragon toolchain (9.3.0)..."

if command -v wget &>/dev/null; then
    wget -q --show-progress -O /tmp/libdragon.tar.gz "$TOOLCHAIN_URL"
elif command -v curl &>/dev/null; then
    curl -L -o /tmp/libdragon.tar.gz "$TOOLCHAIN_URL"
else
    echo "${RED}✗${NC} Neither wget nor curl found! Install one first."
    exit 1
fi

# Create install directory
echo "${CYAN}→${NC} Creating install directory..."
sudo mkdir -p "$INSTALL_DIR"

# Extract
echo "${CYAN}→${NC} Extracting toolchain to $INSTALL_DIR..."
sudo tar -xzf /tmp/libdragon.tar.gz -C "$INSTALL_DIR"

# Add to PATH
echo "${CYAN}→${NC} Configuring shell..."

SHELL_RC="$HOME/.zshrc"
[[ -f "$HOME/.bashrc" ]] && [[ ! -f "$HOME/.zshrc" ]] && SHELL_RC="$HOME/.bashrc"

if ! grep -q "/opt/libdragon/bin" "$SHELL_RC" 2>/dev/null; then
    cat >> "$SHELL_RC" << 'EOF'

# ════════════════════════════════════════════════════
# libdragon N64 SDK (NO-GIT) - Team Flames
# ════════════════════════════════════════════════════
export LIBDRAGON=/opt/libdragon
export PATH="/opt/libdragon/bin:$PATH"
EOF
    echo "${GREEN}✓${NC} Added PATH to $SHELL_RC"
else
    echo "${GREEN}✓${NC} PATH already configured in $SHELL_RC"
fi

# Cleanup
echo "${CYAN}→${NC} Cleaning up..."
rm -f /tmp/libdragon.tar.gz

# Export for current session
export PATH="/opt/libdragon/bin:$PATH"

# Verification
echo ""
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${YELLOW} Verifying libdragon toolchain...${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

check() {
    if command -v "$1" &>/dev/null; then
        echo "${GREEN}✓${NC} $1 → $($1 --version 2>/dev/null | head -1 || echo 'OK')"
    else
        echo "${RED}✗${NC} $1 NOT FOUND"
    fi
}

check mips64-elf-gcc
check mips64-elf-g++
check mips64-elf-as
check mips64-elf-ld
check mips64-elf-objcopy
check n64tool
check chksum64
check mkdfs
check mksprite

# Create n64-build helper
echo ""
echo "${CYAN}→${NC} Installing n64-build helper..."

sudo tee /usr/local/bin/n64-build > /dev/null << 'HELPER'
#!/bin/zsh
# n64-build - Quick N64 ROM compiler
# Usage: n64-build source.c output.z64

SRC="$1"; OUT="$2"

[[ -z "$SRC" || -z "$OUT" ]] && {
    echo "Usage: n64-build <source.c> <output.z64>"
    exit 1
}

export PATH="/opt/libdragon/bin:$PATH"

echo "→ Compiling $SRC..."
mips64-elf-gcc -march=vr4300 -mtune=vr4300 -O2 -G0 \
    -I/opt/libdragon/mips64-elf/include \
    -L/opt/libdragon/mips64-elf/lib \
    "$SRC" -ldragon -lc -ldragonsys -o /tmp/n64_temp.elf || exit 1

echo "→ Building ROM..."
n64tool -l 2M -o "$OUT" -e 0 /tmp/n64_temp.elf
chksum64 "$OUT" > /dev/null 2>&1 || true

rm -f /tmp/n64_temp.elf
echo "✓ Built: $OUT"
HELPER

sudo chmod +x /usr/local/bin/n64-build
echo "${GREEN}✓${NC} n64-build installed"

# Create sample project
SAMPLE_DIR="$HOME/n64-hello"
if [[ ! -d "$SAMPLE_DIR" ]]; then
    echo ""
    echo "${CYAN}→${NC} Creating sample project at ~/n64-hello..."
    mkdir -p "$SAMPLE_DIR"
    
    cat > "$SAMPLE_DIR/hello.c" << 'SAMPLE'
#include <stdio.h>
#include <libdragon.h>

int main(void) {
    display_init(RESOLUTION_320x240, DEPTH_16_BPP, 2, GAMMA_NONE, FILTERS_RESAMPLE);
    console_init();
    console_set_render_mode(RENDER_MANUAL);
    controller_init();

    printf("\n\n");
    printf("  ================================\n");
    printf("  ||   Hello Nintendo 64!      ||\n");
    printf("  ||   libdragon 9.3.0         ||\n");
    printf("  ||   NO-GIT Edition          ||\n");
    printf("  ================================\n");
    printf("\n");
    printf("  Press START to exit\n");

    while (1) {
        console_render();
        controller_scan();
        if (get_keys_down().c[0].start) break;
    }
    return 0;
}
SAMPLE

    cat > "$SAMPLE_DIR/Makefile" << 'MAKEFILE'
# N64 Hello World - FlamesCo
TARGET = hello
LIBDRAGON = /opt/libdragon

include $(LIBDRAGON)/include/n64.mk

$(TARGET).z64: $(TARGET).c
	$(N64_CC) $(N64_CFLAGS) -o $(TARGET).elf $<
	$(N64_TOOL) -l 2M -t "Hello N64" -o $@ $(TARGET).elf
	@$(N64_CHKSUM) $@ || true
	@echo "✓ Built: $@"

clean:
	rm -f *.elf *.z64

.PHONY: clean
MAKEFILE

    echo "${GREEN}✓${NC} Sample project created"
fi

# Done!
echo ""
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${GREEN} ✓ LIBDRAGON INSTALLATION COMPLETE!${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo " ${YELLOW}Quick Start:${NC}"
echo "   cd ~/n64-hello"
echo "   make"
echo ""
echo " ${YELLOW}Or use n64-build:${NC}"
echo "   n64-build hello.c hello.z64"
echo ""
echo " ${YELLOW}Restart terminal or run:${NC}"
echo "   source ~/.zshrc"
echo ""
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo " 🎮 Happy N64 coding! - Team Flames"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
