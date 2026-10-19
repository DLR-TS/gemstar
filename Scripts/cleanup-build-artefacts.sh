#!/usr/bin/env bash
# Copyright (c) 2026 DLR e.V.
#
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

delete_dir() {
    local path="$1"

    if [ -d "$path" ]; then
        printf 'Deleting: %s\n' "$path"
        rm -rf -- "$path"
    fi
}

printf '%s\n' '============================================'
printf '%s\n' 'GEMSTAR Cleanup Script'
printf 'Project directory: %s\n' "$PROJECT_DIR"
printf '%s\n' '============================================'

printf '\n%s\n' 'Deleting Binaries, Intermediate, DerivedDataCache and Output in project root...'
delete_dir "$PROJECT_DIR/Binaries"
delete_dir "$PROJECT_DIR/Intermediate"
delete_dir "$PROJECT_DIR/DerivedDataCache"
delete_dir "$PROJECT_DIR/Output"

printf '\n%s\n' 'Deleting Binaries and Intermediate in Plugins/*...'
if [ -d "$PROJECT_DIR/Plugins" ]; then
    for plugin_dir in "$PROJECT_DIR"/Plugins/*; do
        [ -d "$plugin_dir" ] || continue
        delete_dir "$plugin_dir/Binaries"
        delete_dir "$plugin_dir/Intermediate"
    done
fi

printf '\n%s\n' 'Deleting Binaries and Intermediate in Plugins/GameFeatures/*...'
if [ -d "$PROJECT_DIR/Plugins/GameFeatures" ]; then
    for plugin_dir in "$PROJECT_DIR"/Plugins/GameFeatures/*; do
        [ -d "$plugin_dir" ] || continue
        delete_dir "$plugin_dir/Binaries"
        delete_dir "$plugin_dir/Intermediate"
    done
fi

printf '\n%s\n' 'Done.'

