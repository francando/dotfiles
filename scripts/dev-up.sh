#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=utils.sh
source "$DOTFILES_ROOT/scripts/utils.sh"

ensure_dotfiles_root
require_host
require_devpod
require_docker_compose_v2

consume_common_flags "$@"
set -- "${DEV_ARGS[@]}"

recreate=0
while [[ $# -gt 0 ]]; do
    case "$1" in
    --recreate)
        recreate=1
        shift
        ;;
    *)
        error "Unknown argument: $1"
        exit 1
        ;;
    esac
done

id="$(workspace_id)"
root="$(repo_root)"

args=("${DEVPOD_GLOBAL_FLAGS[@]}" up "$root" --id "$id" --ide none
    --provider-option "DOCKER_PATH=$(devpod_docker_path)")
if [[ "$recreate" -eq 1 ]]; then
    args+=(--recreate)
fi

log "Starting DevPod workspace: $id"
log "  source: $root"
devpod "${args[@]}"
success "Workspace $id is up"

if ssh_host_configured "$id"; then
    sync_dotfiles_to_workspace "$id" || warn "Dotfiles sync failed — try: dev sync --id $id"
fi
