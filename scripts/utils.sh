#!/usr/bin/env bash
# Shared helpers for bin/dev (DevPod + host tmux).
set -euo pipefail

# -----------------------------
# Logging
# -----------------------------
log() { printf "→ %s\n" "$*"; }
info() { printf "[INFO] %s\n" "$*"; }
success() { printf "✔ %s\n" "$*"; }
warn() { printf "⚠ %s\n" "$*" >&2; }
error() { printf "✗ %s\n" "$*" >&2; }

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
# Dotfiles / PATH
# -----------------------------
ensure_dotfiles_root() {
    if [[ -z "${DOTFILES_ROOT:-}" ]]; then
        local here
        here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
        export DOTFILES_ROOT="$here"
    fi
}

require_host() {
    if [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]] || [[ -n "${DEVCONTAINER:-}" ]]; then
        error "Run this on the host, not inside a container"
        exit 1
    fi
}

require_devpod() {
    if ! command -v devpod >/dev/null 2>&1; then
        error "devpod is not installed or not in PATH"
        exit 1
    fi
}

require_tmux() {
    if ! command -v tmux >/dev/null 2>&1; then
        error "tmux is not installed or not in PATH"
        exit 1
    fi
}

# -----------------------------
# Project identity
# -----------------------------
# Prefer nearest .devcontainer (walk up), else git root, else PWD
repo_root() {
    local dir="${1:-$PWD}"
    dir="$(cd "$dir" && pwd)"
    local cursor="$dir"
    while [[ "$cursor" != "/" ]]; do
        if [[ -f "$cursor/.devcontainer/devcontainer.json" ]]; then
            echo "$cursor"
            return 0
        fi
        cursor="$(dirname "$cursor")"
    done
    if command -v git >/dev/null 2>&1; then
        git -C "$dir" rev-parse --show-toplevel 2>/dev/null && return 0
    fi
    echo "$dir"
}

# DevPod-style default id: lowercase, alphanumeric only
default_workspace_id() {
    local name
    name="$(basename "$(repo_root)")"
    echo "$name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9'
}

# Prefer explicit override, then existing DevPod workspace by local path, then default id
workspace_id() {
    if [[ -n "${DEV_WORKSPACE:-}" ]]; then
        echo "$DEV_WORKSPACE"
        return 0
    fi

    local root id resolved
    root="$(repo_root)"

    if command -v jq >/dev/null 2>&1 && command -v devpod >/dev/null 2>&1; then
        resolved="$root"
        if command -v realpath >/dev/null 2>&1; then
            resolved="$(realpath "$root" 2>/dev/null || echo "$root")"
        fi
        id="$(
            devpod list --output json 2>/dev/null |
                jq -r --arg p "$resolved" --arg p2 "$root" '
          .[]
          | select(.source.localFolder == $p or .source.localFolder == $p2)
          | .id
        ' 2>/dev/null | head -n1 || true
        )"
        if [[ -n "$id" && "$id" != "null" ]]; then
            echo "$id"
            return 0
        fi
    fi

    default_workspace_id
}

ensure_workspace_ready() {
    local id="${1:-$(workspace_id)}"
    if ! ssh_host_configured "$id" || ! workspace_running "$id"; then
        log "Workspace '$id' not ready — starting…"
        "$DOTFILES_ROOT/scripts/dev-up.sh" --id "$id"
    fi
    if ! ssh_host_configured "$id"; then
        error "No SSH host '${id}.devpod' after up — fix docker compose / image tag, then: dev up"
        exit 1
    fi
}

# Consumes optional --id / --debug from "$@"; remaining in DEV_ARGS
# Sets DEVPOD_GLOBAL_FLAGS for `devpod` invocations
consume_common_flags() {
    DEV_ARGS=()
    DEVPOD_GLOBAL_FLAGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --id)
            shift
            [[ $# -gt 0 ]] || {
                error "--id requires a value"
                exit 1
            }
            export DEV_WORKSPACE="$1"
            shift
            ;;
        --id=*)
            export DEV_WORKSPACE="${1#--id=}"
            shift
            ;;
        --debug)
            DEVPOD_GLOBAL_FLAGS+=(--debug)
            shift
            ;;
        *)
            DEV_ARGS+=("$1")
            shift
            ;;
        esac
    done
}

