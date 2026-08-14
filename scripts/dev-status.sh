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
root="$(repo_root)"
ws_state="$(workspace_state "$id")"

printf "project:   %s\n" "$root"
printf "workspace: %s\n" "$id"
printf "devpod:    %s\n" "$ws_state"

if ! command -v tmux >/dev/null 2>&1; then
    printf "tmux:      (tmux not installed)\n"
    exit 0
fi

local_list="$(list_workspace_tmux_sessions "$id" || true)"
if [[ -z "$local_list" ]]; then
    printf "tmux:      none\n"
    exit 0
fi

printf "tmux:\n"
while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    printf "  - %s\n" "$name"
done <<<"$local_list"
