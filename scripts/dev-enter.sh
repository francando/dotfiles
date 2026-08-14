#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=utils.sh
source "$DOTFILES_ROOT/scripts/utils.sh"

ensure_dotfiles_root
require_host
require_devpod
require_tmux

consume_common_flags "$@"
set -- "${DEV_ARGS[@]}"

session_name=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    --session)
        shift
        [[ $# -gt 0 ]] || {
            error "--session requires a name"
            exit 1
        }
        session_name="$1"
        shift
        ;;
    --session=*)
        session_name="${1#--session=}"
        shift
        ;;
    --attach)
        error "Use: dev attach [--session NAME]"
        exit 1
        ;;
    *)
        error "Unknown argument: $1 (supported: --session NAME)"
        exit 1
        ;;
    esac
done

ensure_workspace_ready
sync_dotfiles_to_workspace || warn "Dotfiles sync failed — nvim may be on the last GitHub clone"
create_tmux_session "$session_name"
