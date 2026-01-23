#!/usr/bin/env bash
set -euo pipefail

# Source utils
source "$(dirname "$0")/utils.sh"

require_dotfiles_root
require_docker

# Determine project image
PROJECT_IMAGE="$(docker_image_name)" # e.g., dotfiles:dev
log "→ Launching container from image: $PROJECT_IMAGE"

# Name of the container (optional: project-specific)
CONTAINER_NAME="${PROJECT_IMAGE//[:]/_}-dev" # e.g., dotfiles_dev-dev

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    info "Container already exists: $CONTAINER_NAME"
else
    log "→ Creating container..."
    docker run -dit \
        --name "$CONTAINER_NAME" \
        -v "$HOME/.config:/home/dev/.config:cached" \
        -v "$PWD:/workspace:cached" \
        "$PROJECT_IMAGE" \
        bash
fi

# Attach or start tmux inside container
log "→ Attaching tmux session inside container..."
docker exec -it "$CONTAINER_NAME" tmux new-session -A -s dev
