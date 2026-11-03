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
CONTAINER_NAME="${CONTAINER_NAME:-gemstar-unreal-builder}"
BUILD_CONFIG="${BUILD_CONFIG:-Development}"
PLATFORM="${PLATFORM:-Linux}"
BUILD_DIR="${BUILD_DIR:-Build}"
CLEAN_BUILD="${CLEAN_BUILD:-1}"

case "$BUILD_CONFIG" in
    Debug|DebugGame|Development|Shipping|Test) ;;
    *)
        printf 'Unsupported BUILD_CONFIG: %s\n' "$BUILD_CONFIG" >&2
        exit 2
        ;;
esac

case "$PLATFORM" in
    Linux|LinuxArm64) ;;
    *)
        printf 'Unsupported PLATFORM: %s\n' "$PLATFORM" >&2
        exit 2
        ;;
esac

if [[ "$BUILD_DIR" = /* || "$BUILD_DIR" == ".." || "$BUILD_DIR" == ../* || "$BUILD_DIR" == */../* ]]; then
    printf 'BUILD_DIR must stay inside the project directory: %s\n' "$BUILD_DIR" >&2
    exit 2
fi

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    CURRENT_IMAGE="$(docker container inspect --format '{{.Config.Image}}' "$CONTAINER_NAME")"

    if [ "$CURRENT_IMAGE" != "$IMAGE_TAG" ]; then
        printf 'Recreating container %s: image changed from %s to %s.\n' \\
            "$CONTAINER_NAME" "$CURRENT_IMAGE" "$IMAGE_TAG"
        docker container rm --force "$CONTAINER_NAME" >/dev/null
    fi
fi

if ! docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    docker run -d \
        --name "$CONTAINER_NAME" \
        --network host \
        --ipc host \
        -v "$ROOT_DIR":/workspace \
        -w /workspace \
        "$IMAGE_TAG" sleep infinity >/dev/null
elif [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" != "true" ]; then
    docker start "$CONTAINER_NAME" >/dev/null
fi

uat_args=(
    BuildCookRun
    -nop4
    -utf8output
    -installed
    -project=/workspace/GEMSTAR.uproject
    -target=GEMSTAR
    "-platform=$PLATFORM"
    "-clientconfig=$BUILD_CONFIG"
    -build
    -cook
    -stage
    -package
    -archive
    -prereqs
    "-archivedirectory=/workspace/$BUILD_DIR"
)

if [ "$CLEAN_BUILD" = "1" ]; then
    uat_args+=( -clean )
elif [ "$CLEAN_BUILD" != "0" ]; then
    printf 'CLEAN_BUILD must be 0 or 1: %s\n' "$CLEAN_BUILD" >&2
    exit 2
fi

uat_args+=( "$@" )

printf 'Building GEMSTAR (%s, %s) into %s/%s ...\n' \
    "$PLATFORM" "$BUILD_CONFIG" "$ROOT_DIR" "$BUILD_DIR"

docker exec "$CONTAINER_NAME" \
    /home/ue4/UnrealEngine/Engine/Build/BatchFiles/RunUAT.sh \
    "${uat_args[@]}"

printf 'Build completed: %s/%s/%s\n' "$ROOT_DIR" "$BUILD_DIR" "$PLATFORM"
