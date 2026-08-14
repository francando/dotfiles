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

id="$(workspace_id)"

if ! workspace_exists "$id"; then
    warn "Workspace '$id' does not exist"
    exit 0
fi

log "Stopping DevPod workspace: $id"
devpod stop "$id"
success "Stopped $id"
