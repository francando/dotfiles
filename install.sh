#!/bin/bash

# Exit on error
set -e

echo "Starting Dotfiles Bootstrap..."

# 1. Detect OS and install dependencies
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Detected Linux. Installing dependencies..."
    # Add procps for tmux-nvim navigation compatibility
    apt-get update && sudo apt-get install -y stow tmux curl git
    echo "Installing neovim snap..."
    snap install neovim
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected macOS. Installing dependencies..."
    brew install stow tmux neovim curl git
fi

# 2. Navigate to dotfiles directory
DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$DOTFILES_DIR"

# 3. Clean up existing configs to prevent Stow conflicts
echo "Cleaning up existing config paths..."
rm -rf ~/.config/nvim
rm -f ~/.tmux.conf

# 4. Use Stow to create symlinks
echo "Stowing configurations..."
stow nvim
stow tmux
stow alacritty

TPM_DIR="$HOME/.config/tmux/plugins/tpm"
# 5. Install Tmux Plugin Manager (TPM) if not present
if [ ! -d "$TPM_DIR" ]; then
    echo "Installing Tmux Plugin Manager to $TPM_DIR..."
    git clone https://github.com "$TPM_DIR"
    echo "Installing plugins..."
    "$TPM_DIR/bin/install_plugins"
fi

echo "✅ Setup Complete!"
echo "Open 'nvim' to trigger plugin installation."

