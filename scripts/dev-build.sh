#!/usr/bin/env bash
set -euo pipefail

source "$DOTFILES_ROOT/scripts/utils.sh"

echo "→ Resolving build strategy…"

# ---------- Case 1: devcontainer.json ----------
if DEVCONTAINER_JSON="$(find_devcontainer 2>/dev/null)"; then
    success "Found devcontainer.json"

    COMPOSE_FILE="$(devcontainer_get dockerComposeFile "$DEVCONTAINER_JSON")"
    DOCKERFILE="$(devcontainer_get build.dockerfile "$DEVCONTAINER_JSON")"
    CONTEXT="$(devcontainer_get build.context "$DEVCONTAINER_JSON")"
    CONTEXT="${CONTEXT:-.devcontainer}"

    # ---- 1a: docker-compose based devcontainer ----
    if [[ -n "$COMPOSE_FILE" ]]; then
        success "Using dockerComposeFile: $COMPOSE_FILE"

        confirm "Build devcontainer with docker compose?" || exit 0

        docker compose \
            -f ".devcontainer/$COMPOSE_FILE" \
            -f "$DOTFILES_ROOT/devcontainer/docker-compose.overlay.yml" \
            build

        exit 0
    fi

    # ---- 1b: Dockerfile-based devcontainer ----
    if [[ -n "$DOCKERFILE" ]]; then
        success "Using Dockerfile: $DOCKERFILE"

        confirm "Build devcontainer image?" || exit 0

        docker build \
            -f "$CONTEXT/$DOCKERFILE" \
            -t repo-base:dev \
            "$CONTEXT"

        docker build \
            --build-arg BASE_IMAGE=repo-base:dev \
            -f "$DOTFILES_ROOT/devcontainer/Dockerfile.overlay" \
            -t dev-env:latest \
            "$DOTFILES_ROOT"

        exit 0
    fi

    error "devcontainer.json found, but no dockerComposeFile or build.dockerfile"
    exit 1
fi

# ---------- Case 2: plain Dockerfile ----------
if [[ -f Dockerfile ]]; then
    success "Found Dockerfile at repo root"

    confirm "Build Dockerfile + dev overlay?" || exit 0

    PROJECT_NAME="$(docker_image_name)"

    log "Building $PROJECT_NAME..."

    docker build -t "$PROJECT_NAME:latest" .

    docker build \
        --build-arg BASE_IMAGE="$PROJECT_NAME" \
        -f "$DOTFILES_ROOT/devcontainer/Dockerfile.overlay" \
        -t "$PROJECT_NAME:dev" \
        "$DOTFILES_ROOT"

    exit 0
fi

# ---------- Nothing buildable ----------
error "✗ No devcontainer.json or Dockerfile found"
exit 1
