#!/usr/bin/env bash
# DevPod / container bootstrap: Neovim + config only (no host desktop tools).
# Cloned by DevPod into ~/dotfiles and run via DOTFILES_SCRIPT.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf "→ %s\n" "$*"; }
success() { printf "✔ %s\n" "$*"; }

ensure_path() {
    mkdir -p "$HOME/.local/bin"
    case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
    esac

    # Persist for interactive shells in this workspace
    local line='export PATH="$HOME/.local/bin:$PATH"'
    for rc in "$HOME/.bashrc" "$HOME/.profile"; do
        if [[ -f "$rc" ]] || [[ "$rc" == "$HOME/.bashrc" ]]; then
            touch "$rc"
            if ! grep -qF '.local/bin' "$rc" 2>/dev/null; then
                printf '\n# DevPod dotfiles\n%s\n' "$line" >>"$rc"
            fi
        fi
    done
}

install_nvim() {
    if command -v nvim >/dev/null 2>&1; then
        log "nvim already on PATH: $(command -v nvim)"
        return 0
    fi

    local arch asset
    arch="$(uname -m)"
    case "$arch" in
    x86_64 | amd64) asset="nvim-linux-x86_64" ;;
    aarch64 | arm64) asset="nvim-linux-arm64" ;;
    *)
        echo "✗ Unsupported arch: $arch" >&2
        exit 1
        ;;
    esac

    local url="https://github.com/neovim/neovim/releases/latest/download/${asset}.tar.gz"
    local tmp
    tmp="$(mktemp -d)"
    log "Installing Neovim ($asset) into ~/.local/nvim…"
    curl -fsSL "$url" -o "$tmp/nvim.tar.gz"
    rm -rf "$HOME/.local/nvim"
    mkdir -p "$HOME/.local/nvim"
    tar -xzf "$tmp/nvim.tar.gz" -C "$HOME/.local/nvim" --strip-components=1
    ln -sfn "$HOME/.local/nvim/bin/nvim" "$HOME/.local/bin/nvim"
    rm -rf "$tmp"
    success "nvim $(nvim --version | head -1)"
}

link_nvim_config() {
    mkdir -p "$HOME/.config"
    local src="$DOTFILES_DIR/nvim/.config/nvim"
    local dst="$HOME/.config/nvim"

    if [[ ! -d "$src" ]]; then
        echo "✗ Missing nvim config at $src" >&2
        exit 1
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        rm -rf "$dst"
    fi
    ln -sfn "$src" "$dst"
    success "Linked $dst → $src"
}

install_telescope_deps() {
    # Best-effort; images vary (apt/apk/none)
    if command -v rg >/dev/null 2>&1 && command -v fd >/dev/null 2>&1; then
        return 0
    fi
    if command -v sudo >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
        log "Installing ripgrep / fd-find (apt)…"
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ripgrep fd-find >/dev/null || true
        if command -v fdfind >/dev/null 2>&1 && [[ ! -e "$HOME/.local/bin/fd" ]]; then
            ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
        fi
    fi
}

main() {
    log "DevPod dotfiles install from $DOTFILES_DIR"
    ensure_path
    install_nvim
    link_nvim_config
    install_telescope_deps
    success "Done — open a pane and run: nvim"
}

main "$@"