require_docker_compose_v2() {
    # Do not replace Ubuntu's compose plugin — VS Code uses it.
    # DevPod 0.6 extra issues are handled by bin/docker (DOCKER_PATH).
    local dc
    dc="$(command -v docker-compose 2>/dev/null || true)"
    if [[ -n "$dc" ]]; then
        local dcver
        dcver="$(docker-compose version 2>/dev/null | head -n1 || true)"
        if echo "$dcver" | grep -Eq 'version 1\.|docker-compose version 1'; then
            error "DevPod will pick docker-compose v1 at $dc ($dcver) over 'docker compose'"
            error "Removing this v1 CLI does not affect VS Code (it uses the v2 plugin)."
            error "  dpkg -S $dc"
            error "  sudo apt remove docker-compose python3-compose && sudo apt autoremove"
            error "  pip uninstall docker-compose"
            exit 1
        fi
    fi

    if ! docker compose version >/dev/null 2>&1; then
        error "Missing 'docker compose' (Compose v2 plugin)"
        error "Ubuntu: sudo apt install docker-compose-v2"
        exit 1
    fi
}

devpod_docker_path() {
    echo "${DOTFILES_ROOT}/bin/docker"
}

# -----------------------------
# DevPod workspace state
# -----------------------------
workspace_state() {
    local id="${1:-$(workspace_id)}"
    # Avoid docker.sock requirement when we only need recorded state
    local out
    if ! out="$(devpod status "$id" --output json --container-status=false 2>/dev/null)"; then
        echo "Absent"
        return 0
    fi
    if command -v jq >/dev/null 2>&1; then
        jq -r '.state // "Unknown"' <<<"$out" 2>/dev/null || echo "Unknown"
    else
        echo "$out"
    fi
}

workspace_exists() {
    local state
    state="$(workspace_state "$1" 2>/dev/null || true)"
    [[ -n "$state" && "$state" != "Absent" ]]
}

workspace_running() {
    local state
    state="$(workspace_state "$1" 2>/dev/null || true)"
    [[ "$state" == "Running" ]]
}

ssh_host_configured() {
    local id="${1:-$(workspace_id)}"
    grep -q "Host ${id}.devpod" "${HOME}/.ssh/config" 2>/dev/null
}

# Multiplexed OpenSSH into DevPod (avoids a full `devpod ssh` per pane)
ssh_host() {
    local id="${1:-$(workspace_id)}"
    echo "${id}.devpod"
}

ensure_ssh_multiplexing() {
    local marker="# Dotfiles DevPod multiplexing"
    local cfg="${HOME}/.ssh/config"
    mkdir -p "${HOME}/.ssh"
    touch "$cfg"
    chmod 600 "$cfg" 2>/dev/null || true
    if grep -qF "$marker" "$cfg" 2>/dev/null; then
        return 0
    fi
    cat >>"$cfg" <<EOF

${marker}
Host *.devpod
  ControlMaster auto
  ControlPath ~/.ssh/cm-devpod-%h
  ControlPersist 30m
EOF
}

# Open (or reuse) the SSH master so new tmux panes are cheap
warm_ssh_master() {
    local id="${1:-$(workspace_id)}"
    local host
    host="$(ssh_host "$id")"
    ensure_ssh_multiplexing

    if ! ssh_host_configured "$id"; then
        error "No SSH host '${id}.devpod' in ~/.ssh/config — workspace did not finish starting"
        return 1
    fi

    if ssh -O check "$host" >/dev/null 2>&1; then
        return 0
    fi

    log "Warming SSH master for $host…"
    if ! ssh -fN "$host"; then
        error "Could not open SSH to $host"
        return 1
    fi
}

