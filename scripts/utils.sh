#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Logging helpers
# -----------------------------
log() {
    printf "→ %s\n" "$*"
}

info() {
    printf "[INFO] %s\n" "$*"
}

success() {
    printf "✔ %s\n" "$*"
}

warn() {
    printf "⚠ %s\n" "$*" >&2
}

error() {
    printf "✗ %s\n" "$*" >&2
}

# -----------------------------
# Confirmation prompt
# -----------------------------
confirm() {
    local prompt="${1:-Continue?}"
    local reply

    printf "%s [y/N] " "$prompt"
    read -r reply

    case "$reply" in
    y | Y | yes | YES) return 0 ;;
    *) return 1 ;;
    esac
}

# -----------------------------
# Devcontainer helpers
# -----------------------------

# Find .devcontainer/devcontainer.json
# Prints path if found, exits non-zero otherwise
find_devcontainer() {
    local dir="${1:-$PWD}"
    local dc="$dir/.devcontainer/devcontainer.json"

    if [[ -f "$dc" ]]; then
        echo "$dc"
        return 0
    fi

    return 1
}

# Read a value from devcontainer.json using jq
# Usage: devcontainer_get key [file]
# Example: devcontainer_get build.dockerfile
devcontainer_get() {
    local key="$1"
    local file="${2:-}"

    if [[ -z "$file" ]]; then
        file="$(find_devcontainer)" || return 1
    fi

    jq -r --arg key "$key" '
        getpath($key | split(".")) // empty
    ' "$file" 2>/dev/null || true
}

# -----------------------------
# Repo helpers
# -----------------------------

# Return repo root (git-based, fallback to PWD)
repo_root() {
    if command -v git >/dev/null 2>&1; then
        git rev-parse --show-toplevel 2>/dev/null || pwd
    else
        pwd
    fi
}

# Check if a Dockerfile exists at repo root
has_root_dockerfile() {
    [[ -f "$(repo_root)/Dockerfile" ]]
}

# -----------------------------
# Docker helpers
# -----------------------------

# Ensure docker is available
require_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        error "docker is not installed or not in PATH"
        exit 1
    fi
}

# Ensure docker compose is available
require_docker_compose() {
    if ! docker compose version >/dev/null 2>&1; then
        error "docker compose is not available"
        exit 1
    fi
}

docker_image_name() {
    local repo
    repo="$(basename "$(repo_root)")" # last folder of the repo
    # replace invalid chars for Docker image names
    repo="${repo//[^a-zA-Z0-9_.-]/_}"
    echo "${repo}"
}

# -----------------------------
# Safety checks
# -----------------------------

require_dotfiles_root() {
    if [[ -z "${DOTFILES_ROOT:-}" ]]; then
        error "DOTFILES_ROOT is not set"
        error "Export it in your shell (e.g. ~/.zshrc)"
        exit 1
    fi
}
