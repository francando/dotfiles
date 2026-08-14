#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=utils.sh
source "$DOTFILES_ROOT/scripts/utils.sh"

ensure_dotfiles_root
require_host
require_devpod

consume_common_flags "$@"
set -- "${DEV_ARGS[@]}"

if [[ $# -gt 0 ]]; then
    error "Unknown argument: $1"
    exit 1
fi

sync_dotfiles_to_workspace