# Copy the host working tree into the workspace ~/dotfiles (not the GitHub clone),
# then relink nvim/zsh configs. Does not reinstall packages.
sync_dotfiles_to_workspace() {
    local id="${1:-$(workspace_id)}"
    local host
    host="$(ssh_host "$id")"

    if ! ssh_host_configured "$id"; then
        error "No SSH host '${id}.devpod' — start the workspace first: dev up"
        return 1
    fi
    if ! workspace_running "$id"; then
        error "Workspace '$id' is not Running (state: $(workspace_state "$id"))"
        return 1
    fi

    warm_ssh_master "$id" || return 1

    log "Syncing $DOTFILES_ROOT → ${host}:~/dotfiles"
    tar -C "$DOTFILES_ROOT" --exclude='.git' --exclude='.cursor' -cf - . |
        ssh "$host" 'mkdir -p "$HOME/dotfiles" && tar -C "$HOME/dotfiles" -xf - && bash "$HOME/dotfiles/install-devpod.sh" --links-only'
    success "Dotfiles synced — new shells pick up zsh; restart nvim (or :source \$MYVIMRC)"
}

ssh_workspace() {
    local id="${1:-$(workspace_id)}"
    local host
    local -a remote_cmd
    host="$(ssh_host "$id")"
    shift || true

    ensure_ssh_multiplexing

    if [[ $# -eq 0 ]]; then
        if [[ -n "${DEV_REMOTE_SHELL:-}" ]]; then
            # shellcheck disable=SC2206
            remote_cmd=(${DEV_REMOTE_SHELL})
        else
            # Interactive, not login: `zsh -l` over ssh -tt often eats the first Enter.
            remote_cmd=(
                'command -v zsh >/dev/null 2>&1 && exec zsh -i; command -v bash >/dev/null 2>&1 && exec bash -i; exec sh'
            )
        fi
    else
        remote_cmd=("$@")
    fi

    if grep -q "Host ${id}.devpod" "${HOME}/.ssh/config" 2>/dev/null; then
        exec ssh -tt "$host" -- "${remote_cmd[@]}"
    fi

    warn "Falling back to 'devpod ssh' (no ${id}.devpod in ssh config)"
    exec devpod ssh "$id" --command "${remote_cmd[*]}"
}

# -----------------------------
# Tmux: many sessions per workspace, all panes SSH into that workspace
# -----------------------------
# Brackets like [REMOTE] are tmux wildcards — use a Nerd Font docker mark instead.
# Override with DEV_TMUX_PREFIX='REMOTE-' if you want ASCII.
tmux_remote_prefix() {
    printf '%s' "${DEV_TMUX_PREFIX:-$'\uf308 '}"
}

prefixed_session_name() {
    local raw="$1"
    local p
    p="$(tmux_remote_prefix)"
    if [[ -z "$raw" ]]; then
        echo ""
        return 0
    fi
    if [[ "$raw" == "$p"* ]]; then
        printf '%s\n' "$raw"
    else
        printf '%s%s\n' "$p" "$raw"
    fi
}

tmux_session_exists() {
    local session="${1:-}"
    [[ -n "$session" ]] && tmux has-session -t "=${session}" 2>/dev/null
}

resolve_tmux_session() {
    local want="$1"
    [[ -n "$want" ]] || return 1
    if tmux_session_exists "$want"; then
        printf '%s\n' "$want"
        return 0
    fi
    local prefixed
    prefixed="$(prefixed_session_name "$want")"
    if [[ "$prefixed" != "$want" ]] && tmux_session_exists "$prefixed"; then
        printf '%s\n' "$prefixed"
        return 0
    fi
    return 1
}

tmux_attach_or_switch() {
    local session="$1"
    if [[ -n "${TMUX:-}" ]]; then
        log "Switching to tmux session: $session"
        tmux switch-client -t "$session"
    else
        log "Attaching tmux session: $session"
        exec tmux attach-session -t "$session"
    fi
}

# Session names bound to this DevPod workspace (via DEV_WORKSPACE env)
list_workspace_tmux_sessions() {
    local id="${1:-$(workspace_id)}"
    local name env
    command -v tmux >/dev/null 2>&1 || return 0
    tmux list-sessions -F '#{session_name}' 2>/dev/null | while read -r name; do
        [[ -n "$name" ]] || continue
        env="$(tmux show-environment -t "$name" DEV_WORKSPACE 2>/dev/null | sed -n 's/^DEV_WORKSPACE=//p' || true)"
        if [[ "$env" == "$id" || "$name" == "$id" || "$name" == "$id"-* ]]; then
            printf '%s\n' "$name"
        elif [[ "$name" == "$(tmux_remote_prefix)$id" || "$name" == "$(tmux_remote_prefix)$id"-* ]]; then
            printf '%s\n' "$name"
        fi
    done
}

next_tmux_session_name() {
    local id="${1:-$(workspace_id)}"
    local n=2
    local base
    if [[ -n "${DEV_TMUX_SESSION:-}" ]]; then
        prefixed_session_name "$DEV_TMUX_SESSION"
        return 0
    fi
    base="$(prefixed_session_name "$id")"
    if ! tmux_session_exists "$base"; then
        echo "$base"
        return 0
    fi
    while tmux_session_exists "$(prefixed_session_name "${id}-${n}")"; do
        n=$((n + 1))
    done
    prefixed_session_name "${id}-${n}"
}

bind_tmux_session() {
    local session="$1"
    local id="$2"
    local root="$3"
    local shell_cmd="${DOTFILES_ROOT}/bin/dev-shell"

    tmux set-environment -t "$session" DEV_WORKSPACE "$id"
    tmux set-environment -t "$session" DEV_PROJECT_ROOT "$root"
    tmux set-option -t "$session" default-command "$shell_cmd"
    tmux set-option -t "$session" default-path "$root" 2>/dev/null || true
}

create_tmux_session() {
    local id session root shell_cmd
    id="$(workspace_id)"
    if [[ -n "${1:-}" ]]; then
        session="$(prefixed_session_name "$1")"
    else
        session="$(next_tmux_session_name "$id")"
    fi
    root="$(repo_root)"
    shell_cmd="${DOTFILES_ROOT}/bin/dev-shell"

    require_tmux
    warm_ssh_master "$id"

    if tmux_session_exists "$session"; then
        error "tmux session '$session' already exists — use: dev attach --session $session"
        exit 1
    fi

    log "Creating tmux session: $session → workspace $id"
    tmux new-session -d -s "$session" -c "$root" -e "DEV_WORKSPACE=$id" -e "DEV_PROJECT_ROOT=$root" "$shell_cmd"
    bind_tmux_session "$session" "$id" "$root"

    sleep 0.2
    if ! tmux_session_exists "$session"; then
        error "tmux session '$session' exited at once (remote shell/SSH failed)"
        error "Try: ssh ${id}.devpod"
        error "Then in the workspace: ~/dotfiles/install-devpod.sh"
        exit 1
    fi

    tmux_attach_or_switch "$session"
}

attach_tmux_session() {
    local id session
    local -a sessions=()
    id="$(workspace_id)"
    session="${1:-}"

    require_tmux
    warm_ssh_master "$id"

    if [[ -n "$session" ]]; then
        local resolved
        if ! resolved="$(resolve_tmux_session "$session")"; then
            error "No tmux session named '$session'"
            exit 1
        fi
        session="$resolved"
        bind_tmux_session "$session" "$id" "$(repo_root)"
        tmux_attach_or_switch "$session"
        return 0
    fi

    mapfile -t sessions < <(list_workspace_tmux_sessions "$id")
    if [[ ${#sessions[@]} -eq 0 ]]; then
        log "No tmux sessions for workspace $id — creating one"
        create_tmux_session
        return 0
    fi
    if [[ ${#sessions[@]} -eq 1 ]]; then
        bind_tmux_session "${sessions[0]}" "$id" "$(repo_root)"
        tmux_attach_or_switch "${sessions[0]}"
        return 0
    fi

    error "Multiple tmux sessions for workspace $id:"
    printf '  %s\n' "${sessions[@]}" >&2
    error "Use: dev attach --session NAME   or   dev enter (new session)"
    exit 1
}
