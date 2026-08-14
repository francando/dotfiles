#!/usr/bin/env bash
# DevPod / container bootstrap: packages (zsh, nvim) + stow all dotfiles.
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

    # zshrc is stowed — do not append into the symlink (that would dirty the repo).
    local line='export PATH="$HOME/.local/bin:$PATH"'
    for rc in "$HOME/.bashrc" "$HOME/.profile"; do
        touch "$rc"
        if ! grep -qF '.local/bin' "$rc" 2>/dev/null; then
            printf '\n# DevPod dotfiles\n%s\n' "$line" >>"$rc"
        fi
    done
}

ensure_stow() {
    if command -v stow >/dev/null 2>&1; then
        return 0
    fi
    if command -v sudo >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
        log "Installing stow…"
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq stow
    fi
    if ! command -v stow >/dev/null 2>&1; then
        echo "✗ stow is not installed (needed to link dotfiles)" >&2
        exit 1
    fi
}

# Top-level dirs meant for `stow -t $HOME` (home-relative layout).
stow_packages() {
    local dir name
    for dir in "$DOTFILES_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        name="$(basename "$dir")"
        case "$name" in
        bin | scripts | devcontainer) continue ;;
        esac
        if [[ -d "$dir/.config" || -e "$dir/.zshrc" || -e "$dir/.tmux.conf" ]]; then
            printf '%s\n' "$name"
        fi
    done
}

# Drop whole-directory symlinks from the old ln -sfn linker so stow can file-link.
unstow_conflicting_targets() {
    local pkg="$1"
    local dest name
    if [[ -d "$DOTFILES_DIR/$pkg/.config" ]]; then
        for dest in "$DOTFILES_DIR/$pkg/.config"/*; do
            [[ -e "$dest" || -L "$dest" ]] || continue
            name="$(basename "$dest")"
            if [[ -L "$HOME/.config/$name" ]]; then
                rm -f "$HOME/.config/$name"
            fi
        done
    fi
    if [[ -e "$DOTFILES_DIR/$pkg/.zshrc" ]] && [[ -L "$HOME/.zshrc" || -f "$HOME/.zshrc" ]]; then
        rm -f "$HOME/.zshrc"
    fi
}

# Stow every package into $HOME (same as host install.sh).
link_dotfiles() {
    local pkg
    ensure_stow
    mkdir -p "$HOME/.config"
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        unstow_conflicting_targets "$pkg"
        (cd "$DOTFILES_DIR" && stow -t "$HOME" -R "$pkg")
        success "stow $pkg"
    done < <(stow_packages)
}

glibc_version() {
    local ver
    ver="$(ldd --version 2>&1 | awk 'NR==1 {print $NF}')"
    echo "${ver:-0}"
}

version_lt() {
    printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1 | grep -qx "$1" && [[ "$1" != "$2" ]]
}

nvim_works() {
    command -v nvim >/dev/null 2>&1 && nvim --version >/dev/null 2>&1
}

link_nvim_bin() {
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$HOME/.local/nvim/bin/nvim" "$HOME/.local/bin/nvim"
}

install_nvim_tarball() {
    local arch url
    arch="$(uname -m)"
    case "$arch" in
    x86_64 | amd64)
        url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
        ;;
    aarch64 | arm64)
        url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-arm64.tar.gz"
        ;;
    *)
        echo "✗ Unsupported arch: $arch" >&2
        return 1
        ;;
    esac

    local tmp
    tmp="$(mktemp -d)"
    log "Installing official Neovim tarball into ~/.local/nvim…"
    curl -fsSL "$url" -o "$tmp/nvim.tar.gz"
    rm -rf "$HOME/.local/nvim"
    mkdir -p "$HOME/.local/nvim"
    tar -xzf "$tmp/nvim.tar.gz" -C "$HOME/.local/nvim" --strip-components=1
    link_nvim_bin
    rm -rf "$tmp"
}

ensure_nvim_build_deps() {
    if command -v cmake >/dev/null 2>&1 && command -v gcc >/dev/null 2>&1 && command -v ninja >/dev/null 2>&1; then
        return 0
    fi
    if command -v sudo >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
        log "Installing Neovim build dependencies (apt)…"
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
            ninja-build gettext cmake unzip curl git build-essential
        return 0
    fi
    echo "✗ Need cmake, gcc, ninja to build Neovim from source" >&2
    return 1
}

install_nvim_from_source() {
    local src
    src="$(mktemp -d)"
    log "Building Neovim 0.11+ from source (links against this image's glibc)…"
    log "This takes several minutes."
    ensure_nvim_build_deps
    git clone --depth 1 --branch stable https://github.com/neovim/neovim.git "$src/neovim"
    make -C "$src/neovim" CMAKE_BUILD_TYPE=Release \
        CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$HOME/.local/nvim"
    rm -rf "$HOME/.local/nvim"
    make -C "$src/neovim" install
    link_nvim_bin
    rm -rf "$src"
}

install_nvim() {
    if nvim_works; then
        log "nvim already on PATH: $(command -v nvim)"
        return 0
    fi

    local glibc
    glibc="$(glibc_version)"

    # Official binaries need glibc 2.34+ (Ubuntu 22.04). Older images must compile.
    if ! version_lt "$glibc" "2.34"; then
        install_nvim_tarball || true
        if nvim_works; then
            success "nvim $(nvim --version | head -1)"
            return 0
        fi
        log "Tarball Neovim does not run on glibc $glibc — building from source"
    else
        log "glibc $glibc < 2.34 — official nvim 0.11+ binaries will not run; building from source"
    fi

    rm -rf "$HOME/.local/nvim" "$HOME/.local/bin/nvim"
    install_nvim_from_source

    if ! nvim_works; then
        echo "✗ Neovim built but failed to run" >&2
        nvim --version >&2 || true
        exit 1
    fi
    success "nvim $(nvim --version | head -1)"
}

install_zsh() {
    if command -v sudo >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
        log "Installing zsh…"
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
            zsh zsh-syntax-highlighting zsh-autosuggestions stow
    elif ! command -v zsh >/dev/null 2>&1; then
        echo "✗ zsh is not installed and apt is unavailable" >&2
        exit 1
    fi

    mkdir -p "$HOME/.zsh"
    if [[ ! -f "$HOME/.zsh/catppuccin_macchiato-zsh-syntax-highlighting.zsh" ]]; then
        log "Installing Catppuccin zsh-syntax-highlighting theme…"
        git clone --depth 1 https://github.com/catppuccin/zsh-syntax-highlighting.git /tmp/catppuccin-zsh
        cp /tmp/catppuccin-zsh/themes/catppuccin_macchiato-zsh-syntax-highlighting.zsh "$HOME/.zsh/"
        rm -rf /tmp/catppuccin-zsh
    fi

    local zsh_bin
    zsh_bin="$(command -v zsh)"
    if [[ -n "$zsh_bin" ]] && grep -qxF "$zsh_bin" /etc/shells 2>/dev/null; then
        if command -v sudo >/dev/null 2>&1; then
            sudo chsh -s "$zsh_bin" "$USER" 2>/dev/null || chsh -s "$zsh_bin" 2>/dev/null || true
        else
            chsh -s "$zsh_bin" 2>/dev/null || true
        fi
    fi
    success "zsh $("$zsh_bin" --version 2>/dev/null | head -1)"
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
    install_zsh
    ensure_path
    install_nvim
    link_dotfiles
    install_telescope_deps
    success "Done — panes use zsh; run nvim inside the workspace"
}

if [[ "${1:-}" == "--links-only" ]]; then
    link_dotfiles
    exit 0
fi

main "$@"
