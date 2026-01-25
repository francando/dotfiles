#!/bin/bash

# Exit on error
set -e

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "❌ Error: This setup is currently optimized for Linux (Ubuntu/Debian) only."
    echo "Detected OSTYPE: $OSTYPE"
    exit 1
fi

# --- TOOL FUNCTIONS ---
setup_alacritty() {
    echo "🖥️  Setting up Alacritty..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo snap install --classic alacritty
    fi
    rm -rf ~/.config/alacritty
    stow alacritty
}

setup_zsh() {
    echo "🐚 Setting up Zsh & Catppuccin theme..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt install -y zsh zsh-syntax-highlighting zsh-autosuggestions shfmt
    fi

    # Clean and stow
    rm -f ~/.zshrc
    rm -rf ~/.zsh
    mkdir -p "$HOME/.zsh"
    stow zsh

    # Theme logic
    if [ ! -d "/tmp/catppuccin-zsh" ]; then
        git clone --depth 1 https://github.com/catppuccin/zsh-syntax-highlighting.git /tmp/catppuccin-zsh
    fi
    cp /tmp/catppuccin-zsh/themes/catppuccin_macchiato-zsh-syntax-highlighting.zsh "$HOME/.zsh/"

    # Shell switch
    if [ "$SHELL" != "$(which zsh)" ]; then
        echo "Changing default shell to Zsh..."
        chsh -s "$(which zsh)"
    fi
}

setup_font() {

    FONT_NAME="JetBrainsMono"
    NERD_FONT_NAME="JetBrainsMono"
    FONTS_DIR="$HOME/.local/share/fonts"

    echo "Creating font directory at $FONTS_DIR..."
    mkdir -p "$FONTS_DIR"

    echo "Downloading $FONT_NAME Nerd Font from official Nerd Fonts release..."
    wget -q --show-progress \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${NERD_FONT_NAME}.zip" \
        -O "${FONT_NAME}.zip"

    echo "Extracting and installing..."
    unzip -o "${FONT_NAME}.zip" -d "$FONTS_DIR/${FONT_NAME}"

    echo "Cleaning up..."
    rm -f "${FONT_NAME}.zip"

    echo "Updating font cache..."
    fc-cache -fv "$FONTS_DIR"

    echo "---------------------------------------------------"
    echo "Done! Set your terminal font to 'JetBrainsMono Nerd Font'."
    echo "---------------------------------------------------"
}

setup_tmux() {
    echo "🪟 Setting up Tmux & TPM..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt install -y tmux procps
    fi

    rm -f ~/.tmux.conf
    stow tmux

    TPM_DIR="$HOME/.config/tmux/plugins/tpm"
    if [ ! -d "$TPM_DIR" ]; then
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
        "$TPM_DIR/bin/install_plugins"
    fi
}

setup_neovim() {
    echo "🌙 Setting up Neovim..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if ! command -v nvim &>/dev/null; then
            sudo snap install nvim --classic
        fi
    fi
    rm -rf ~/.config/nvim
    stow nvim
}

# --- MAIN EXECUTION ---

echo "🚀 Starting Dotfiles Bootstrap..."

# 1. Essential System Tools
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sudo apt update && sudo apt install -y stow curl git python3-venv
fi

# 2. Execute Tool Setups
cd "$DOTFILES_DIR"
setup_alacritty
setup_zsh
setup_font
setup_tmux
setup_neovim

echo "✅ Setup Complete!"
