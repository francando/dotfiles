#!/usr/bin/env bash
set -euo pipefail

# Source utils
source "$(dirname "$0")/utils.sh"

require_dotfiles_root
require_docker

USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Determine project image
PROJECT_IMAGE="$(docker_image_name)" # e.g., dotfiles:dev
log "Launching container from image: $PROJECT_IMAGE:dev"

# Name of the container (optional: project-specific)
CONTAINER_NAME="${PROJECT_IMAGE//[:]/_}" # e.g., dotfiles_dev-dev

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    info "Container already exists: $CONTAINER_NAME"

    # Check if it's actually running
    if [ "$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}")" = "false" ]; then
        log "Container is stopped. Starting it..."
        docker start "${CONTAINER_NAME}" >/dev/null
    fi
else
    log "Creating container..."
    docker run -dit \
        --name "$CONTAINER_NAME" \
        --hostname "$CONTAINER_NAME" \
        --user "$USER" \
        -v "$HOME/.config:/home/$USER/.config:cached" \
        -v "$HOME/dotfiles:/home/$USER/dotfiles:cached" \
        -v "$HOME/.zshrc:/home/$USER/.zshrc:cached" \
        -v "$HOME/.local:/home/$USER/.local:cached" \
        -v "/usr/local/share/fonts:/usr/local/share/fonts:cached" \
        -v "$PWD:/workspace:cached" \
        "$PROJECT_IMAGE:dev" \
        tail -f /dev/null
    # bash -c "usermod -u $USER_ID $USER && groupmod -g $GROUP_ID $USER && chown $USER:$USER /home/$USER && tail -f /dev/null"
    # sleep 0.001
fi

# For sticky terminals in this session
tmux set-environment -g DEV_CONTAINER_ACTIVE 1

# Attach or start tmux inside container
# log "Attaching to container $CONTAINER_NAME..."
docker exec -it -u "$USER" "$CONTAINER_NAME" zsh
