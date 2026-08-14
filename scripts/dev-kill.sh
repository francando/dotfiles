#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=utils.sh
source "$DOTFILES_ROOT/scripts/utils.sh"

ensure_dotfiles_root
require_host
require_tmux

consume_common_flags "$@"
set -- "${DEV_ARGS[@]}"

stop_ws=0
kill_all=0
session_name=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    --down)
        stop_ws=1
        shift
        ;;
    --all)
        kill_all=1
        shift
        ;;
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
    *)
        error "Unknown argument: $1 (supported: --session NAME, --all, --down)"
        exit 1
        ;;
    esac
done

id="$(workspace_id)"

kill_one() {
    local s="$1"
    local resolved
    if resolved="$(resolve_tmux_session "$s")"; then
        s="$resolved"
    fi
    if tmux_session_exists "$s"; then
        log "Killing tmux session: $s"
        tmux kill-session -t "=$s"
        success "Session $s killed"
    else
        warn "No tmux session named '$s'"
    fi
}

if [[ "$kill_all" -eq 1 ]]; then
    mapfile -t sessions < <(list_workspace_tmux_sessions "$id")
    if [[ ${#sessions[@]} -eq 0 ]]; then
        warn "No tmux sessions for workspace '$id'"
    else
        for s in "${sessions[@]}"; do
            [[ -n "$s" ]] || continue
            kill_one "$s"
        done
    fi
elif [[ -n "$session_name" ]]; then
    kill_one "$session_name"
elif [[ -n "${TMUX:-}" ]]; then
    kill_one "$(tmux display-message -p '#S')"
else
    mapfile -t sessions < <(list_workspace_tmux_sessions "$id")
    if [[ ${#sessions[@]} -eq 1 ]]; then
        kill_one "${sessions[0]}"
    elif [[ ${#sessions[@]} -eq 0 ]]; then
        warn "No tmux sessions for workspace '$id'"
    else
        error "Multiple tmux sessions; pass --session NAME or --all"
        printf '  %s\n' "${sessions[@]}" >&2
        exit 1
    fi
fi

if [[ "$stop_ws" -eq 1 ]]; then
    require_devpod
    if workspace_exists "$id"; then
        log "Stopping DevPod workspace: $id"
        devpod stop "$id"
        success "Stopped $id"
    else
        warn "Workspace '$id' does not exist"
    fi
fi
