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

if ! workspace_running "$id"; then
    error "Workspace '$id' is not Running (state: $(workspace_state "$id" 2>/dev/null || echo Absent))"
    error "Start it with: dev up --id $id"
    exit 1
fi

log "SSH into workspace: $id"
warm_ssh_master "$id" || true
ssh_workspace "$id"
