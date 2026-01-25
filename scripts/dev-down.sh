#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/utils.sh"

require_dotfiles_root
require_docker

PROJECT_IMAGE="$(docker_image_name)"     # e.g., dotfiles:dev
CONTAINER_NAME="${PROJECT_IMAGE//[:]/_}" # e.g., dotfiles_dev-dev

log "Tearing down $CONTAINER_NAME..."
tmux set-environment -g DEV_CONTAINER_ACTIVE 0

docker stop "$CONTAINER_NAME"
docker rm "$CONTAINER_NAME"

success "Done"
