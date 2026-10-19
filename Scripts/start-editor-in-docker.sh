#!/usr/bin/env bash
# Copyright (c) 2026 DLR e.V.
#
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_TAG="${IMAGE_TAG:-ghcr.io/epicgames/unreal-engine:dev-5.8.3}"
CONTAINER_NAME="${CONTAINER_NAME:-gemstar-unreal-editor}"
DISPLAY_VALUE="${DISPLAY:?DISPLAY must be set for the editor UI}"
XAUTHORITY_PATH="${XAUTHORITY:-$HOME/.Xauthority}"
ENGINE_DIR="/home/ue4/UnrealEngine"
PROJECT_FILE="/workspace/GEMSTAR.uproject"

if [ ! -f "$XAUTHORITY_PATH" ] || [ ! -r "$XAUTHORITY_PATH" ]; then
    printf 'Xauthority must be a readable file: %s\n' "$XAUTHORITY_PATH" >&2
    exit 1
fi

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    CURRENT_IMAGE="$(docker container inspect --format '{{.Config.Image}}' "$CONTAINER_NAME")"

    CURRENT_DISPLAY="$(docker container inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$CONTAINER_NAME" | sed -n 's/^DISPLAY=//p')"
    CURRENT_XAUTHORITY="$(docker container inspect --format '{{range .Mounts}}{{if eq .Destination "/tmp/.Xauthority"}}{{.Source}}{{end}}{{end}}' "$CONTAINER_NAME")"

    if [ "$CURRENT_IMAGE" != "$IMAGE_TAG" ] ||
       [ "$CURRENT_DISPLAY" != "$DISPLAY_VALUE" ] ||
       [ "$CURRENT_XAUTHORITY" != "$XAUTHORITY_PATH" ]; then
        printf 'Recreating container %s: image or graphical session changed.\n' "$CONTAINER_NAME"
        docker container rm --force "$CONTAINER_NAME" >/dev/null
    fi
fi

if ! docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    docker run -d \
        --name "$CONTAINER_NAME" \
        --network host \
        --ipc host \
        --gpus all \
        --device /dev/dri \
        -e NVIDIA_DRIVER_CAPABILITIES=graphics,compute,utility,display \
        -e DISPLAY="$DISPLAY_VALUE" \
        -e XAUTHORITY=/tmp/.Xauthority \
        -v "$ROOT_DIR":/workspace \
        -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
        --mount "type=bind,source=$XAUTHORITY_PATH,target=/tmp/.Xauthority,readonly" \
        -w /workspace \
        "$IMAGE_TAG" sleep infinity
elif [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" != "true" ]; then
    docker start "$CONTAINER_NAME" >/dev/null
fi

if docker exec "$CONTAINER_NAME" pgrep -x UnrealEditor >/dev/null 2>&1; then
    printf 'UnrealEditor is already running in container %s.\n' "$CONTAINER_NAME"
    exit 0
fi

# Build the editor target explicitly before starting the GUI. Unreal Editor 5.8
# otherwise starts an asynchronous rebuild when modules are missing (for
# example after cleanup-build-artefacts.sh) and exits before the rebuilt
# modules can be loaded.
printf 'Building GEMSTAREditor if necessary...\n'
docker exec "$CONTAINER_NAME" \
    "$ENGINE_DIR/Engine/Build/BatchFiles/Linux/Build.sh" \
    Development Linux \
    "-Project=$PROJECT_FILE" \
    -TargetType=Editor \
    -Progress \
    -NoEngineChanges \
    -NoHotReloadFromIDE

docker exec "$CONTAINER_NAME" /bin/bash -lc 'rm -f /workspace/Saved/webcache_*/SingletonLock'
docker exec -d "$CONTAINER_NAME" \
    "$ENGINE_DIR/Engine/Binaries/Linux/UnrealEditor" \
    "$PROJECT_FILE" \
    -nosound \
    -VSync \
    -r.RHI.Bindless.Resources=0 \
    -r.RHI.Bindless.Samplers=0

printf 'UnrealEditor started in container %s.\n' "$CONTAINER_NAME"
